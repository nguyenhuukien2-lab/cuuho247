import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';

/// A map-independent coordinate pair, reusable by a future map adapter.
class RescueCoordinates {
  const RescueCoordinates(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  bool get isValid =>
      latitude.isFinite &&
      longitude.isFinite &&
      latitude >= -90 &&
      latitude <= 90 &&
      longitude >= -180 &&
      longitude <= 180;

  String get label =>
      '${latitude.toStringAsFixed(6)}, ${longitude.toStringAsFixed(6)}';
}

enum LocationStatus { idle, loading, acquired, denied, unavailable }

enum LocationIssue { deniedForever, disabled, timeout, stale, unsupported }

class LocationResult {
  const LocationResult(this.status, this.message,
      {this.coordinates, this.accuracy, this.capturedAt, this.issue});

  final LocationStatus status;
  final String message;
  final RescueCoordinates? coordinates;
  final double? accuracy;
  final DateTime? capturedAt;
  final LocationIssue? issue;

  bool isFresh(DateTime now) =>
      capturedAt != null &&
      now.toUtc().difference(capturedAt!.toUtc()) <=
          const Duration(minutes: 2) &&
      now.toUtc().difference(capturedAt!.toUtc()) >=
          const Duration(seconds: -30);

  String get statusLabel => switch (status) {
        LocationStatus.loading => 'Đang cập nhật vị trí',
        LocationStatus.acquired => 'GPS sẵn sàng',
        LocationStatus.denied => issue == LocationIssue.deniedForever
            ? 'Quyền vị trí đã bị chặn'
            : 'Chưa cấp quyền vị trí',
        LocationStatus.unavailable => issue == LocationIssue.disabled
            ? 'GPS đang tắt'
            : 'Không thể lấy vị trí',
        LocationStatus.idle => 'Chưa cập nhật GPS',
      };
}

abstract interface class CustomerLocationService {
  Future<LocationResult> getCurrentLocation();
}

abstract interface class CustomerLocationStreamService {
  Stream<LocationResult> watchLocation();
}

class GeolocatorLocationService
    implements CustomerLocationService, CustomerLocationStreamService {
  const GeolocatorLocationService({this.platform, this.isWeb = kIsWeb});

  final GeolocatorPlatform? platform;
  final bool isWeb;
  static const timeout = Duration(seconds: 20);

  @override
  Future<LocationResult> getCurrentLocation() async {
    final geolocator = platform ?? GeolocatorPlatform.instance;
    try {
      // On Web, getCurrentPosition prompts for permission itself. The plugin's
      // requestPermission maps all browser errors to deniedForever, so avoid
      // that call to distinguish denial from unavailable/timeout correctly.
      if (!isWeb) {
        if (!await geolocator.isLocationServiceEnabled().timeout(timeout)) {
          return const LocationResult(LocationStatus.unavailable,
              'Dịch vụ vị trí đang tắt. Hãy bật vị trí trên thiết bị rồi thử lại.',
              issue: LocationIssue.disabled);
        }
        var permission = await geolocator.checkPermission().timeout(timeout);
        if (permission == LocationPermission.denied) {
          permission = await geolocator.requestPermission().timeout(timeout);
        }
        if (permission == LocationPermission.deniedForever) {
          return const LocationResult(LocationStatus.denied,
              'Quyền vị trí đã bị chặn. Hãy cấp quyền trong Cài đặt ứng dụng rồi thử lại.',
              issue: LocationIssue.deniedForever);
        }
        if (permission == LocationPermission.denied) return _denied;
        if (permission == LocationPermission.unableToDetermine) {
          return const LocationResult(LocationStatus.unavailable,
              'Không xác định được quyền vị trí trên thiết bị này.');
        }
      }
      final position = await geolocator
          .getCurrentPosition(
              locationSettings: const LocationSettings(
                  accuracy: LocationAccuracy.high, timeLimit: timeout))
          .timeout(timeout);
      return _fromPosition(position);
    } catch (error) {
      return fromError(error);
    }
  }

  @override
  Stream<LocationResult> watchLocation() async* {
    try {
      final geolocator = platform ?? GeolocatorPlatform.instance;
      await for (final position in geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 20,
        ),
      )) {
        yield _fromPosition(position);
      }
    } catch (error) {
      yield fromError(error);
    }
  }

  static LocationResult _fromPosition(Position position) {
    final coordinates =
        RescueCoordinates(position.latitude, position.longitude);
    if (!coordinates.isValid ||
        !position.accuracy.isFinite ||
        position.accuracy < 0) {
      return const LocationResult(LocationStatus.unavailable,
          'Thiết bị trả về vị trí hoặc độ chính xác không hợp lệ.');
    }
    final result = LocationResult(
        LocationStatus.acquired, 'Tọa độ sẽ được gửi kèm địa chỉ bạn nhập.',
        coordinates: coordinates,
        accuracy: position.accuracy,
        capturedAt: position.timestamp.toUtc());
    if (!result.isFresh(DateTime.now())) {
      return const LocationResult(LocationStatus.unavailable,
          'Vị trí GPS đã cũ. Hãy cập nhật vị trí rồi thử lại.',
          issue: LocationIssue.stale);
    }
    return result;
  }

  static LocationResult fromError(Object error) {
    if (error is PermissionDeniedException) return _denied;
    if (error is LocationServiceDisabledException) {
      return const LocationResult(LocationStatus.unavailable,
          'Dịch vụ vị trí đang tắt. Hãy bật vị trí rồi thử lại.',
          issue: LocationIssue.disabled);
    }
    if (error is TimeoutException) {
      return const LocationResult(LocationStatus.unavailable,
          'Lấy vị trí quá thời gian chờ. Bạn có thể thử lại.',
          issue: LocationIssue.timeout);
    }
    if (error is UnsupportedError || error is MissingPluginException)
      return _unsupported;
    return const LocationResult(LocationStatus.unavailable,
        'Không lấy được vị trí. Hãy kiểm tra cài đặt vị trí và thử lại. Trên web, cần HTTPS hoặc localhost.');
  }

  static const _denied = LocationResult(LocationStatus.denied,
      'Bạn đã từ chối quyền vị trí. Có thể cấp lại quyền trong cài đặt trình duyệt/ứng dụng rồi thử lại.');
  static const _unsupported = LocationResult(LocationStatus.unavailable,
      'Thiết bị hoặc trình duyệt không hỗ trợ vị trí. Trên web, cần HTTPS hoặc localhost.',
      issue: LocationIssue.unsupported);
}
