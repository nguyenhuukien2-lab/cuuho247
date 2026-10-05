import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/backend_models.dart';

class PartnerSignUpResult {
  const PartnerSignUpResult(
    this.userId, {
    required this.needsEmailConfirmation,
  });
  final String? userId;
  final bool needsEmailConfirmation;
}

abstract class RescuerService {
  String? get userId;
  Stream<String?> get authChanges;
  Future<void> signIn(String email, String password);
  Future<PartnerSignUpResult> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
  });
  Json? get registrationProfile;
  Future<void> signOut();
  Future<RescuerSnapshot> loadSnapshot();
  Future<Json> mutate(String name, Json params);
  Future<RequestPage> available(String vehicleId, {Json? cursor});
  Future<ActiveJob?> getActiveJob();
  Future<HistoryPage> history({Json? cursor});
  Future<HistoryJob> historyJob(String assignmentId);
  Future<void> uploadDocument(
    String type,
    String? vehicleId,
    Uint8List bytes,
    String mime,
  ) async {
    throw const RescuerFailure('Upload giấy tờ sẽ bổ sung sau.');
  }
}

class SupabaseRescuerService implements RescuerService {
  @override
  Future<HistoryPage> history({Json? cursor}) async {
    if (userId == null) throw const RescuerFailure('Vui lòng đăng nhập lại.');
    final j = Json.from(
      await client.rpc(
        'rescuer_list_job_history',
        params: {'p_limit': 20, 'p_cursor': cursor, 'p_state_filter': null},
      ) as Map,
    );
    return HistoryPage(
      (j['items'] as List)
          .map((r) => HistoryJob.fromJson(Json.from(r as Map)))
          .toList(),
      j['next_cursor'] == null ? null : Json.from(j['next_cursor'] as Map),
    );
  }

  @override
  Future<HistoryJob> historyJob(String assignmentId) async {
    if (userId == null) throw const RescuerFailure('Vui lòng đăng nhập lại.');
    return HistoryJob.fromJson(
      Json.from(
        await client.rpc(
          'rescuer_get_job_history',
          params: {'p_assignment_id': assignmentId},
        ) as Map,
      ),
    );
  }

  SupabaseRescuerService(this.client);
  final SupabaseClient client;
  final Map<String, String> _pendingOperations = {};
  final Map<String, Json> _pendingUploads = {};
  static const _mutations = {
    'rescuer_register_profile',
    'rescuer_update_profile',
    'rescuer_submit_profile',
    'rescuer_register_vehicle',
    'rescuer_update_vehicle',
    'rescuer_set_capability',
    'rescuer_reserve_document',
    'rescuer_complete_document',
    'rescuer_set_online',
    'rescuer_update_location',
    'rescuer_claim_request',
    'rescuer_update_job_status',
    'rescuer_create_quote',
  };
  @override
  String? get userId => client.auth.currentUser?.id;
  @override
  Stream<String?> get authChanges =>
      client.auth.onAuthStateChange.map((event) => event.session?.user.id);
  @override
  Future<void> signIn(String email, String password) async {
    await client.auth.signInWithPassword(
      email: email.trim(),
      password: password,
    );
  }

