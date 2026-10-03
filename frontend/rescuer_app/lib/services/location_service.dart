import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../models/backend_models.dart';

abstract class LocationService {
  Future<LocationSample> current();
  Future<bool> openSettings({bool gps = false}) async => false;
}

class DeviceLocationService implements LocationService {
  @override
  Future<LocationSample> current() async {
    try {
      return await _current();
    } on TimeoutException {
      throw const LocationFailure(
        'Chưa lấy được GPS sau 20 giây. Ra khu vực thoáng và thử lại.',
        LocationHelp.precision,
      );
    } on PermissionDeniedException {
      throw const LocationFailure(
        'Quyền vị trí bị từ chối. Cho phép vị trí chính xác trong Cài đặt.',
        LocationHelp.permission,
      );
    } on LocationServiceDisabledException {
      throw const LocationFailure(
        'GPS đang tắt. Bật GPS rồi thử lại.',
        LocationHelp.disabled,
      );
    }
  }

  Future<LocationSample> _current() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw const LocationFailure(
        'GPS đang tắt. Bật dịch vụ vị trí rồi thử lại.',
        LocationHelp.disabled,
      );
    }
    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw const LocationFailure(
        'Chưa có quyền vị trí. Cho phép vị trí trong cài đặt ứng dụng hoặc trình duyệt.',
        LocationHelp.permission,
      );
    }
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        timeLimit: Duration(seconds: 20),
      ),
    );
    final age = DateTime.now().toUtc().difference(position.timestamp.toUtc());
    if (!position.accuracy.isFinite ||
        position.accuracy > 100 ||
        age > const Duration(seconds: 120) ||
        age < const Duration(seconds: -30)) {
      throw const LocationFailure(
        'GPS chưa đủ chính xác (cần ≤100 m) hoặc vị trí đã cũ. Vui lòng thử lại.',
        LocationHelp.precision,
      );
    }
    return LocationSample(
      position.latitude,
      position.longitude,
      position.accuracy,
      position.timestamp.toUtc(),
    );
  }

  @override
  Future<bool> openSettings({bool gps = false}) =>
      gps ? Geolocator.openLocationSettings() : Geolocator.openAppSettings();
}
