import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../services/request_debug_log.dart';
import '../services/customer_profile_service.dart';
import '../services/customer_vehicle_service.dart';
import 'user_session.dart';
import 'customer_gps_controller.dart';
import '../services/location_service.dart';
import '../services/payment_service.dart';
import 'payment_watcher.dart';

enum VehicleKind { motorbike, car, truck, other }

extension VehicleKindText on VehicleKind {
  String get label => switch (this) {
        VehicleKind.motorbike => 'Xe máy',
        VehicleKind.car => 'Ô tô',
        VehicleKind.truck => 'Xe tải',
        VehicleKind.other => 'Khác',
      };
}

enum RescueService { tire, battery, fuel, towing, other }

enum RequestStage {
  searching,
  accepted,
  arriving,
  inProgress,
  completed,
  cancelled
}

extension RequestStageContract on RequestStage {
  String get databaseValue =>
      this == RequestStage.inProgress ? 'in_progress' : name;
  bool get isTerminal =>
      this == RequestStage.completed || this == RequestStage.cancelled;
}

extension RescueServiceText on RescueService {
  String get label => switch (this) {
        RescueService.tire => 'Vá lốp',
        RescueService.battery => 'Kích bình',
        RescueService.fuel => 'Tiếp nhiên liệu',
        RescueService.towing => 'Kéo xe',
        RescueService.other => 'Khác',
      };
}

class RescueRequestData {
  RescueRequestData(
      {required this.id,
      this.requestCode,
      this.quoteCode,
      required this.service,
      required this.vehicle,
      required this.address,
      required this.createdAt,
      required this.stage,
      this.description = '',
      this.contactName = '',
      this.contactPhone = '',
      this.price,
      this.latitude,
      this.longitude,
      this.clientRequestId,
      this.vehicleId,
      DateTime? updatedAt})
      : hasServerUpdateTime = updatedAt != null,
        updatedAt = updatedAt ?? createdAt;
  final String id;
  final String? requestCode, quoteCode;
  final RescueService service;
  final VehicleKind vehicle;
  final String address;
  final DateTime createdAt;
  final DateTime updatedAt;
  final bool hasServerUpdateTime;
  RequestStage stage;
  final String description;
  final String contactName;
  final String contactPhone;
  final int? price;
  final double? latitude;
  final double? longitude;
  final String? clientRequestId;
  final String? vehicleId;

  factory RescueRequestData.fromJson(Map<String, dynamic> json) {
    try {
      return RescueRequestData(
        id: json['id'] as String,
        requestCode: json['request_code'] as String?,
        quoteCode: json['quote_code'] as String?,
        clientRequestId: json['client_request_id'] as String?,
        vehicleId: json['vehicle_id'] as String?,
        service: RescueService.values.byName(json['service_code'] as String),
        vehicle: VehicleKind.values.byName(json['vehicle_kind'] as String),
        address: json['location_text'] as String,
        createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
        stage: RequestStage.values
            .singleWhere((stage) => stage.databaseValue == json['status']),
        updatedAt: json['updated_at'] == null
            ? null
            : DateTime.parse(json['updated_at'] as String).toLocal(),
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        description: json['description'] as String? ?? '',
        contactName: json['contact_name'] as String? ?? '',
        contactPhone: json['contact_phone'] as String? ?? '',
        price: json['quoted_price'] as int?,
      );
    } catch (_) {
      throw const AppFailure(
          'Dữ liệu yêu cầu từ máy chủ không hợp lệ hoặc chưa được hỗ trợ. Vui lòng tải lại.');
    }
  }
}

