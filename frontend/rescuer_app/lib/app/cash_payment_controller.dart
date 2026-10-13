import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/payment_dto.dart';
import '../services/payment_service.dart';
import 'payment_watcher.dart';

enum CashIssue { offline, timeout, conflict, settled, unavailable, failed }

/// A route owns its subscription; history selection cannot change its payment.
class CashPaymentController extends ChangeNotifier {
  CashPaymentController({
    required PaymentSource? source,
    required this.requestId,
    required this.assignmentId,
    required this.completed,
    required this.canCollect,
  }) : watcher = PaymentWatcher(source) {
    watcher.addListener(_changed);
  }

  final PaymentWatcher watcher;
  final String requestId, assignmentId;
  final bool completed;
  final bool Function() canCollect;
  bool submitting = false, _disposed = false;
  CashIssue? issue;
  Map<String, dynamic>? _pending;
  String? _pendingOwner;
  PaymentDto? get payment => watcher.payment;
  bool get loadingPayment => watcher.loading;
  bool get confirmingCash => submitting;
  String? get paymentError => watcher.error ?? issue?.name;
  Future<void> loadJobPayment() => start();
  Future<void> refreshJobPayment() => retry();
  Future<void> confirmCashReceived(PaymentDto reviewed) => confirm(reviewed);
  bool get eligible =>
      canCollect() &&
      watcher.source is CashPaymentCommands &&
      watcher.requestId == requestId &&
      payment?.assignmentId == assignmentId &&
      payment?.method == 'cash' &&
      payment?.status == 'awaiting_payment' &&
      payment?.currency == 'VND' &&
      payment!.amountExpected > BigInt.zero &&
      !watcher.stale &&
      !watcher.loading &&
      watcher.error == null &&
      watcher.source?.userId != null;
  bool get canConfirm => eligible && !submitting && issue == null;

  void _changed() {
    if (_pendingOwner != watcher.source?.userId || watcher.requestId == null) {
      _pending = null;
      _pendingOwner = null;
    }
    if (!_disposed) notifyListeners();
  }

  Future<void> start() => watcher.watch(requestId);

  Future<void> retry() async {
    if (submitting) return;
    issue = null;
    await start(); // Read only: a failed response may have followed a commit.
    _changed();
  }

  Future<void> confirm(PaymentDto reviewed) async {
    if (!canConfirm) return;
    final current = payment!;
    if (reviewed.paymentId != current.paymentId ||
        reviewed.version != current.version ||
        reviewed.amountExpected != current.amountExpected) {
      issue = CashIssue.conflict;
      _changed();
      await watcher.refresh();
      return;
    }
    final owner = watcher.source!.userId;
    if (_pendingOwner != owner ||
        _pending?['p_payment_id'] != current.paymentId ||
        _pending?['p_expected_version'] != current.version.toString()) {
      _pendingOwner = owner;
      _pending = {
        'p_request_id': requestId,
        'p_payment_id': current.paymentId,
        'p_amount_received': current.amountExpected.toString(),
        'p_expected_version': current.version.toString(),
        'p_operation_id': const Uuid().v4(),
      };
    }
    submitting = true;
    _changed();
    try {
      await (watcher.source! as CashPaymentCommands)
          .confirmCash(Map<String, dynamic>.from(_pending!))
          .timeout(const Duration(seconds: 20));
      if (_disposed || watcher.source?.userId != owner) return;
      await watcher.refresh();
      if (_disposed || watcher.source?.userId != owner) return;
      if (watcher.error != null || payment?.status != 'paid') {
        issue = CashIssue.failed;
      } else {
        _pending = null;
      }
    } catch (error) {
      if (_disposed || watcher.source?.userId != owner) return;
      issue = switch (error) {
        PaymentAccessDenied() || AuthException() => CashIssue.unavailable,
        TimeoutException() => CashIssue.timeout,
        PostgrestException(message: 'VERSION_CONFLICT') => CashIssue.conflict,
        PostgrestException(message: 'PAYMENT_ALREADY_SETTLED') =>
          CashIssue.settled,
        PostgrestException(message: 'PAYMENT_STATE_CONFLICT') =>
          CashIssue.conflict,
        PostgrestException(message: 'PAYMENT_NOT_ELIGIBLE') =>
          CashIssue.unavailable,
        PostgrestException(message: 'PAYMENT_NOT_ACCESSIBLE') =>
          CashIssue.unavailable,
        PostgrestException(message: 'PROFILE_SUSPENDED') =>
          CashIssue.unavailable,
        PostgrestException(message: 'PROFILE_NOT_READY') =>
          CashIssue.unavailable,
        PostgrestException() || FormatException() => CashIssue.failed,
        _ => CashIssue.offline,
      };
      // Keep the same operation/payload on uncertain outcomes. Retry only reads.
      await watcher.refresh();
      if (_disposed || watcher.source?.userId != owner) return;
      if (watcher.error == null && payment?.status == 'paid') {
        issue = null;
        _pending = null;
      }
    } finally {
      submitting = false;
      _changed();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    watcher.removeListener(_changed);
    watcher.dispose();
    super.dispose();
  }
}
