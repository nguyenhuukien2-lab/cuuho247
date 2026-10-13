import 'dart:async';
import 'dart:math';
import 'package:supabase_flutter/supabase_flutter.dart';

bool isPaymentRequestId(String value) => RegExp(
        r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$')
    .hasMatch(value);

String newPaymentOperationId() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
      '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// Immutable payload retained after an ambiguous network outcome.
class CashPaymentSelection {
  const CashPaymentSelection(
      {required this.requestId,
      required this.paymentId,
      required this.expectedVersion,
      required this.operationId});
  final String requestId, paymentId, operationId;
  final BigInt expectedVersion;
  Map<String, dynamic> get parameters => {
        'p_request_id': requestId,
        'p_payment_id': paymentId,
        'p_method': 'cash',
        'p_expected_version': expectedVersion.toString(),
        'p_operation_id': operationId,
      };
}

class BankPaymentSelection {
  const BankPaymentSelection(
      {required this.requestId,
      required this.paymentId,
      required this.expectedVersion,
      required this.operationId});
  final String requestId, paymentId, operationId;
  final BigInt expectedVersion;
  Map<String, dynamic> get parameters => {
        'p_request_id': requestId,
        'p_payment_id': paymentId,
        'p_expected_version': expectedVersion.toString(),
        'p_operation_id': operationId,
      };
}

/// Exact expired-intent replacement payload. Retain this object across an
/// ambiguous timeout so retries reuse the same operation id and version guards.
class BankPaymentRegeneration {
  const BankPaymentRegeneration(
      {required this.requestId,
      required this.paymentId,
      required this.expectedVersion,
      required this.expectedIntentId,
      required this.expectedIntentVersion,
      required this.operationId});
  final String requestId, paymentId, expectedIntentId, operationId;
  final BigInt expectedVersion, expectedIntentVersion;
  Map<String, dynamic> get parameters => {
        'p_request_id': requestId,
        'p_payment_id': paymentId,
        'p_expected_version': expectedVersion.toString(),
        'p_expected_intent_id': expectedIntentId,
        'p_expected_intent_version': expectedIntentVersion.toString(),
        'p_operation_id': operationId,
      };
}

abstract interface class BankPaymentSource {
  Future<bool> bankCapability(String requestId);
  Future<Map<String, dynamic>?> loadBank(String requestId);
  Future<void> selectBank(BankPaymentSelection selection);
  Future<void> regenerateBank(BankPaymentRegeneration regeneration);
}

class PaymentCommandFailure implements Exception {
  const PaymentCommandFailure(this.code, {this.outcomeUnknown = false});
  final String code;
  final bool outcomeUnknown;
}

/// Commands acknowledge completion only. Their DTOs never become UI state.
abstract interface class PaymentCommands {
  Future<void> prepare(String requestId);
  Future<void> selectCash(CashPaymentSelection selection);
}

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

class SupabasePaymentSource
    implements PaymentSource, PaymentCommands, BankPaymentSource {
  SupabasePaymentSource(this.client,
      {this.commandTimeout = const Duration(seconds: 20)});
  final SupabaseClient client;
  final Duration commandTimeout;
  static int _channelSerial = 0;
  @override
  String? get userId => client.auth.currentUser?.id;
  @override
  Stream<String?> get authChanges =>
      client.auth.onAuthStateChange.map((event) => event.session?.user.id);

  @override
  Future<void> prepare(String requestId) =>
      _command('customer_prepare_payment', {'p_request_id': requestId});

  @override
  Future<void> selectCash(CashPaymentSelection selection) =>
      _command('customer_select_payment_method', selection.parameters);

  @override
  Future<void> selectBank(BankPaymentSelection selection) =>
      _command('customer_select_bank_transfer', selection.parameters);

  @override
  Future<void> regenerateBank(BankPaymentRegeneration regeneration) =>
      _command('customer_regenerate_bank_transfer', regeneration.parameters);

  @override
  Future<bool> bankCapability(String requestId) async {
    final row = await _read('customer_get_bank_capability', requestId);
    return row?['available'] == true;
  }

  @override
  Future<Map<String, dynamic>?> loadBank(String requestId) =>
      _read('customer_get_bank_payment', requestId);

  Future<void> _command(String rpc, Map<String, dynamic> parameters) async {
    final owner = userId;
    if (owner == null) throw const PaymentAccessDenied();
    try {
      final result =
          await client.rpc(rpc, params: parameters).timeout(commandTimeout);
      if (userId != owner) throw const PaymentAccessDenied();
      // Even a valid replay may contain an older payment version. Discard it.
      if (result is! Map ||
          (rpc != 'customer_prepare_payment' &&
              (result['payment'] is! Map || result['changed'] is! bool))) {
        throw const PaymentCommandFailure('PAYMENT_COMMAND_UNCERTAIN',
            outcomeUnknown: true);
      }
    } on AuthException {
      throw const PaymentAccessDenied();
    } on PostgrestException catch (error) {
      if (userId != owner ||
          ['42501', '28000', 'PGRST301', 'PGRST302', 'PGRST303']
              .contains(error.code)) {
        throw const PaymentAccessDenied();
      }
      const safeCodes = {
        'PAYMENT_NOT_ELIGIBLE',
        'QUOTE_SNAPSHOT_INCONSISTENT',
        'ZERO_AMOUNT_REQUIRES_POLICY',
        'VERSION_CONFLICT',
        'IDEMPOTENCY_CONFLICT',
        'PAYMENT_ALREADY_SETTLED',
        'PAYMENT_STATE_CONFLICT',
        'METHOD_NOT_IMPLEMENTED',
        'INVALID_EXPECTED_VERSION',
        'IDEMPOTENCY_KEY_REQUIRED',
        'BANK_UNAVAILABLE',
        'BANK_INTENT_UNAVAILABLE',
        'INVALID_EXPECTED_INTENT_VERSION',
        'BANK_INTENT_VERSION_CONFLICT',
        'BANK_INTENT_NOT_EXPIRED',
        'BANK_TRANSFER_RECONCILIATION_REQUIRED'
      };
      if (error.message == 'PAYMENT_NOT_ACCESSIBLE' ||
          error.message == 'AUTHENTICATION_REQUIRED') {
        throw const PaymentAccessDenied();
      }
      throw PaymentCommandFailure(
          safeCodes.contains(error.message)
              ? error.message
              : 'PAYMENT_COMMAND_UNCERTAIN',
          outcomeUnknown: !safeCodes.contains(error.message));
    } on PaymentAccessDenied {
      rethrow;
    } on PaymentCommandFailure {
      rethrow;
    } catch (_) {
      if (userId != owner) throw const PaymentAccessDenied();
      throw const PaymentCommandFailure('PAYMENT_COMMAND_UNCERTAIN',
          outcomeUnknown: true);
    }
  }

  @override
  Future<Map<String, dynamic>?> load(String requestId) =>
      _read('customer_get_payment', requestId);

  Future<Map<String, dynamic>?> _read(String rpc, String requestId) async {
    final owner = userId;
    if (owner == null) throw const PaymentAccessDenied();
    try {
      final result = await client.rpc(rpc, params: {
        'p_request_id': requestId
      }).timeout(const Duration(seconds: 20));
      if (owner != userId) throw const PaymentAccessDenied();
      if (result == null) return null;
      if (result is! Map) throw const FormatException('Invalid payment DTO');
      return Map<String, dynamic>.from(result);
    } on AuthException {
      throw const PaymentAccessDenied();
    } on PostgrestException catch (error) {
      if (['42501', '28000', 'PGRST301', 'PGRST302', 'PGRST303']
              .contains(error.code) ||
          ['AUTHENTICATION_REQUIRED', 'PAYMENT_NOT_ACCESSIBLE']
              .contains(error.message)) {
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
          payload.newRecord['customer_id'] == owner) {
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
            value: requestId);
        channel = client
            .channel(
                'customer_app-payment:$owner:$requestId:${++_channelSerial}')
            .onPostgresChanges(
                event: PostgresChangeEvent.insert,
                schema: 'public',
                table: 'payments',
                filter: filter,
                callback: invalidate)
            .onPostgresChanges(
                event: PostgresChangeEvent.update,
                schema: 'public',
                table: 'payments',
                filter: filter,
                callback: invalidate)
            .subscribe((status, error) {
          emit(status == RealtimeSubscribeStatus.subscribed
              ? PaymentSignalKind.connected
              : PaymentSignalKind.disconnected);
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