class AppController extends ChangeNotifier {
  AppController(
      {this.client,
      CustomerLocationService? locationService,
      PaymentSource? paymentSource,
      String Function()? paymentOperationId})
      : payments = PaymentWatcher(
            paymentSource ?? SupabaseService.paymentSource(client: client)),
        _paymentOperationId = paymentOperationId ?? newPaymentOperationId,
        gps = CustomerGpsController(
            locationService ?? const GeolocatorLocationService()) {
    gps.addListener(_gpsChanged);
    _paymentCommandOwner = payments.source?.userId;
    payments.addListener(_paymentChanged);
  }
  final SupabaseClient? client;
  final CustomerGpsController gps;
  final PaymentWatcher payments;

  final String Function() _paymentOperationId;
  final Map<String, _PaymentAction> _paymentActions = {};
  String? _paymentCommandOwner, _paymentRouteRequest, _paymentRouteOwner;
  Object? _paymentRouteToken;
  int _paymentCommandGeneration = 0;

  Future<void> loadPayment(String requestId) => watchPayment(requestId);
  Future<void> watchPayment(String requestId) {
    // Background tracking/hydration must not steal an explicitly opened route.
    if (_paymentRouteToken != null &&
        (_paymentRouteRequest != requestId ||
            _paymentRouteOwner != payments.source?.userId))
      return Future<void>.value();
    return payments.watch(requestId);
  }

  Future<void> refreshPayment() => payments.refresh();
  void clearPayment() {
    _paymentCommandGeneration++;
    _paymentActions.clear();
    payments.clear();
  }

  Object bindPaymentRequest(String requestId) {
    final token = Object();
    _paymentRouteToken = token;
    _paymentRouteRequest = requestId;
    _paymentRouteOwner = payments.source?.userId;
    if (!isPaymentRequestId(requestId) || _paymentRouteOwner == null) {
      clearPayment();
    }
    return token;
  }

  bool ownsPaymentRoute(Object? token, String requestId, String? owner) =>
      token != null &&
      identical(token, _paymentRouteToken) &&
      requestId == _paymentRouteRequest &&
      owner != null &&
      owner == _paymentRouteOwner &&
      owner == payments.source?.userId;

  void releasePaymentRequest(Object? token) {
    if (!identical(token, _paymentRouteToken)) return;
    _paymentRouteToken = null;
    _paymentRouteRequest = null;
    _paymentRouteOwner = null;
  }

  bool paymentSubmitting(String id) => _paymentActions[id]?.task != null;
  String? paymentCommandError(String id) => _paymentActions[id]?.error;
  String? paymentCommandNotice(String id) => _paymentActions[id]?.notice;
  bool paymentSelectionNeedsRefresh(String id) =>
      _paymentActions[id]?.selectionAcknowledged ?? false;
  bool paymentMethodRetryBlocked(String id, {required bool bank}) => bank
      ? _paymentActions[id]?.cash != null
      : _paymentActions[id]?.bank != null;

  void _paymentChanged() {
    final owner = payments.source?.userId;
    if (_paymentCommandOwner != owner) {
      _paymentCommandOwner = owner;
      // A page from an earlier login must stay invalid even after A -> B -> A.
      _paymentRouteOwner = null;
      _paymentCommandGeneration++;
      _paymentActions.clear();
    }
    _gpsChanged();
  }

  Future<bool> preparePayment(String requestId) =>
      _paymentCommand(requestId, selectCash: false);
  Future<bool> selectCashPayment(String requestId) =>
      _paymentCommand(requestId, selectCash: true);
  Future<bool> selectBankPayment(String requestId) =>
      _paymentCommand(requestId, selectCash: false, selectBank: true);
  Future<bool> regenerateBankPayment(String requestId) =>
      _paymentCommand(requestId, selectCash: false, regenerateBank: true);

