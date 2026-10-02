import 'package:supabase_flutter/supabase_flutter.dart';

import 'supabase_service.dart';

class RequestDetails {
  const RequestDetails(this.request, this.events);
  final Map<String, dynamic> request;
  final List<Map<String, dynamic>> events;

  DateTime? get terminalTime {
    for (final event in events.reversed) {
      if (event['status'] == request['status'] &&
          event['is_initial_snapshot'] != true &&
          (event['status'] == 'completed' || event['status'] == 'cancelled')) {
        return DateTime.tryParse(event['occurred_at']?.toString() ?? '');
      }
    }
    return null;
  }
}

abstract interface class RequestDetailsRepository {
  Future<RequestDetails?> load(String requestId);
}

class SupabaseRequestDetailsRepository implements RequestDetailsRepository {
  const SupabaseRequestDetailsRepository({this.client});
  final SupabaseClient? client;

  @override
  Future<RequestDetails?> load(String requestId) async {
    if (client == null && !BackendConfiguration.isConfigured) {
      throw const AppFailure('Backend chưa được cấu hình.');
    }
    final db = client ?? Supabase.instance.client;
    final owner = db.auth.currentUser?.id;
    if (owner == null) {
      throw const AppFailure('Vui lòng đăng nhập lại.',
          sessionExpired: true);
    }
    final row = await db
        .from('rescue_requests')
        .select()
        .eq('id', requestId)
        .eq('customer_id', owner)
        .maybeSingle()
        .timeout(const Duration(seconds: 20));
    if (db.auth.currentUser?.id != owner) {
      throw const AppFailure('Phiên đăng nhập đã thay đổi.',
          sessionExpired: true);
    }
    if (row == null) return null;
    final events = await db
        .from('request_status_events')
        .select()
        .eq('request_id', requestId)
        .order('occurred_at', ascending: true)
        .order('id', ascending: true)
        .timeout(const Duration(seconds: 20));
    if (db.auth.currentUser?.id != owner) {
      throw const AppFailure('Phiên đăng nhập đã thay đổi.',
          sessionExpired: true);
    }
    return RequestDetails(row, events);
  }
}
