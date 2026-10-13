import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/payment_dto.dart';
import '../services/payment_service.dart';

/// One user/request scope. Only getter responses can change the payment.
class PaymentWatcher extends ChangeNotifier {
  PaymentWatcher(this.source) : _owner = source?.userId {
    _auth = source?.authChanges.listen((user) {
      if (user != _owner) {
        clear(); // Never transfer the selected request or cached DTO to a new user.
        _owner = user;
      } else if (user != null) {
        unawaited(refresh()); // Auth restoration/token renewal, even same user.
      }
    }, onError: (Object _) => clear());
  }

  final PaymentSource? source;
  PaymentDto? payment;
  String? requestId, error;
  bool loading = false, stale = false;
  String? _owner;
  StreamSubscription<String?>? _auth;
  StreamSubscription<PaymentSignal>? _channel;
  Future<void> _cancellation = Future<void>.value();
  Future<void>? _refreshTask;
  Timer? _retry, _refreshRetry;
  int _generation = 0;
  bool _disposed = false,
      _foreground = true,
      _connected = false,
      _reload = false;

  bool _current(int generation) =>
      !_disposed &&
      generation == _generation &&
      _owner != null &&
      _owner == source?.userId &&
      requestId != null;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  Future<void> watch(String id) async {
    if (_disposed) return;
    final user = source?.userId;
    if (user == null) {
      clear();
      return;
    }
    if (_owner == user && requestId == id) {
      await refresh();
      return;
    }
    clear();
    _owner = user;
    requestId = id;
    final generation = _generation;
    await _connect(generation);
    if (_current(generation)) await refresh();
  }

  Future<void> _connect(int generation) async {
    await _cancellation;
    if (!_current(generation) || _channel != null) return;
    try {
      _channel = source!
          .watch(requestId!)
          .listen(
            (signal) {
              if (!_current(generation) || signal.requestId != requestId) {
                return;
              }
              if (signal.kind == PaymentSignalKind.disconnected) {
                _disconnected(generation);
              } else {
                if (signal.kind == PaymentSignalKind.connected) {
                  _connected = true;
                  _retry?.cancel();
                  _retry = null;
                }
                if (_foreground) unawaited(refresh());
              }
            },
            onError: (Object failure) {
              if (!_current(generation)) return;
              if (failure is PaymentAccessDenied) {
                payment = null;
                error = 'PAYMENT_NOT_ACCESSIBLE';
              }
              _disconnected(generation);
            },
            onDone: () {
              if (_current(generation)) _disconnected(generation);
            },
          );
    } catch (_) {
      if (_current(generation)) _disconnected(generation);
    }
  }

  void _detach() {
    final old = _channel;
    _channel = null;
    // Await removal before starting the next channel, including rapid switches.
    _cancellation = _cancellation
        .then((_) async {
          if (old != null) await old.cancel();
        })
        .catchError((Object _) {
          /* Identity/generation already invalidated. */
        });
  }

  void _disconnected(int generation) {
    _connected = false;
    stale = true;
    _notify();
    if (!_foreground || _retry != null) return;
    _retry = Timer(const Duration(seconds: 3), () async {
      _retry = null;
      if (!_current(generation)) return;
      _detach();
      await _connect(generation);
      if (_current(generation)) await refresh();
    });
  }

  Future<void> refresh() {
    if (_disposed || requestId == null) return Future<void>.value();
    if (_owner == null || _owner != source?.userId) {
      clear();
      return Future<void>.value();
    }
    _refreshRetry?.cancel();
    _refreshRetry = null;
    _reload = true;
    if (_refreshTask != null) return _refreshTask!;
    // Reserve the task before notifying listeners inside _drain.
    final completion = Completer<void>();
    _refreshTask = completion.future;
    unawaited(
      _drain(_generation)
          .then(completion.complete, onError: completion.completeError),
    );
    return completion.future;
  }

  Future<void> _drain(int generation) async {
    var formatRetried = false;
    loading = true;
    _notify();
    try {
      while (_reload && _current(generation)) {
        _reload = false;
        try {
          final row = await source!.load(requestId!);
          if (!_current(generation)) return;
          final next = row == null ? null : PaymentDto.fromJson(row);
          if (next != null &&
              (next.requestId != requestId ||
                  (payment != null && next.paymentId != payment!.paymentId))) {
            throw const PaymentAccessDenied();
          }
          if (next == null) {
            payment = null;
          } else if (payment != null && next.version < payment!.version) {
            // Keep the newer snapshot, but do not present cached paid as a
            // successful fresh read when the getter returned an older version.
            throw const FormatException('Stale payment response');
          } else if (payment == null || next.version > payment!.version) {
            payment = next;
          }
          // Equal/older versions never overwrite an accepted snapshot.
          error = null;
          _refreshRetry?.cancel();
          _refreshRetry = null;
          stale = !_connected;
        } on PaymentAccessDenied {
          if (!_current(generation)) return;
          _refreshRetry?.cancel();
          _refreshRetry = null;
          payment = null;
          stale = true;
          error = 'PAYMENT_NOT_ACCESSIBLE';
        } on FormatException {
          if (!_current(generation)) return;
          stale = true;
          error = 'PAYMENT_INVALID_RESPONSE';
          // One immediate authoritative refetch; no infinite loop on bad data.
          if (!formatRetried) {
            formatRetried = true;
            _reload = true;
          }
        } catch (_) {
          if (!_current(generation)) return;
          stale = true;
          error = 'PAYMENT_REFRESH_FAILED';
          // A network error preserves only the current user's/request's DTO.
          _scheduleRefreshRetry(generation);
        }
      }
    } finally {
      if (_current(generation)) {
        _refreshTask = null;
        loading = false;
        _notify();
      }
    }
  }

  void _scheduleRefreshRetry(int generation) {
    if (!_foreground || _refreshRetry != null) return;
    _refreshRetry = Timer(const Duration(seconds: 3), () {
      _refreshRetry = null;
      if (_foreground && _current(generation)) unawaited(refresh());
    });
  }

  void setForeground(bool value) {
    if (_disposed || _foreground == value) return;
    _foreground = value;
    if (!value) {
      _refreshRetry?.cancel();
      _refreshRetry = null;
      _retry?.cancel();
      _retry = null;
    } else {
      if (!_connected && requestId != null) _disconnected(_generation);
      unawaited(refresh());
    }
  }

  void clear() {
    _generation++;
    _reload = false;
    _refreshTask = null;
    _refreshRetry?.cancel();
    _refreshRetry = null;
    _retry?.cancel();
    _retry = null;
    _detach();
    requestId = null;
    payment = null;
    error = null;
    loading = false;
    stale = false;
    _connected = false;
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    clear();
    unawaited(_auth?.cancel());
    super.dispose();
  }
}