  Future<bool> _paymentCommand(String id,
      {required bool selectCash,
      bool selectBank = false,
      bool regenerateBank = false}) {
    final source = payments.source;
    final owner = source?.userId;
    if (_disposed ||
        owner == null ||
        owner != _paymentCommandOwner ||
        !isPaymentRequestId(id) ||
        payments.requestId != id ||
        (_paymentRouteToken != null &&
            (_paymentRouteOwner != owner || _paymentRouteRequest != id))) {
      return Future<bool>.value(false);
    }
    final state = _paymentActions.putIfAbsent(id, _PaymentAction.new);
    if (state.task != null) return state.task!;
    if (source is! PaymentCommands) {
      state.error = 'PAYMENT_COMMAND_UNAVAILABLE';
      _gpsChanged();
      return Future<bool>.value(false);
    }
    final dto = payments.payment;
    final bankDto = payments.bankPayment;
    if ((selectBank && state.cash != null) ||
        (selectCash && state.bank != null)) {
      return Future<bool>.value(false);
    }
    if (selectBank && state.bank == null) {
      if (source is! BankPaymentSource ||
          !payments.bankAvailable ||
          payments.stale ||
          dto == null ||
          dto.requestId != id ||
          dto.status != 'pending' ||
          dto.method != null ||
          payments.loading ||
          payments.error != null ||
          state.selectionAcknowledged) return Future<bool>.value(false);
      state.bank = BankPaymentSelection(
          requestId: id,
          paymentId: dto.paymentId,
          expectedVersion: dto.version,
          operationId: _paymentOperationId());
    }
    if (selectCash && state.cash == null) {
      if (dto == null ||
          dto.requestId != id ||
          dto.status != 'pending' ||
          dto.method != null ||
          payments.loading ||
          payments.error != null ||
          state.selectionAcknowledged) return Future<bool>.value(false);
      state.cash = CashPaymentSelection(
          requestId: id,
          paymentId: dto.paymentId,
          expectedVersion: dto.version,
          operationId: _paymentOperationId());
    }
    if (regenerateBank && state.regeneration == null) {
      if (source is! BankPaymentSource ||
          dto == null ||
          bankDto == null ||
          dto.requestId != id ||
          dto.method != 'bank_transfer' ||
          dto.status != 'awaiting_payment' ||
          !bankDto.matches(dto) ||
          bankDto.intentStatus != 'expired' ||
          !bankDto.available ||
          payments.loading ||
          payments.stale ||
          payments.error != null ||
          payments.bankError != null) return Future<bool>.value(false);
      state.regeneration = BankPaymentRegeneration(
          requestId: id,
          paymentId: dto.paymentId,
          expectedVersion: dto.version,
          expectedIntentId: bankDto.intentId,
          expectedIntentVersion: bankDto.intentVersion,
          operationId: _paymentOperationId());
    }
    if (!selectCash &&
        !selectBank &&
        !regenerateBank &&
        (dto != null || payments.loading || payments.error != null)) {
      return Future<bool>.value(false);
    }
    final generation = _paymentCommandGeneration;
    bool current() =>
        !_disposed &&
        generation == _paymentCommandGeneration &&
        source!.userId == owner &&
        identical(_paymentActions[id], state);
    final completion = Completer<bool>();
    state.task =
        completion.future; // Reserve before notifying: double taps share it.
    state.error = null;
    state.notice = null;
    _gpsChanged();
    unawaited(() async {
      var success = false;
      try {
        final commands = source as PaymentCommands;
        if (regenerateBank) {
          await (source as BankPaymentSource)
              .regenerateBank(state.regeneration!);
        } else if (selectBank) {
          await (source as BankPaymentSource).selectBank(state.bank!);
        } else if (selectCash) {
          await commands.selectCash(state.cash!);
        } else {
          await commands.prepare(id);
        }
        if (!current()) return;
        state.cash = null;
        state.bank = null;
        state.regeneration = null;
        state.selectionAcknowledged = selectCash || selectBank;
        state.notice = selectCash
            ? 'Đã chọn tiền mặt. Chờ đối tác xác nhận thu tiền.'
            : null;
        success = true;
      } on PaymentAccessDenied {
        if (!current()) return;
        state.cash = null;
        state.bank = null;
        state.regeneration = null;
        state.error = 'PAYMENT_NOT_ACCESSIBLE';
        if (payments.requestId == id) payments.clear();
      } on PaymentCommandFailure catch (failure) {
        if (!current()) return;
        state.error = failure.code;
        if (!failure.outcomeUnknown) {
          state.cash = null;
          state.bank = null;
          state.regeneration = null;
        }
      } catch (_) {
        if (!current()) return;
        // Includes timeout from an injected transport; preserve the exact payload.
        state.error = 'PAYMENT_COMMAND_UNCERTAIN';
      } finally {
        if (current()) {
          // Never use a command/replay DTO as payment state.
          if (payments.requestId == id &&
              state.error != 'PAYMENT_NOT_ACCESSIBLE') {
            await payments.refresh();
          }
          if (current()) {
            state.task = null;
            _gpsChanged();
          }
        }
        completion.complete(success && current());
      }
    }());
    return completion.future;
  }

