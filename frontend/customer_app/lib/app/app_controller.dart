import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../services/supabase_service.dart';
import '../services/request_debug_log.dart';
import '../services/customer_profile_service.dart';
import '../services/customer_vehicle_service.dart';
import 'user_session.dart';

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

  factory RescueRequestData.fromJson(Map<String, dynamic> json) =>
      RescueRequestData(
        id: json['id'] as String,
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
}

class AppController extends ChangeNotifier {
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

  bool get backendConfigured => BackendConfiguration.isConfigured;
  bool get isLoggedIn => UserSession.isLoggedIn;

  Future<void> initialize() async {
    if (!backendConfigured) {
      restoringSession = false;
      loadError = 'Backend chưa được cấu hình.';
      notifyListeners();
      return;
    }
    _authSubscription = SupabaseService.authStateChanges.listen((state) async {
      await _restoreUser(state.session?.user);
    });
    await _restoreUser(SupabaseService.currentUser);
  }

  Future<void> _restoreUser(User? user) async {
    if (_disposed) return;
    final version = ++_sessionVersion;
    if (UserSession.userId != user?.id) {
      selectedSavedVehicle = null;
      activeRequest = null;
      history = [];
    }
    UserSession.restore(user);
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
      final profile = await SupabaseService.fetchProfile();
      if (_disposed || version != _sessionVersion) return;
      if (profileRevision == _profileRevision) {
        UserSession.restore(user, profile: profile);
      }
      await refreshRequests();
    } on AppFailure catch (error) {
      if (_disposed || version != _sessionVersion) return;
      loadError = error.message;
      notifyListeners();
    }
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
        SupabaseService.fetchActiveRequest(),
        SupabaseService.fetchHistory(),
      ]);
      if (_disposed ||
          version != _sessionVersion ||
          revision != _requestRevision) return;
      activeRequest = results[0] as RescueRequestData?;
      history = results[1] as List<RescueRequestData>;
    } on AppFailure catch (error) {
      if (_disposed ||
          version != _sessionVersion ||
          revision != _requestRevision) return;
      loadError = error.message;
      if (error.sessionExpired) UserSession.clear();
    } finally {
      if (!_disposed && version == _sessionVersion) {
        loadingRequests = false;
        notifyListeners();
      }
    }
  }

  void selectTab(int value) {
    tabIndex = value;
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
      SupabaseService.watchRequest(requestId);

  void applyTrackingUpdate(RescueRequestData request) {
    final current = activeRequest;
    if (_disposed ||
        !isLoggedIn ||
        current == null ||
        current.id != request.id ||
        request.updatedAt.isBefore(current.updatedAt)) return;
    _requestRevision++;
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
    final cancelled = await SupabaseService.cancelRequest(request.id);
    if (_disposed || customerId != UserSession.userId) return;
    _requestRevision++;
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
    notifyListeners();
  }

  Future<void> signOut() async {
    await SupabaseService.signOut();
    if (_disposed) return;
    _sessionVersion++;
    _requestRevision++;
    UserSession.clear();
    selectedSavedVehicle = null;
    activeRequest = null;
    history = [];
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _sessionVersion++;
    _authSubscription?.cancel();
    super.dispose();
  }
}
