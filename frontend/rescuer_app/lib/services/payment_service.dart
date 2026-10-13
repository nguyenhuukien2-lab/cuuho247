import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

enum PaymentSignalKind { changed, connected, disconnected }

class PaymentSignal {
  const PaymentSignal(this.requestId, this.kind);
  final String requestId;
  final PaymentSignalKind kind;
}

class PaymentAccessDenied implements Exception {
  const PaymentAccessDenied();
}

/// Testable transport boundary. Raw realtime rows never leave this service.
abstract class PaymentSource {
  String? get userId;
  Stream<String?> get authChanges;
  Future<Map<String, dynamic>?> load(String requestId);
  Stream<PaymentSignal> watch(String requestId);
}

abstract class CashPaymentCommands {
  Future<void> confirmCash(Map<String, dynamic> params);
}

class SupabasePaymentSource implements PaymentSource, CashPaymentCommands {
  SupabasePaymentSource(this.client);
  final SupabaseClient client;
  static int _channelSerial = 0;
  @override
  Future<void> confirmCash(Map<String, dynamic> params) async {
    final owner = userId;
    if (owner == null) throw const PaymentAccessDenied();
    await client
        .rpc('rescuer_confirm_cash_received', params: params)
        .timeout(const Duration(seconds: 20));
    if (owner != userId) throw const PaymentAccessDenied();
    // The UI refetches the authoritative DTO after every command.
  }

  @override
  String? get userId => client.auth.currentUser?.id;
  @override
  Stream<String?> get authChanges =>
      client.auth.onAuthStateChange.map((event) => event.session?.user.id);

  @override
  Future<Map<String, dynamic>?> load(String requestId) async {
    final owner = userId;
    if (owner == null) throw const PaymentAccessDenied();
    try {
      final result = await client
          .rpc('rescuer_get_job_payment', params: {'p_request_id': requestId})
          .timeout(const Duration(seconds: 20));
      if (owner != userId) throw const PaymentAccessDenied();
      if (result == null) return null;
      if (result is! Map) throw const FormatException('Invalid payment DTO');
      return Map<String, dynamic>.from(result);
    } on AuthException {
      throw const PaymentAccessDenied();
    } on PostgrestException catch (error) {
      if ([
            '42501',
            '28000',
            'PGRST301',
            'PGRST302',
            'PGRST303',
          ].contains(error.code) ||
          [
            'AUTHENTICATION_REQUIRED',
            'PAYMENT_NOT_ACCESSIBLE',
          ].contains(error.message)) {
        throw const PaymentAccessDenied();
      }
      rethrow;
    }
  }

  @override
  Stream<PaymentSignal> watch(String requestId) {
    final owner = userId;
    late final StreamController<PaymentSignal> events;
    RealtimeChannel? channel;
    var stopped = false;
    void emit(PaymentSignalKind kind) {
      if (!stopped && !events.isClosed && owner != null && userId == owner) {
        events.add(PaymentSignal(requestId, kind));
      }
    }

    void invalidate(PostgresChangePayload payload) {
      // Filter is only an optimization. PostgreSQL participant RLS authorizes
      // delivery; these checks also discard accidental unrelated invalidations.
      if (payload.newRecord['request_id'] == requestId &&
          payload.newRecord['rescuer_id'] == owner) {
        emit(PaymentSignalKind.changed);
      }
    }

    events = StreamController<PaymentSignal>(
      onListen: () {
        if (owner == null) {
          events.addError(const PaymentAccessDenied());
          return;
        }
        final filter = PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'request_id',
          value: requestId,
        );
        channel = client
            .channel(
              'rescuer_app-payment:$owner:$requestId:${++_channelSerial}',
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.insert,
              schema: 'public',
              table: 'payments',
              filter: filter,
              callback: invalidate,
            )
            .onPostgresChanges(
              event: PostgresChangeEvent.update,
              schema: 'public',
              table: 'payments',
              filter: filter,
              callback: invalidate,
            )
            .subscribe((status, error) {
              emit(
                status == RealtimeSubscribeStatus.subscribed
                    ? PaymentSignalKind.connected
                    : PaymentSignalKind.disconnected,
              );
            });
      },
      onCancel: () async {
        stopped = true;
        final old = channel;
        channel = null;
        if (old != null) await client.removeChannel(old);
      },
    );
    return events.stream;
  }
}