  void _watchCurrentPayment() {
    if (activeRequest != null) {
      if (payments.requestId != activeRequest!.id) {
        unawaited(watchPayment(activeRequest!.id));
      }
      return;
    }
    if (payments.requestId != null) return;
    final request =
        history.where((r) => r.stage == RequestStage.completed).firstOrNull;
    if (request != null) unawaited(watchPayment(request.id));
  }

  void _gpsChanged() {
    if (!_disposed) notifyListeners();
  }

  void setForeground(bool value) {
    gps.setForeground(value);
    payments.setForeground(value);
  }

  int tabIndex = 0;
  VehicleKind vehicle = VehicleKind.car;
  CustomerVehicle? selectedSavedVehicle;
  int vehiclesRevision = 0;
  RescueService? selectedService;
  RescueRequestData? activeRequest;
  List<RescueRequestData> history = [];
  bool restoringSession = true;
  bool loadingRequests = false;
  String? loadError;
  StreamSubscription<AuthState>? _authSubscription;
  int _sessionVersion = 0;
  int _requestRevision = 0;
  int _profileRevision = 0;
  bool _disposed = false;
  bool _initialized = false;

  bool get backendConfigured =>
      client != null || BackendConfiguration.isConfigured;
  bool get isLoggedIn => UserSession.isLoggedIn;

  Future<void> initialize() async {
    if (_initialized || _disposed) return;
    _initialized = true;
    gps.setUser(UserSession.userId);
    if (!backendConfigured) {
      restoringSession = false;
      loadError = 'Backend chưa được cấu hình.';
      notifyListeners();
      return;
    }
    _authSubscription =
        (client?.auth.onAuthStateChange ?? SupabaseService.authStateChanges)
            .listen((state) async {
      // The explicit current-user restore below owns initial hydration.
      if (state.event == AuthChangeEvent.initialSession) return;
      await _restoreUser(state.session?.user);
    });
    await _restoreUser(client != null
        ? client!.auth.currentUser
        : SupabaseService.currentUser);
  }

  Future<void> _restoreUser(User? user) async {
    if (_disposed) return;
    final version = ++_sessionVersion;
    final sameUser = user != null && UserSession.userId == user.id;
    if (!sameUser) {
      clearPayment();
      selectedSavedVehicle = null;
      activeRequest = null;
      history = [];
    }
    if (sameUser) {
      // Token refresh must not replace an edited profile with old Auth metadata.
      UserSession.email = user.email;
    } else {
      UserSession.restore(user);
    }
    gps.setUser(UserSession.userId);
    restoringSession = false;
    // Notify immediately on identity changes, before any profile/network wait,
    // so tracking cannot keep a subscription belonging to the previous user.
    notifyListeners();
    if (user == null) {
      loadingRequests = false;
      activeRequest = null;
      history = [];
      loadError = null;
      notifyListeners();
      return;
    }
    try {
      final profileRevision = _profileRevision;
      final profile = await SupabaseService.fetchProfile(client: client);
      if (_disposed || version != _sessionVersion) return;
      if (profileRevision == _profileRevision) {
        UserSession.restore(user, profile: profile);
      }
    } on AppFailure catch (error) {
      if (_disposed || version != _sessionVersion) return;
      loadError = error.message;
      if (error.sessionExpired) {
        _clearSession();
        notifyListeners();
        return;
      }
      notifyListeners();
    }
    if (!_disposed && version == _sessionVersion) await refreshRequests();
  }

