import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/backend_models.dart';
import '../models/payment_dto.dart';
import '../services/payment_service.dart';

class HistoryPaymentState {
  const HistoryPaymentState({this.payment, this.loading = false, this.error});
  final PaymentDto? payment;
  final bool loading;
  final String? error;
}

/// Read-only, user-scoped summaries. History pagination owns the job list;
/// these bounded getter reads never select a job or open realtime channels.
class HistoryPaymentController extends ChangeNotifier {
  HistoryPaymentController(this.source) : _owner = source?.userId {
    _auth = source?.authChanges.listen((owner) {
      if (owner != _owner) {
        _owner = owner;
        clear();
      }
    }, onError: (Object _) => clear());
  }

  final PaymentSource? source;
  final Map<String, HistoryPaymentState> _states = {};
  final Map<String, int> _revisions = {};
  StreamSubscription<String?>? _auth;
  String? _owner;
  int _generation = 0;
  bool _disposed = false;

  HistoryPaymentState stateFor(String requestId) =>
      _states[requestId] ?? const HistoryPaymentState();

  Future<void> refresh(
    Iterable<JobAssignment> jobs, {
    bool reset = false,
  }) async {
    if (_disposed) return;
    if (reset) clear();
    final owner = source?.userId;
    if (source == null || owner == null) return;
    if (owner != _owner) {
      clear();
      _owner = owner;
    }
    final generation = _generation;
    final queue = jobs.toList();
    var index = 0;
    bool current() =>
        !_disposed && generation == _generation && owner == source?.userId;
    Future<void> worker() async {
      while (current() && index < queue.length) {
        final job = queue[index++];
        final id = job.requestId;
        final revision = (_revisions[id] ?? 0) + 1;
        _revisions[id] = revision;
        final previous = _states[id]?.payment;
        _states[id] = HistoryPaymentState(payment: previous, loading: true);
        notifyListeners();
        bool accept() => current() && _revisions[id] == revision;
        try {
          final row = await source!.load(id);
          if (!accept()) continue;
          final next = row == null ? null : PaymentDto.fromJson(row);
          if (next != null &&
              (next.requestId != id ||
                  next.assignmentId != job.id ||
                  (previous != null && next.paymentId != previous.paymentId))) {
            throw const PaymentAccessDenied();
          }
          if (next != null &&
              previous != null &&
              next.version < previous.version) {
            throw const FormatException('Stale payment response');
          }
          _states[id] = HistoryPaymentState(
            payment:
                next != null &&
                    previous != null &&
                    next.version <= previous.version
                ? previous
                : next,
          );
        } on PaymentAccessDenied {
          if (accept()) {
            _states[id] = const HistoryPaymentState(error: 'unavailable');
          }
        } catch (_) {
          if (accept()) {
            _states[id] = HistoryPaymentState(
              payment: previous,
              error: 'network',
            );
          }
        }
        if (accept()) notifyListeners();
      }
    }

    await Future.wait(List.generate(queue.length.clamp(0, 4), (_) => worker()));
  }

  void clear() {
    _generation++;
    _states.clear();
    _revisions.clear();
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    clear();
    unawaited(_auth?.cancel());
    super.dispose();
  }
}
