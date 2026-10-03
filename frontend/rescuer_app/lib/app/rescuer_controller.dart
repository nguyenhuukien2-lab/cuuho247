import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/backend_models.dart';
import '../services/location_service.dart';
import '../services/document_picker.dart';
import '../services/rescuer_service.dart';

enum FeedStatus { unavailable, loading, empty, ready, error }

enum JobStatus { unavailable, loading, empty, ready, error }

class RescuerController extends ChangeNotifier {
  RescuerController(this.service, this.location, {DocumentPicker? documents})
    : documents = documents ?? DocumentPicker();
  final RescuerService service;
  final LocationService location;
  final DocumentPicker documents;
  StreamSubscription<String?>? _auth;
  Timer? _timer;
  bool _disposed = false, _foreground = true;
  int _epoch = 0;
  String? userId, selectedVehicle, sessionId, error, feedError;
  RescuerSnapshot snapshot = const RescuerSnapshot();
  bool loading = true,
      working = false,
      online = false,
      locationReady = false,
      snapshotLoaded = false;
  int sequence = 0, tab = 0;
  FeedStatus feedStatus = FeedStatus.unavailable;
  List<AvailableRequest> requests = [];
  Json? cursor;
  String accountSection = 'profile';
  String? notice;
  LocationHelp? locationHelp;
  bool gpsReady = false, onlineRecoveryRequired = false;
  String? onlineProgress;
  ActiveJob? activeJob;
  JobAssignment? claimedAssignment;
  JobStatus jobStatus = JobStatus.unavailable;
  String? jobError, claimingRequestId;
  int claimSuccessSerial = 0;
  bool get hasActiveJob =>
      activeJob != null || claimedAssignment?.isActive == true;
  bool get canClaim =>
      online &&
      canOnline &&
      locationReady &&
      !hasActiveJob &&
      jobStatus == JobStatus.empty &&
      !working &&
      !loading;
  bool get signedIn => userId != null;
  bool get canOnline =>
      snapshot.approved &&
      snapshot.eligibleVehicles.any((v) => v['id'] == selectedVehicle);
  bool get canEdit => snapshot.profile?['verification_status'] != 'suspended';
  List<ReadinessItem> get checklist {
    final profile = snapshot.profile;
    final active = snapshot.vehicles
        .where((v) => v['is_active'] == true)
        .toList();
    final enabled = snapshot.capabilities
        .where(
          (c) =>
              c['is_enabled'] == true &&
              active.any((v) => v['id'] == c['vehicle_id']),
        )
        .toList();
    return [
      ReadinessItem(
        'Hồ sơ cá nhân',
        profile == null
            ? 'Nhập họ tên và số điện thoại liên hệ.'
            : 'Đã lưu thông tin cá nhân.',
        profile != null,
        'profile',
      ),
      ReadinessItem(
        'Xe cứu hộ',
        active.isEmpty
            ? 'Thêm ít nhất một phương tiện hoạt động.'
            : '${active.length} phương tiện hoạt động.',
        active.isNotEmpty,
        'vehicles',
      ),
      ReadinessItem(
        'Dịch vụ nhận',
        enabled.isEmpty
            ? 'Chọn dịch vụ và loại xe khách cho phương tiện.'
            : '${enabled.length} khả năng phục vụ đã chọn; cần được duyệt.',
        enabled.isNotEmpty,
        'services',
      ),
      ReadinessItem(
        'Giấy tờ/xác minh',
        snapshot.documentsReady
            ? 'Giấy tờ đã tải lên, còn hiệu lực.'
            : snapshot.approved
            ? 'Hồ sơ đã được xác minh.'
            : 'Tải căn cước, bằng lái và đăng ký xe.',
        snapshot.documentsReady || snapshot.approved,
        'documents',
      ),
      ReadinessItem(
        'GPS',
        gpsReady
            ? 'Đã có vị trí chính xác trên thiết bị.'
            : 'Bật GPS và cho phép vị trí chính xác.',
        gpsReady,
        'gps',
      ),
      ReadinessItem(
        'Được duyệt',
        snapshot.approved && snapshot.eligibleVehicles.isNotEmpty
            ? 'Hồ sơ, xe và dịch vụ đủ quyền hoạt động.'
            : 'Chờ duyệt hồ sơ, xe và dịch vụ đã chọn.',
        snapshot.approved && snapshot.eligibleVehicles.isNotEmpty,
        'review',
      ),
    ];
  }

