import 'dart:async';
import 'dart:math';
import 'package:http/http.dart' as http;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../app/app_controller.dart';
import 'request_debug_log.dart';

class BackendConfiguration {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
    defaultValue: String.fromEnvironment('SUPABASE_ANON_KEY'),
  );
  static bool get isConfigured => url.isNotEmpty && publishableKey.isNotEmpty;
}

class AppFailure implements Exception {
  const AppFailure(this.message,
      {this.sessionExpired = false, this.locationRequired = false});
  final String message;
  final bool sessionExpired;
  final bool locationRequired;
  @override
  String toString() => message;
}

class SignUpResult {
  const SignUpResult({required this.needsEmailConfirmation});
  final bool needsEmailConfirmation;
}

class SupabaseService {
  SupabaseService._();
  static const locationRequiredFailure =
      AppFailure('Vui lòng nhập địa chỉ cứu hộ', locationRequired: true);
  static const _networkFailure = AppFailure(
      'Không kết nối được máy chủ. Thông tin đã nhập vẫn được giữ. Hãy kiểm tra kết nối Internet và thử lại.');
  // Legacy screens are not routed by the current app, but these aliases keep
  // them analyzable until that UI is removed.
  static String get supabaseUrl => BackendConfiguration.url;
  static String get anonKey => BackendConfiguration.publishableKey;
  static SupabaseClient get _client => Supabase.instance.client;
  static User? get currentUser =>
      BackendConfiguration.isConfigured ? _client.auth.currentUser : null;
  static Stream<AuthState> get authStateChanges =>
      _client.auth.onAuthStateChange;

  static Future<SignUpResult> signUp(
      {required String email,
      required String password,
      required String fullName,
      required String phone}) async {
    _requireConfigured();
    try {
      final response = await _client.auth.signUp(
          email: email,
          password: password,
          data: {'full_name': fullName, 'phone': phone});
      return SignUpResult(needsEmailConfirmation: response.session == null);
    } on AuthException catch (error) {
      throw AppFailure(_authMessage(error));
    } catch (_) {
      throw const AppFailure(
          'Không thể kết nối máy chủ. Hãy kiểm tra mạng và thử lại.');
    }
  }