  @override
  Future<PartnerSignUpResult> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    final result = await client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'partner_registration': true,
        'full_name': name.trim(),
        'contact_phone': phone.trim(),
      },
    );
    if (result.user == null) {
      throw const RescuerFailure(
        'Chưa xác nhận được đăng ký. Kiểm tra kết nối rồi thử lại.',
      );
    }
    return PartnerSignUpResult(
      result.user?.id,
      needsEmailConfirmation: result.session == null,
    );
  }

  // Metadata only restores entered contact details; it never grants permissions.
  @override
  Json? get registrationProfile {
    final data = client.auth.currentUser?.userMetadata;
    if (data?['partner_registration'] != true ||
        data?['full_name'] is! String ||
        data?['contact_phone'] is! String) {
      return null;
    }
    return {
      'full_name': data!['full_name'],
      'contact_phone': data['contact_phone'],
    };
  }

  @override
  Future<void> signOut() async {
    await client.auth.signOut(scope: SignOutScope.local);
    _pendingOperations.clear();
    _pendingUploads.clear();
  }

  @override
  Future<RescuerSnapshot> loadSnapshot() async {
    final uid = userId;
    if (uid == null) throw const RescuerFailure('Vui lòng đăng nhập lại.');
    final results = await Future.wait<dynamic>([
      client
          .from('rescuer_profiles')
          .select(
            'user_id,rescuer_code,full_name,contact_phone,verification_status,version',
          )
          .eq('user_id', uid)
          .maybeSingle(),
      client
          .from('rescuer_vehicles')
          .select(
            'id,kind,display_name,license_plate,verification_status,is_active,version',
          )
          .eq('rescuer_id', uid)
          .order('created_at'),
      client
          .from('rescuer_service_capabilities')
          .select(
            'vehicle_id,service_code,customer_vehicle_kind,verification_status,is_enabled',
          )
          .eq('rescuer_id', uid),
      client
          .from('rescuer_documents')
          .select(
            'id,document_type,vehicle_id,uploaded_at,verification_status,expires_at,created_at',
          )
          .eq('rescuer_id', uid),
      client
          .from('rescuer_online_status')
          .select('is_online,session_id,vehicle_id,last_seen_at')
          .eq('rescuer_id', uid)
          .maybeSingle(),
      client
          .from('rescuer_locations')
          .select('session_id,sequence')
          .eq('rescuer_id', uid)
          .maybeSingle(),
      client
          .from('rescue_services')
          .select('code,name,is_active')
          .eq('is_active', true)
          .order('sort_order'),
    ]);
    List<Json> rows(dynamic value) =>
        (value as List).map((r) => Json.from(r as Map)).toList();
    return RescuerSnapshot(
      profile: results[0] as Json?,
      vehicles: rows(results[1]),
      capabilities: rows(results[2]),
      documents: rows(results[3]),
      online: results[4] as Json?,
      location: results[5] as Json?,
      services: rows(results[6]),
    );
  }

  @override
  Future<Json> mutate(String name, Json params) async {
    if (!_mutations.contains(name)) {
      throw const RescuerFailure('Thao tác chưa được hỗ trợ.');
    }
    if (name == 'rescuer_update_job_status' &&
        (![
              'en_route',
              'arrived',
              'in_progress',
              'completed',
            ].contains(params['p_target_state']) ||
            params['p_reason_code'] != null)) {
      throw const RescuerFailure(
        'Thao tác trạng thái chuyến chưa được hỗ trợ.',
      );
    }
    if (userId == null) throw const RescuerFailure('Vui lòng đăng nhập lại.');
    final payloadKey = jsonEncode([userId, name, params]);
    final op = _pendingOperations.putIfAbsent(
      payloadKey,
      () => const Uuid().v4(),
    );
    try {
      final result = await client.rpc(
        name,
        params: {...params, 'p_operation_id': op},
      );
      _pendingOperations.remove(payloadKey);
      return Json.from(result as Map);
    } on PostgrestException {
      // The server returned a transaction failure; transport failures keep the same key.
      _pendingOperations.remove(payloadKey);
      rethrow;
    }
  }

  @override
  Future<RequestPage> available(String vehicleId, {Json? cursor}) async {
    final result = Json.from(
      await client.rpc(
        'rescuer_list_available_requests',
        params: {'p_vehicle_id': vehicleId, 'p_limit': 20, 'p_cursor': cursor},
      ) as Map,
    );
    return RequestPage(
      (result['items'] as List)
          .map((r) => AvailableRequest.fromJson(Json.from(r as Map)))
          .toList(),
      result['next_cursor'] == null
          ? null
          : Json.from(result['next_cursor'] as Map),
    );
  }

  @override
  Future<ActiveJob?> getActiveJob() async {
    if (userId == null) throw const RescuerFailure('Vui lòng đăng nhập lại.');
    final result = await client.rpc('rescuer_get_active_job');
    if (result == null) return null;
    final job = ActiveJob.fromJson(Json.from(result as Map));
    return job.assignment.isActive ? job : null;
  }

  @override
  Future<void> uploadDocument(
    String type,
    String? vehicleId,
    Uint8List bytes,
    String mime,
  ) async {
    final uid = userId;
    if (uid == null) throw const RescuerFailure('Vui lòng đăng nhập lại.');
    if (bytes.isEmpty ||
        bytes.length > 10485760 ||
        !['image/jpeg', 'image/png', 'application/pdf'].contains(mime)) {
      throw const RescuerFailure('Chọn JPEG, PNG hoặc PDF tối đa 10 MB.');
    }
    final key = jsonEncode([
      uid,
      type,
      vehicleId,
      mime,
      sha256.convert(bytes).toString(),
    ]);
    var reservation = _pendingUploads[key];
    reservation ??= await mutate('rescuer_reserve_document', {
      'p_document_type': type,
      'p_vehicle_id': vehicleId,
      'p_content_type': mime,
      'p_byte_size': bytes.length,
    });
    _pendingUploads[key] = reservation;
    void checkUser() {
      if (userId != uid) {
        throw const RescuerFailure('Phiên đăng nhập đã thay đổi.');
      }
    }

    checkUser();
    if (reservation['object_uploaded'] != true) {
      try {
        await client.storage
            .from('rescuer-documents')
            .uploadBinary(
              reservation['storage_path'] as String,
              bytes,
              fileOptions: FileOptions(contentType: mime, upsert: false),
            );
      } on StorageException catch (e) {
        // Same reserved path and content hash after a lost upload response.
        if (e.statusCode != '409') rethrow;
      }
      checkUser();
      reservation['object_uploaded'] = true;
    }
    await mutate('rescuer_complete_document', {
      'p_document_id': reservation['document_id'],
    });
    checkUser();
    _pendingUploads.remove(key);
  }
}