  List<String> get onlineBlockers {
    final v = snapshot.vehicles
        .where((v) => v['id'] == selectedVehicle)
        .firstOrNull;
    return [
      if (snapshot.profile == null) 'Chưa tạo hồ sơ cá nhân.',
      if (snapshot.profile != null && !snapshot.approved)
        'Hồ sơ cá nhân chưa được duyệt.',
      if (v == null) 'Chưa chọn phương tiện hoạt động.',
      if (v != null &&
          (v['verification_status'] != 'approved' || v['is_active'] != true))
        'Xe đã chọn chưa được duyệt hoặc đã tắt hoạt động.',
      if (v != null &&
          !snapshot.capabilities.any(
            (c) =>
                c['vehicle_id'] == selectedVehicle &&
                c['is_enabled'] == true &&
                c['verification_status'] == 'approved',
          ))
        'Xe đã chọn chưa có dịch vụ được duyệt.',
    ];
  }

  void openSection(String section) {
    accountSection = section;
    tab = 2;
    _notify();
  }

  void clearLocationHelp() {
    locationHelp = null;
    _notify();
  }

  Future<void> openLocationSettings(LocationHelp help) async {
    try {
      if (!await location.openSettings(gps: help == LocationHelp.disabled)) {
        error = 'Không mở được Cài đặt. Hãy mở Cài đặt thiết bị hoặc trình duyệt và bật quyền vị trí chính xác.';
      }
    } catch (_) {
      error = 'Hãy mở Cài đặt thiết bị và bật vị trí chính xác cho ứng dụng.';
    }
    _notify();
  }

  Future<void> checkGps() => _run((epoch) async {
    await location.current();
    _guard(epoch);
    gpsReady = true;
    notice = 'GPS đã sẵn sàng. Bạn có thể bật online khi hồ sơ, xe và dịch vụ đã được duyệt.';
  });

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool _current(int epoch) =>
      !_disposed && epoch == _epoch && userId == service.userId;
  void _guard(int epoch) {
    if (!_current(epoch)) {
      throw const RescuerFailure('Phiên đăng nhập đã thay đổi.');
    }
  }

  void start() {
    if (_auth != null) return;
    _auth = service.authChanges.listen(
      (_) {
        unawaited(_syncAuth());
      },
      onError: (Object e) {
        _epoch++;
        working = false;
        loading = false;
        _timer?.cancel();
        activeJob = null;
        claimedAssignment = null;
        jobStatus = JobStatus.error;
        jobError = rescuerError(e);
        locationReady = false;
        requests = [];
        cursor = null;
        error = rescuerError(e);
        _notify();
      },
    );
    unawaited(_syncAuth(force: true));
  }