  static Future<void> signIn(
      {required String email, required String password}) async {
    _requireConfigured();
    try {
      await _client.auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (error) {
      throw AppFailure(_authMessage(error));
    } catch (_) {
      throw const AppFailure(
          'Không thể kết nối máy chủ. Hãy kiểm tra mạng và thử lại.');
    }
  }

  static Future<void> signOut() async {
    _requireConfigured();
    try {
      await _client.auth.signOut();
    } on AuthException catch (error) {
      throw AppFailure(_authMessage(error));
    } catch (_) {
      throw const AppFailure('Không thể đăng xuất. Vui lòng thử lại.');
    }
  }

  static Future<Map<String, dynamic>?> fetchProfile() async {
    final user = _requireUser();
    try {
      return await _client
          .from('customer_profiles')
          .select()
          .eq('user_id', user.id)
          .maybeSingle()
          .timeout(const Duration(seconds: 20));
    } on PostgrestException catch (error) {
      throw _databaseFailure(error);
    } on http.ClientException {
      throw _networkFailure;
    } on TimeoutException {
      throw _networkFailure;
    }
  }

  static Future<List<dynamic>> fetchNearbyProviders(
      {required double lat,
      required double lng,
      double maxDistanceKm = 15}) async {
    _requireConfigured();
    try {
      return await _client.rpc('get_nearby_providers', params: {
        'customer_lat': lat,
        'customer_lng': lng,
        'max_distance_km': maxDistanceKm,
      }) as List<dynamic>;
    } on PostgrestException catch (error) {
      throw _databaseFailure(error);
    } on http.ClientException {
      throw _networkFailure;
    } on TimeoutException {
      throw _networkFailure;
    }
  }

  static Future<RescueRequestData?> fetchActiveRequest() async {
    final user = _requireUser();
    try {
      final row = await _client
          .from('rescue_requests')
          .select()
          .eq('customer_id', user.id)
          .inFilter('status',
              const ['searching', 'accepted', 'arriving', 'in_progress'])
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle()
          .timeout(const Duration(seconds: 20));
      return row == null ? null : RescueRequestData.fromJson(row);
    } on PostgrestException catch (error) {
      throw _databaseFailure(error);
    } on http.ClientException {
      throw _networkFailure;
    } on TimeoutException {
      throw _networkFailure;
    }
  }

  static Future<List<RescueRequestData>> fetchHistory() async {
    final user = _requireUser();
    try {
      final rows = await _client
          .from('rescue_requests')
          .select()
          .eq('customer_id', user.id)
          .inFilter('status', const ['completed', 'cancelled'])
          .order('created_at', ascending: false)
          .limit(100)
          .timeout(const Duration(seconds: 20));
      return rows
          .map<RescueRequestData>(RescueRequestData.fromJson)
          .toList(growable: false);
    } on PostgrestException catch (error) {
      throw _databaseFailure(error);
    } on http.ClientException {
      throw _networkFailure;
    } on TimeoutException {
      throw _networkFailure;
    }
  }

  static Future<RescueRequestData> createRescueRequest(
      {required String clientRequestId,
      required VehicleKind vehicle,
      required RescueService service,
      required String locationText,
      required String description,
      required String contactName,
      required String contactPhone,
      String? vehicleId,
      SupabaseClient? client,
      double? latitude,
      double? longitude}) async {
    SupabaseClient? requestClient;
    void logFailure(String step, Object error, StackTrace stackTrace) {
      logRequestFailure(step, error, stackTrace,
          client: requestClient,
          sensitiveValues: [
            locationText,
            locationText.trim(),
            description,
            description.trim(),
            contactName,
            contactName.trim(),
            contactPhone,
            contactPhone.trim(),
            latitude?.toString(),
            longitude?.toString(),
          ]);
    }

    logRequestStep('service.createRescueRequest.begin');
    try {
      final trimmedLocation = locationText.trim();
      if (trimmedLocation.isEmpty) throw locationRequiredFailure;
      if (client == null) {
        _requireUser();
      } else if (client.auth.currentUser == null) {
        throw const AppFailure('Vui lòng đăng nhập lại.', sessionExpired: true);
      }
      requestClient = client ?? _client;
      final row = await requestClient
          .rpc('create_customer_rescue_request', params: {
            'p_client_request_id': clientRequestId,
            'p_vehicle_kind': vehicle.name,
            'p_service_code': service.name,
            'p_location_text': trimmedLocation,
            'p_description': description,
            'p_contact_name': contactName,
            'p_contact_phone': contactPhone,
            'p_vehicle_id': vehicleId,
            'p_latitude': latitude,
            'p_longitude': longitude,
          })
          .single()
          .timeout(const Duration(seconds: 20));
      return RescueRequestData.fromJson(row);
    } on PostgrestException catch (error, stackTrace) {
      logFailure('service.createRescueRequest.rpc', error, stackTrace);
      throw _databaseFailure(error);
    } on http.ClientException catch (error, stackTrace) {
      logFailure('service.createRescueRequest.network', error, stackTrace);
      throw _networkFailure;
    } on TimeoutException catch (error, stackTrace) {
      logFailure('service.createRescueRequest.timeout', error, stackTrace);
      throw _networkFailure;
    } on AuthException catch (error, stackTrace) {
      logFailure('service.createRescueRequest.auth', error, stackTrace);
      throw const AppFailure(
          'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
          sessionExpired: true);
    } on AppFailure {
      rethrow;
    } catch (error, stackTrace) {
      logFailure('service.createRescueRequest', error, stackTrace);
      throw const AppFailure(
          'Máy chủ chưa thể xử lý yêu cầu. Dữ liệu đã nhập vẫn được giữ, hãy thử lại.');
    }
  }

  static Future<RescueRequestData> cancelRequest(String requestId) async {
    _requireUser();
    try {
      final row = await _client
          .rpc('cancel_own_rescue_request', params: {'request_id': requestId})
          .single()
          .timeout(const Duration(seconds: 20));
      return RescueRequestData.fromJson(Map<String, dynamic>.from(row as Map));
    } on PostgrestException catch (error) {
      throw _databaseFailure(error);
    } on http.ClientException {
      throw _networkFailure;
    } on TimeoutException {
      throw _networkFailure;
    }
  }

  /// One row per channel; each successful (re)join reloads a snapshot to recover
  /// changes missed while disconnected. Canceling the stream removes the channel.
  static Stream<RescueRequestData> watchRequest(String requestId) {
    final user = _requireUser();
    final client = _client;
    late final StreamController<RescueRequestData> stream;
    RealtimeChannel? channel;
    StreamSubscription<AuthState>? auth;
    var stopped = false;
    var changeVersion = 0;

    bool getCanEmit() =>
        !stopped && !stream.isClosed && client.auth.currentUser?.id == user.id;

    void emit(Map<String, dynamic> row) {
      if (!getCanEmit() ||
          row['id'] != requestId ||
          row['customer_id'] != user.id) return;
      try {
        stream.add(RescueRequestData.fromJson(row));
      } catch (_) {
        stream.addError(const AppFailure('Không đọc được trạng thái yêu cầu.'));
      }
    }

    Future<void> reload() async {
      final version = ++changeVersion;
      try {
        final row = await client
            .from('rescue_requests')
            .select()
            .eq('id', requestId)
            .eq('customer_id', user.id)
            .maybeSingle()
            .timeout(const Duration(seconds: 20));
        if (getCanEmit() && version == changeVersion && row != null) emit(row);
      } catch (_) {
        if (getCanEmit() && version == changeVersion) {
          stream.addError(_networkFailure);
        }
      }
    }

    stream = StreamController<RescueRequestData>(
      onListen: () {
        auth = client.auth.onAuthStateChange.listen((state) {
          if (state.session?.user.id != user.id) {
            unawaited(stream.close());
          }
        });
        channel = client
            .channel('customer-request:$requestId:${newClientRequestId()}')
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'rescue_requests',
              filter: PostgresChangeFilter(
                  type: PostgresChangeFilterType.eq,
                  column: 'id',
                  value: requestId),
              callback: (payload) {
                changeVersion++;
                emit(payload.newRecord);
              },
            )
            .subscribe((status, error) {
          if (!getCanEmit()) return;
          if (status == RealtimeSubscribeStatus.subscribed) {
            unawaited(reload());
          } else if (status == RealtimeSubscribeStatus.channelError ||
              status == RealtimeSubscribeStatus.timedOut ||
              status == RealtimeSubscribeStatus.closed) {
            stream.addError(const AppFailure(
                'Kết nối cập nhật bị gián đoạn. Đang thử kết nối lại; bạn có thể cập nhật thủ công.'));
          }
        });
      },
      onCancel: () async {
        stopped = true;
        changeVersion++;
        await auth?.cancel();
        final current = channel;
        if (current != null) await client.removeChannel(current);
      },
    );
    return stream.stream;
  }