String rescuerError(Object error) {
  if (error is RescuerFailure) return error.message;
  if (error is AuthException) {
    return 'Đăng nhập không thành công hoặc phiên đã hết hạn. Kiểm tra email, mật khẩu và kết nối.';
  }
  if (error is PostgrestException) {
    final code = error.message;
    const messages = {
      'PROFILE_NOT_READY':
          'Hồ sơ cần được duyệt trước khi sử dụng tính năng này.',
      'PROFILE_SUSPENDED': 'Hồ sơ đang tạm ngưng. Vui lòng liên hệ hỗ trợ.',
      'VEHICLE_NOT_READY': 'Xe chưa được duyệt hoặc chưa hoạt động.',
      'CAPABILITY_UNAVAILABLE': 'Dịch vụ của xe chưa được duyệt.',
      'LOCATION_NOT_FRESH':
          'Vị trí chưa đủ mới hoặc chưa đủ chính xác. Hãy cập nhật GPS.',
      'STALE_ONLINE_SESSION':
          'Phiên online đã thay đổi. Tải lại trạng thái trước khi tiếp tục.',
      'STALE_LOCATION_SEQUENCE':
          'Vị trí đã được cập nhật ở phiên khác. Tải lại trạng thái.',
      'VERSION_CONFLICT': 'Dữ liệu đã thay đổi. Tải lại trước khi tiếp tục.',
      'INVALID_STATUS_TRANSITION': 'Không thể chuyển sang trạng thái này. Tải lại chuyến và thực hiện bước tiếp theo.',
      'DOCUMENT_NOT_READY': 'Cần hoàn tất giấy tờ trước khi gửi duyệt.',
      'INVALID_QUOTE': 'Kiểm tra số tiền, dịch vụ và ghi chú báo giá.',
      'QUOTE_REQUIRED': 'Cần báo giá đã gửi trước khi hoàn tất chuyến.',
      'QUOTE_IMMUTABLE': 'Báo giá đã gửi không thể chỉnh sửa. Tải lại chuyến để xem báo giá hiện tại.',
      'DISCOVERY_RATE_LIMITED':
          'Bạn tải đơn quá nhanh. Vui lòng thử lại sau một phút.',
      'RESCUER_BUSY':
          'Bạn đang có chuyến đang xử lý. Mở tab Đang xử lý để xem chuyến.',
      'REQUEST_UNAVAILABLE': 'Đơn đã có người nhận hoặc không còn khả dụng.',
      'PROFILE_ALREADY_EXISTS': 'Hồ sơ đã tồn tại. Hãy tải lại trạng thái.',
      'VEHICLE_ALREADY_EXISTS': 'Biển số xe đã được đăng ký trong hồ sơ.',
      'INVALID_PROFILE': 'Kiểm tra họ tên và số điện thoại (8–15 chữ số).',
      'INVALID_VEHICLE': 'Kiểm tra loại xe, tên và biển số.',
      'INVALID_SUBMISSION_STATE':
          'Hồ sơ đã gửi duyệt hoặc đã được duyệt. Hãy tải lại trạng thái.',
      'DOCUMENT_LIMIT_REACHED':
          'Đã đạt giới hạn giấy tờ. Vui lòng liên hệ hỗ trợ.',
      'INVALID_DOCUMENT':
          'Kiểm tra loại giấy tờ, xe liên quan và định dạng tệp.',
      'IDEMPOTENCY_CONFLICT':
          'Yêu cầu gửi lại không khớp. Tải lại trạng thái trước khi thử lại.',
    };
    if (messages.containsKey(code)) return messages[code]!;
    if (error.code == '42501' ||
        code.contains('row-level security') ||
        code.contains('permission denied')) {
      return 'Không đủ quyền truy cập (RLS/quyền RPC). Vui lòng tải lại hoặc liên hệ quản trị viên.';
    }
    if (error.code == 'PGRST202' || error.code == 'PGRST205') {
      return 'Dịch vụ chưa có RPC hoặc bảng cần thiết. Vui lòng liên hệ quản trị viên.';
    }
    if (error.code == 'PGRST301' || code == 'AUTHENTICATION_REQUIRED') {
      return 'Phiên đăng nhập không hợp lệ. Vui lòng đăng nhập lại.';
    }
    return 'Dịch vụ từ chối yêu cầu. Hãy tải lại trạng thái và thử lại.';
  }
  if (error is StorageException) {
    if (error.statusCode == '403' || error.statusCode == '401') {
      return 'Không có quyền tải giấy tờ. Kiểm tra phiên đăng nhập hoặc liên hệ hỗ trợ.';
    }
    return 'Chưa tải được giấy tờ lên kho riêng. Kiểm tra mạng và thử lại cùng tệp.';
  }
  return 'Không thể kết nối hoặc đọc dữ liệu. Kiểm tra mạng rồi thử lại.';
}