  Future<void> _syncAuth({bool force = false}) async {
    if (!force && userId == service.userId) return;
    final epoch = ++_epoch;
    _timer?.cancel();
    userId = service.userId;
    snapshot = const RescuerSnapshot();
    snapshotLoaded = false;
    activeJob = null;
    claimedAssignment = null;
    jobStatus = JobStatus.unavailable;
    jobError = null;
    claimingRequestId = null;
    notice = null;
    locationHelp = null;
    gpsReady = false;
    onlineRecoveryRequired = false;
    onlineProgress = null;
    selectedVehicle = null;
    sessionId = null;
    online = false;
    locationReady = false;
    sequence = 0;
    requests = [];
    cursor = null;
    feedStatus = FeedStatus.unavailable;
    feedError = null;
    error = null;
    tab = 0;
    loading = signedIn;
    working = false;
    _notify();
    if (!signedIn) return;
    try {
      await _load(epoch);
      if (hasActiveJob) tab = 3;
    } catch (e) {
      if (_current(epoch)) error = rescuerError(e);
    } finally {
      if (_current(epoch)) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> _load(int epoch) async {
    activeJob = null;
    RescuerSnapshot result;
    try {
      result = await service.loadSnapshot();
    } catch (e) {
      if (_current(epoch)) {
        jobStatus = JobStatus.error;
        jobError = rescuerError(e);
        requests = [];
        cursor = null;
        _timer?.cancel();
      }
      rethrow;
    }
    _guard(epoch);
    final previousSession = sessionId;
    snapshot = result;
    snapshotLoaded = true;
    online = result.online?['is_online'] == true;
    sessionId = result.online?['session_id'] as String?;
    onlineRecoveryRequired = false;
    sequence = result.location?['session_id'] == sessionId
        ? (result.location?['sequence'] as num?)?.toInt() ?? 0
        : 0;
    final eligible = result.eligibleVehicles;
    final activeVehicles = result.vehicles
        .where((v) => v['is_active'] == true)
        .toList();
    if (online) {
      selectedVehicle = result.online?['vehicle_id'] as String?;
    } else if (!eligible.any((v) => v['id'] == selectedVehicle)) {
      if (!activeVehicles.any((v) => v['id'] == selectedVehicle)) {
        selectedVehicle = eligible.isNotEmpty
            ? eligible.first['id'] as String
            : activeVehicles.firstOrNull?['id'] as String?;
      }
    }
    if (!online || !canOnline || previousSession != sessionId) {
      locationReady = false;
      _timer?.cancel();
      requests = [];
      cursor = null;
      feedStatus = FeedStatus.unavailable;
    }
    if (snapshot.approved) {
      await _loadActiveJob(epoch);
    } else {
      activeJob = null;
      claimedAssignment = null;
      jobStatus = JobStatus.unavailable;
      jobError = null;
    }
  }

  Future<void> _loadActiveJob(int epoch) async {
    _guard(epoch);
    activeJob = null; // Revalidate PII access on every refresh.
    jobStatus = JobStatus.loading;
    jobError = null;
    _notify();
    try {
      final result = await service.getActiveJob();
      _guard(epoch);
      activeJob = result;
      claimedAssignment = result?.assignment;
      jobStatus = result == null ? JobStatus.empty : JobStatus.ready;
      if (result != null) {
        requests = [];
        cursor = null;
        feedStatus = FeedStatus.unavailable;
      }
    } catch (e) {
      if (!_current(epoch)) rethrow;
      activeJob = null;
      jobStatus = JobStatus.error;
      jobError = rescuerError(e);
      requests = [];
      cursor = null;
      feedStatus = FeedStatus.unavailable;
    }
    _schedule();
  }

  Future<void> refreshActiveJob() => _run((epoch) async {
    if (!snapshot.approved) return;
    await _loadActiveJob(epoch);
  });

  Future<void> claimRequest(AvailableRequest request) => _run((epoch) async {
    if (!online ||
        !canOnline ||
        !locationReady ||
        hasActiveJob ||
        jobStatus != JobStatus.empty ||
        !requests.any((r) => r.id == request.id)) {
      throw const RescuerFailure(
        'Chưa thể nhận đơn. Kiểm tra chuyến đang xử lý, online và GPS rồi tải lại.',
      );
    }
    final vehicleId = selectedVehicle!;
    claimingRequestId = request.id;
    _timer?.cancel();
    _notify();
    try {
      final result = await service.mutate('rescuer_claim_request', {
        'p_request_id': request.id,
        'p_vehicle_id': vehicleId,
      });
      _guard(epoch);
      final assignment = JobAssignment.fromJson(result);
      if (assignment.requestId != request.id ||
          assignment.vehicleId != vehicleId) {
        throw const FormatException('Unexpected assignment');
      }
      claimedAssignment = assignment.isActive ? assignment : null;
      _claimSucceeded();
      await _loadActiveJob(epoch);
      // Discovery requires idle on the server. Busy after a successful claim
      // is expected; never retain stale/new claimable cards while assigned.
      if (hasActiveJob) {
        try {
          await service.available(vehicleId);
          _guard(epoch);
        } catch (e) {
          _guard(epoch);
          if (!_rpcError(e, 'RESCUER_BUSY')) {
            feedError = rescuerError(e);
          }
        }
      }
    } catch (e) {
      _guard(epoch);
      // A lost claim response may have committed. Read the authoritative job
      // before allowing another claim; the service retains the operation UUID.
      await _loadActiveJob(epoch);
      if (activeJob?.assignment.requestId == request.id) {
        _claimSucceeded();
      } else {
        if (_rpcError(e, 'RESCUER_BUSY') && hasActiveJob) tab = 3;
        if (_rpcError(e, 'REQUEST_UNAVAILABLE') &&
            !hasActiveJob &&
            jobStatus == JobStatus.empty) {
          try {
            await _fetch(epoch);
          } catch (_) {
            _guard(epoch);
          }
        }
        rethrow;
      }
    } finally {
      if (_current(epoch)) {
        claimingRequestId = null;
        _schedule();
      }
    }
  });

  static bool _rpcError(Object e, String message) =>
      e is PostgrestException && e.message == message;

  void _claimSucceeded() {
    requests = [];
    cursor = null;
    feedStatus = FeedStatus.unavailable;
    feedError = null;
    tab = 3;
    notice = 'Đã nhận đơn thành công.';
    claimSuccessSerial++;
    _notify();
  }

  Future<void> _run(Future<void> Function(int epoch) action) async {
    if (working || loading || _disposed) return;
    final epoch = _epoch;
    working = true;
    error = null;
    notice = null;
    _notify();
    try {
      await action(epoch);
    } catch (e) {
      if (_current(epoch)) {
        error = rescuerError(e);
        if (e is LocationFailure) {
          locationHelp = e.help;
          gpsReady = false;
        }
      }
    } finally {
      if (_current(epoch)) {
        working = false;
        onlineProgress = null;
        _notify();
      }
    }
  }

  Future<void> signIn(String email, String password) async {
    if (working) return;
    working = true;
    error = null;
    _notify();
    try {
      await service.signIn(email, password);
      await _syncAuth();
    } catch (e) {
      error = rescuerError(e);
    } finally {
      if (!_disposed) {
        working = false;
        _notify();
      }
    }
  }

  Future<void> signOut() => _run((epoch) async {
    _timer?.cancel();
    activeJob = null;
    jobStatus = JobStatus.unavailable;
    requests = [];
    cursor = null;
    locationReady = false;
    if (online && sessionId != null) {
      try {
        await service.mutate('rescuer_set_online', {
          'p_online': false,
          'p_vehicle_id': selectedVehicle,
          'p_session_id': sessionId,
        });
      } catch (_) {
        /* Still sign out; server location freshness expires. */
      }
    }
    _guard(epoch);
    await service.signOut();
    await _syncAuth();
  });
  Future<void> refreshProfile() => _run((epoch) => _load(epoch));
  Future<void> saveProfile(String name, String phone) => _run((epoch) async {
    final exists = snapshot.profile != null;
    await service.mutate(
      exists ? 'rescuer_update_profile' : 'rescuer_register_profile',
      {
        'p_full_name': name.trim(),
        'p_contact_phone': phone.trim(),
        if (exists) 'p_expected_version': snapshot.profile!['version'],
      },
    );
    _guard(epoch);
    await _load(epoch);
    notice = 'Thông tin cá nhân đã được lưu.';
  });
  Future<void> submitProfile() => _run((epoch) async {
    if (!snapshot.canSubmit) {
      throw const RescuerFailure('Giấy tờ chưa sẵn sàng để gửi duyệt.');
    }
    await service.mutate('rescuer_submit_profile', {
      'p_expected_version': snapshot.profile!['version'],
    });
    _guard(epoch);
    await _load(epoch);
    notice = 'Hồ sơ đã được gửi xét duyệt. Chúng tôi sẽ cập nhật trạng thái sau khi kiểm tra.';
  });
  Future<void> registerVehicle(String kind, String name, String plate) => _run((
    epoch,
  ) async {
    await service.mutate('rescuer_register_vehicle', {
      'p_kind': kind,
      'p_display_name': name.trim(),
      'p_license_plate': plate.toUpperCase().replaceAll(RegExp(r'[\s.\-]'), ''),
    });
    _guard(epoch);
    await _load(epoch);
    notice = 'Đã thêm phương tiện. Tiếp tục chọn dịch vụ và tải đăng ký xe.';
  });
  Future<void> updateVehicle(
    Json vehicle,
    String kind,
    String name,
    String plate,
    bool active,
  ) => _run((epoch) async {
    await service.mutate('rescuer_update_vehicle', {
      'p_vehicle_id': vehicle['id'],
      'p_kind': kind,
      'p_display_name': name.trim(),
      'p_license_plate': plate.toUpperCase().replaceAll(RegExp(r'[\s.\-]'), ''),
      'p_is_active': active,
      'p_expected_version': vehicle['version'],
    });
    _guard(epoch);
    await _load(epoch);
    notice = 'Đã cập nhật xe. Thông tin xe và dịch vụ cần được duyệt lại.';
  });
  Future<void> saveCapabilities(
    String vehicleId,
    String kind,
    Set<String> chosen,
  ) => _run((epoch) async {
    if (!snapshot.vehicles.any((v) => v['id'] == vehicleId)) {
      throw const RescuerFailure('Chọn xe trong hồ sơ của bạn.');
    }
    if (!['motorbike', 'car', 'truck', 'other'].contains(kind) ||
        !chosen.every(
          (code) => snapshot.services.any((s) => s['code'] == code),
        )) {
      throw const RescuerFailure(
        'Dịch vụ hoặc loại xe khách chưa được hỗ trợ.',
      );
    }
    final existing = snapshot.capabilities
        .where(
          (c) =>
              c['vehicle_id'] == vehicleId &&
              c['customer_vehicle_kind'] == kind,
        )
        .toList();
    final codes = {
      ...chosen,
      ...existing
          .where((c) => c['is_enabled'] == true)
          .map((c) => c['service_code'] as String),
    };
    try {
      for (final code in codes) {
        final old = existing
            .where((c) => c['service_code'] == code)
            .firstOrNull;
        final enabled = chosen.contains(code);
        if (old != null && old['is_enabled'] == enabled) continue;
        _guard(epoch);
        await service.mutate('rescuer_set_capability', {
          'p_vehicle_id': vehicleId,
          'p_service_code': code,
          'p_customer_vehicle_kind': kind,
          'p_enabled': enabled,
        });
      }
    } catch (_) {
      if (_current(epoch)) {
        try {
          await _load(epoch);
        } catch (_) {}
      }
      rethrow;
    }
    _guard(epoch);
    await _load(epoch);
    notice = 'Dịch vụ đã được lưu. Dịch vụ mới hoặc bật lại cần được duyệt.';
  });
  Future<void> uploadDocument(String type, String? vehicleId) => _run((
    epoch,
  ) async {
    if (snapshot.profile == null) {
      throw const RescuerFailure('Lưu hồ sơ cá nhân trước khi tải giấy tờ.');
    }
    final picked = await documents.pick();
    _guard(epoch);
    if (picked == null) return;
    await service.uploadDocument(type, vehicleId, picked.bytes, picked.mime);
    _guard(epoch);
    await _load(epoch);
    notice = 'Giấy tờ đã được tải lên kho riêng và chờ kiểm tra.';
  });
  Future<void> completeDocument(String id) => _run((epoch) async {
    await service.mutate('rescuer_complete_document', {'p_document_id': id});
    _guard(epoch);
    await _load(epoch);
    notice = 'Đã xác nhận tệp giấy tờ trong kho riêng.';
  });
  void selectVehicle(String? id) {
    if (online || working) return;
    selectedVehicle = id;
    _notify();
  }

  void selectTab(int value) {
    tab = value;
    _notify();
    if (value == 1 && online && canOnline) unawaited(refreshRequests());
    if (value == 3) unawaited(refreshActiveJob());
  }

  Future<void> setOnline(bool value) => _run((epoch) async {
    if (value && !canOnline) {
      throw RescuerFailure('Chưa thể bật online: ${onlineBlockers.join(' ')}');
    }
    _timer?.cancel();
    locationReady = false;
    requests = [];
    cursor = null;
    feedStatus = FeedStatus.unavailable;
    onlineProgress = value
        ? 'Đang kiểm tra GPS và quyền vị trí…'
        : 'Đang chuyển offline…';
    _notify();
    final fix = value ? await location.current() : null;
    _guard(epoch);
    if (fix != null) gpsReady = true;
    onlineProgress = value
        ? 'Đang tạo phiên hoạt động…'
        : 'Đang chuyển offline…';
    _notify();
    final result = await service.mutate('rescuer_set_online', {
      'p_online': value,
      'p_vehicle_id': selectedVehicle,
      'p_session_id': value ? null : sessionId,
    });
    _guard(epoch);
    online = result['is_online'] == true;
    sessionId = result['session_id'] as String?;
    sequence = 0;
    onlineRecoveryRequired = false;
    if (online && fix != null) {
      onlineProgress = 'Đang cập nhật vị trí cho phiên hoạt động…';
      _notify();
      try {
        await _sendLocation(fix, epoch);
      } catch (failure) {
        _guard(epoch);
        try {
          final offline = await service.mutate('rescuer_set_online', {
            'p_online': false,
            'p_vehicle_id': selectedVehicle,
            'p_session_id': sessionId,
          });
          _guard(epoch);
          online = offline['is_online'] == true;
          sessionId = offline['session_id'] as String?;
        } catch (_) {
          _guard(epoch);
          onlineRecoveryRequired = true;
        }
        locationReady = false;
        requests = [];
        cursor = null;
        feedStatus = FeedStatus.error;
        feedError = rescuerError(failure);
        rethrow;
      }
      await _loadActiveJob(epoch);
      if (!hasActiveJob && jobStatus == JobStatus.empty) await _fetch(epoch);
      _schedule();
      notice = 'Bạn đang online. Vị trí và danh sách đơn mới đã được cập nhật.';
    }
    if (!online) {
      notice = 'Đã tắt online. Bạn sẽ không tìm đơn mới cho đến khi bật lại.';
    }
    onlineProgress = null;
  });
  Future<void> _sendLocation(LocationSample fix, int epoch) async {
    _guard(epoch);
    if (!_foreground) {
      throw const RescuerFailure('Mở lại ứng dụng để cập nhật vị trí.');
    }
    if (!online || sessionId == null) {
      throw const RescuerFailure('Bật online trước khi cập nhật vị trí.');
    }
    final result = await service.mutate('rescuer_update_location', {
      'p_session_id': sessionId,
      'p_sequence': ++sequence,
      'p_latitude': fix.latitude,
      'p_longitude': fix.longitude,
      'p_accuracy_m': fix.accuracy,
      'p_captured_at': fix.capturedAt.toUtc().toIso8601String(),
    });
    _guard(epoch);
    sequence = (result['sequence'] as num).toInt();
    locationReady = true;
    gpsReady = true;
  }

  Future<void> _fetch(int epoch, {bool more = false}) async {
    if (!_foreground) return;
    _guard(epoch);
    if (hasActiveJob || jobStatus != JobStatus.empty) return;
    feedStatus = FeedStatus.loading;
    feedError = null;
    _notify();
    try {
      final page = await service.available(
        selectedVehicle!,
        cursor: more ? cursor : null,
      );
      _guard(epoch);
      if (!_foreground) return;
      requests = more
          ? [
              ...requests,
              ...page.items.where(
                (r) => !requests.any((old) => old.id == r.id),
              ),
            ]
          : page.items;
      cursor = page.cursor;
      feedStatus = requests.isEmpty ? FeedStatus.empty : FeedStatus.ready;
    } catch (e) {
      if (_current(epoch)) {
        requests = [];
        cursor = null;
        feedStatus = FeedStatus.error;
        feedError = rescuerError(e);
      }
      rethrow;
    }
  }

  Future<void> refreshRequests({bool more = false}) => _run((epoch) async {
    if (!online || !canOnline || (more && cursor == null)) return;
    try {
      await _loadActiveJob(epoch);
      if (hasActiveJob || jobStatus != JobStatus.empty) return;
      if (!more) {
        locationReady = false;
        requests = [];
        cursor = null;
        final fix = await location.current();
        _guard(epoch);
        await _sendLocation(fix, epoch);
      }
      await _fetch(epoch, more: more);
      _schedule();
    } catch (e) {
      if (_current(epoch)) {
        requests = [];
        cursor = null;
        feedStatus = FeedStatus.error;
        feedError = rescuerError(e);
        _timer?.cancel();
      }
      rethrow;
    }
  });
  void _schedule() {
    _timer?.cancel();
    if (_foreground &&
        snapshot.approved &&
        ((online && canOnline) ||
            hasActiveJob ||
            jobStatus == JobStatus.error)) {
      _timer = Timer.periodic(const Duration(seconds: 45), (_) {
        if (!working && !loading) {
          unawaited(
            hasActiveJob || jobStatus == JobStatus.error
                ? refreshActiveJob()
                : refreshRequests(),
          );
        }
      });
    }
  }

  void setForeground(bool value) {
    _foreground = value;
    if (!value) {
      _timer?.cancel();
      locationReady = false;
      gpsReady = false;
      requests = [];
      cursor = null;
      feedStatus = FeedStatus.unavailable;
    }
    if (value && !working && snapshot.approved) {
      unawaited(online && canOnline ? refreshRequests() : refreshActiveJob());
    }
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _epoch++;
    _timer?.cancel();
    unawaited(_auth?.cancel());
    super.dispose();
  }
}