  static String newClientRequestId() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    String hex(int value) => value.toRadixString(16).padLeft(2, '0');
    final value = bytes.map(hex).join();
    return '${value.substring(0, 8)}-${value.substring(8, 12)}-${value.substring(12, 16)}-${value.substring(16, 20)}-${value.substring(20)}';
  }

  static User _requireUser() {
    _requireConfigured();
    final user = _client.auth.currentUser;
    if (user == null)
      throw const AppFailure(
          'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
          sessionExpired: true);
    return user;
  }

  static void _requireConfigured() {
    if (!BackendConfiguration.isConfigured)
      throw const AppFailure(
          'Backend chưa được cấu hình. Hãy cung cấp SUPABASE_URL và SUPABASE_PUBLISHABLE_KEY.');
  }

  static AppFailure _databaseFailure(PostgrestException error) {
    final message = error.message.trim().toUpperCase();
    if (message == 'LOCATION_REQUIRED') return locationRequiredFailure;
    if (message == 'ACTIVE_REQUEST_EXISTS' ||
        message == 'EXISTING_ACTIVE_REQUEST' ||
        message == 'CUSTOMER_HAS_ACTIVE_REQUEST' ||
        (error.code == '23505' &&
            '${error.message} ${error.details}'
                .contains('rescue_requests_one_active_per_customer'))) {
      return const AppFailure(
          'Bạn đang có một yêu cầu được xử lý. Hãy mở tab Đang xử lý để kiểm tra yêu cầu hiện tại.');
    }
    if (message == 'AUTHENTICATION_REQUIRED' || error.code == 'PGRST302') {
      return const AppFailure(
          'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
          sessionExpired: true);
    }
    if (error.code == 'PGRST301' || error.code == 'PGRST303')
      return const AppFailure(
          'Phiên đăng nhập đã hết hạn. Vui lòng đăng nhập lại.',
          sessionExpired: true);
    if (error.code == '42501') {
      return const AppFailure('Bạn không có quyền thực hiện thao tác này.');
    }
    if (error.code == 'P0001') {
      return const AppFailure(
          'Yêu cầu không thể hủy ở trạng thái hiện tại. Hãy cập nhật trạng thái.');
    }
    if (error.code == '23503')
      return const AppFailure(
          'Dịch vụ hoặc phương tiện không còn hợp lệ. Hãy tải lại và thử lại.');
    return const AppFailure(
        'Máy chủ chưa thể xử lý yêu cầu. Dữ liệu đã nhập vẫn được giữ, hãy thử lại.');
  }

  static String _authMessage(AuthException error) {
    final message = error.message.toLowerCase();
    if (message.contains('invalid login credentials'))
      return 'Email hoặc mật khẩu không đúng.';
    if (message.contains('email not confirmed'))
      return 'Email chưa được xác nhận. Hãy kiểm tra hộp thư rồi thử lại.';
    if (message.contains('already registered'))
      return 'Email này đã được đăng ký.';
    if (message.contains('password'))
      return 'Mật khẩu chưa đáp ứng yêu cầu bảo mật của hệ thống.';
    return 'Không thể xác thực tài khoản. Vui lòng kiểm tra thông tin và thử lại.';
  }
}
