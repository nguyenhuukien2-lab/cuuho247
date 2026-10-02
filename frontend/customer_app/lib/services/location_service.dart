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

class LocationResult {
  const LocationResult(this.status, this.message, {this.coordinates});

  final LocationStatus status;
  final String message;
  final RescueCoordinates? coordinates;
}

abstract interface class CustomerLocationService {
  Future<LocationResult> getCurrentLocation();
}

class GeolocatorLocationService implements CustomerLocationService {
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
              'Dịch vụ vị trí đang tắt. Hãy bật vị trí trên thiết bị rồi thử lại.');
        }
        var permission = await geolocator.checkPermission().timeout(timeout);
        if (permission == LocationPermission.denied) {
          permission = await geolocator.requestPermission().timeout(timeout);
        }
        if (permission == LocationPermission.deniedForever) {
          return const LocationResult(LocationStatus.denied,
              'Quyền vị trí đã bị chặn. Hãy cấp quyền trong Cài đặt ứng dụng rồi thử lại.');
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
      final coordinates =
          RescueCoordinates(position.latitude, position.longitude);
      if (!coordinates.isValid) {
        return const LocationResult(
            LocationStatus.unavailable, 'Thiết bị trả về tọa độ không hợp lệ.');
      }
      return LocationResult(
          LocationStatus.acquired, 'Tọa độ sẽ được gửi kèm địa chỉ bạn nhập.',
          coordinates: coordinates);
    } on PermissionDeniedException {
      return _denied;
    } on LocationServiceDisabledException {
      return const LocationResult(LocationStatus.unavailable,
          'Dịch vụ vị trí đang tắt. Hãy bật vị trí rồi thử lại.');
    } on TimeoutException {
      return const LocationResult(LocationStatus.unavailable,
          'Lấy vị trí quá thời gian chờ. Bạn có thể thử lại.');
    } on UnsupportedError {
      return _unsupported;
    } on MissingPluginException {
      return _unsupported;
    } catch (_) {
      return const LocationResult(LocationStatus.unavailable,
          'Không lấy được vị trí. Hãy kiểm tra cài đặt vị trí và thử lại. Trên web, cần HTTPS hoặc localhost.');
    }
  }

  static const _denied = LocationResult(LocationStatus.denied,
      'Bạn đã từ chối quyền vị trí. Có thể cấp lại quyền trong cài đặt trình duyệt/ứng dụng rồi thử lại.');
  static const _unsupported = LocationResult(LocationStatus.unavailable,
      'Thiết bị hoặc trình duyệt không hỗ trợ vị trí. Trên web, cần HTTPS hoặc localhost.');
}
