import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/location_service.dart';

/// Device GPS state is separate from a request's selected rescue location.
class CustomerGpsController extends ChangeNotifier {
  CustomerGpsController(this.service);
  final CustomerLocationService service;
  LocationResult result =
      const LocationResult(LocationStatus.idle, 'Chưa cập nhật GPS.');
  LocationResult? lastFix;
  StreamSubscription<LocationResult>? _subscription;
  Future<void> _cancelling = Future.value();
  Future<LocationResult>? _refresh;
  Timer? _freshnessTimer;
  String? _userId;
  bool _foreground = true, _disposed = false;
  int _generation = 0;

  bool get tracking => _subscription != null;
  bool get loading => result.status == LocationStatus.loading;

  void setUser(String? userId) {
    if (_disposed || _userId == userId) return;
    _stop();
    _userId = userId;
    lastFix = null;
    result = const LocationResult(LocationStatus.idle, 'Chưa cập nhật GPS.');
    notifyListeners();
    if (_userId != null && _foreground) unawaited(refresh());
  }

  void setForeground(bool value) {
    if (_disposed || _foreground == value) return;
    _foreground = value;
    if (!value) {
      _stop();
      result = const LocationResult(
          LocationStatus.idle, 'GPS tạm dừng khi ứng dụng ở nền.');
      notifyListeners();
    } else if (_userId != null) {
      unawaited(refresh());
    }
  }

  Future<LocationResult> refresh() {
    if (_disposed || !_foreground) return Future.value(result);
    if (_refresh != null) return _refresh!;
    final generation = _generation;
    final request = _read(generation);
    _refresh = request;
    request.whenComplete(() {
      if (identical(_refresh, request)) _refresh = null;
    });
    return request;
  }

  Future<LocationResult> _read(int generation) async {
    result =
        const LocationResult(LocationStatus.loading, 'Đang cập nhật vị trí.');
    notifyListeners();
    LocationResult next;
    try {
      next = await service.getCurrentLocation();
    } catch (error) {
      next = GeolocatorLocationService.fromError(error);
    }
    if (!_current(generation)) return next;
    _apply(next);
    if (result.status == LocationStatus.acquired && _userId != null) {
      await _startStream(generation);
    } else if (result.status != LocationStatus.acquired) {
      await _cancelStream();
    }
    return result;
  }

  Future<void> _startStream(int generation) async {
    await _cancelling;
    if (!_current(generation) ||
        _subscription != null ||
        service is! CustomerLocationStreamService) {
      return;
    }
    try {
      _subscription =
          (service as CustomerLocationStreamService).watchLocation().listen(
        (next) {
          if (!_current(generation)) return;
          _apply(next);
          if (result.status != LocationStatus.acquired) {
            unawaited(_cancelStream());
          }
        },
        onError: (Object error) {
          if (!_current(generation)) return;
          _apply(GeolocatorLocationService.fromError(error));
          unawaited(_cancelStream());
        },
        onDone: () {
          if (_current(generation)) _subscription = null;
        },
      );
    } catch (error) {
      if (_current(generation)) {
        _apply(GeolocatorLocationService.fromError(error));
      }
    }
  }

  void _apply(LocationResult next) {
    _freshnessTimer?.cancel();
    if (next.status == LocationStatus.acquired &&
        (next.coordinates?.isValid != true ||
            (next.capturedAt != null && !next.isFresh(DateTime.now())))) {
      next = const LocationResult(LocationStatus.unavailable,
          'Vị trí GPS đã cũ hoặc không hợp lệ. Hãy cập nhật lại.',
          issue: LocationIssue.stale);
    }
    result = next;
    if (next.status == LocationStatus.acquired) {
      lastFix = next;
      if (_userId != null && next.capturedAt != null) {
        _freshnessTimer =
            Timer(const Duration(seconds: 60), () => unawaited(refresh()));
      }
    }
    notifyListeners();
  }

  bool _current(int generation) =>
      !_disposed && _foreground && generation == _generation;

  Future<void> _cancelStream() {
    final subscription = _subscription;
    _subscription = null;
    if (subscription != null) {
      _cancelling = _cancelling.then((_) => subscription.cancel());
    }
    return _cancelling;
  }

  void _stop() {
    _generation++;
    _refresh = null;
    _freshnessTimer?.cancel();
    unawaited(_cancelStream());
  }

  @override
  void dispose() {
    _disposed = true;
    _stop();
    super.dispose();
  }
}