  void _clearSession() {
    clearPayment();
    _sessionVersion++;
    _requestRevision++;
    UserSession.clear();
    gps.setUser(null);
    selectedSavedVehicle = null;
    activeRequest = null;
    history = [];
    loadingRequests = false;
  }

  Future<void> refreshRequests() async {
    if (!isLoggedIn) return;
    final version = _sessionVersion;
    final revision = ++_requestRevision;
    loadingRequests = true;
    loadError = null;
    notifyListeners();
    try {
      final results = await Future.wait<dynamic>([
        SupabaseService.fetchActiveRequest(client: client),
        SupabaseService.fetchHistory(client: client),
      ]);
      if (_disposed ||
          version != _sessionVersion ||
          revision != _requestRevision) return;
      activeRequest = results[0] as RescueRequestData?;
      history = results[1] as List<RescueRequestData>;
      _watchCurrentPayment();
    } on AppFailure catch (error) {
      if (_disposed ||
          version != _sessionVersion ||
          revision != _requestRevision) return;
      loadError = error.message;
      if (error.sessionExpired) {
        _clearSession();
        notifyListeners();
      }
    } finally {
      if (!_disposed &&
          version == _sessionVersion &&
          revision == _requestRevision) {
        loadingRequests = false;
        notifyListeners();
      }
    }
  }

  void selectTab(int value) {
    tabIndex = value;
    gps.setUser(UserSession.userId);
    if (isLoggedIn && [0, 1, 2].contains(value)) unawaited(gps.refresh());
    notifyListeners();
  }

  void applyCustomerProfile(CustomerProfile profile) {
    if (_disposed || UserSession.userId != profile.userId) return;
    _profileRevision++;
    UserSession.fullName = profile.fullName;
    UserSession.phoneNumber = profile.phone;
    UserSession.email = profile.email;
    notifyListeners();
  }

  void startRequest({RescueService? service}) {
    if (service != null) selectedService = service;
    tabIndex = 1;
    gps.setUser(UserSession.userId);
    if (isLoggedIn) unawaited(gps.refresh());
    notifyListeners();
  }

  void selectVehicle(VehicleKind value) {
    selectedSavedVehicle = null;
    vehicle = value;
    notifyListeners();
  }

  void selectSavedVehicle(CustomerVehicle value) {
    if (_disposed || value.customerId != UserSession.userId) return;
    selectedSavedVehicle = value;
    vehicle = value.kind;
    notifyListeners();
  }

  void vehicleChanged(String id, {CustomerVehicle? replacement}) {
    if (_disposed) return;
    if (selectedSavedVehicle?.id == id) {
      selectedSavedVehicle = replacement;
      if (replacement != null) vehicle = replacement.kind;
    }
    vehiclesRevision++;
    notifyListeners();
  }

  void selectService(RescueService value) {
    selectedService = value;
    notifyListeners();
  }

  Future<RescueRequestData> createRequest(
      {required String clientRequestId,
      required String address,
      required String description,
      required String contactName,
      required String contactPhone,
      double? latitude,
      double? longitude,
      bool openTracking = true}) async {
    logRequestStep('controller.createRequest.begin');
    try {
      final trimmedAddress = address.trim();
      if (trimmedAddress.isEmpty) throw SupabaseService.locationRequiredFailure;
      final service = selectedService;
      final customerId = UserSession.userId;
      if (service == null) throw const AppFailure('Vui lòng chọn loại sự cố.');
      final request = await SupabaseService.createRescueRequest(
        clientRequestId: clientRequestId,
        vehicle: vehicle,
        vehicleId: selectedSavedVehicle?.id,
        client: client,
        service: service,
        locationText: trimmedAddress,
        description: description,
        contactName: contactName,
        contactPhone: contactPhone,
        latitude: latitude,
        longitude: longitude,
      );
      if (_disposed || customerId != UserSession.userId) {
        throw const AppFailure(
            'Phiên đăng nhập đã thay đổi. Vui lòng đăng nhập lại.',
            sessionExpired: true);
      }
      if (request.stage == RequestStage.completed ||
          request.stage == RequestStage.cancelled) {
        // An idempotent retry can return an already finished order.
        if (activeRequest?.id == request.id) activeRequest = null;
        history = [request, ...history.where((item) => item.id != request.id)];
        if (openTracking) tabIndex = 3;
      } else {
        activeRequest = request;
        if (openTracking) tabIndex = 2;
      }
      loadError = null;
      _requestRevision++;
      loadingRequests = false;
      unawaited(watchPayment(request.id));
      notifyListeners();
      return request;
    } catch (error, stackTrace) {
      logRequestFailure('controller.createRequest', error, stackTrace,
          sensitiveValues: [
            address,
            address.trim(),
            description,
            contactName,
            contactPhone,
            latitude?.toString(),
            longitude?.toString()
          ]);
      rethrow;
    }
  }

  Stream<RescueRequestData> watchRequest(String requestId) =>
      SupabaseService.watchRequest(requestId, client: client);

  void applyTrackingUpdate(RescueRequestData request) {
    final current = activeRequest;
    if (_disposed ||
        !isLoggedIn ||
        current == null ||
        current.id != request.id ||
        request.updatedAt.isBefore(current.updatedAt)) return;
    _requestRevision++;
    unawaited(watchPayment(request.id));
    loadingRequests = false;
    loadError = null;
    if (request.stage.isTerminal) {
      activeRequest = null;
      history = [request, ...history.where((item) => item.id != request.id)];
      if (tabIndex == 2) tabIndex = 3;
    } else {
      activeRequest = request;
    }
    notifyListeners();
  }

  Future<void> cancelActiveRequest() async {
    final customerId = UserSession.userId;
    final request = activeRequest;
    if (request == null) return;
    final cancelled =
        await SupabaseService.cancelRequest(request.id, client: client);
    if (_disposed || customerId != UserSession.userId) return;
    _requestRevision++;
    loadingRequests = false;
    if (activeRequest?.id == cancelled.id) activeRequest = null;
    history = [cancelled, ...history.where((item) => item.id != cancelled.id)];
    tabIndex = 3;
    notifyListeners();
  }

  void repeatRequest(RescueRequestData request) {
    selectedSavedVehicle = null;
    selectedService = request.service;
    vehicle = request.vehicle;
    tabIndex = 1;
    gps.setUser(UserSession.userId);
    if (isLoggedIn) unawaited(gps.refresh());
    notifyListeners();
  }

  Future<void> signOut() async {
    clearPayment();
    if (client == null) {
      await SupabaseService.signOut();
    } else {
      await client!.auth.signOut();
    }
    if (_disposed) return;
    _clearSession();
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionVersion++;
    _authSubscription?.cancel();
    gps.removeListener(_gpsChanged);
    gps.dispose();
    _paymentCommandGeneration++;
    _paymentActions.clear();
    payments.removeListener(_paymentChanged);
    payments.dispose();
    super.dispose();
  }
}

class _PaymentAction {
  Future<bool>? task;
  CashPaymentSelection? cash;
  BankPaymentSelection? bank;
  BankPaymentRegeneration? regeneration;
  String? error, notice;
  bool selectionAcknowledged = false;
}
