import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import '../models/backend_models.dart';

abstract class LocationService {
  Future<LocationSample> current();
  Future<bool> openSettings({bool gps = false}) async => false;
}

abstract interface class LocationStreamService {
  Stream<LocationSample> watch();
}

class DeviceLocationService implements LocationService, LocationStreamService {
  DeviceLocationService({this.platform, this.isWeb = kIsWeb});
  final GeolocatorPlatform? platform;
  final bool isWeb;
  static const timeout = Duration(seconds: 20);
  GeolocatorPlatform get _platform => platform ?? GeolocatorPlatform.instance;
  @override
  Future<LocationSample> current() async {
    try {
      return await _current();
    } catch (error) {
      throw failure(error);
    }
  }

  Future<LocationSample> _current() async {
    if (!isWeb &&
        !await _platform.isLocationServiceEnabled().timeout(timeout)) {
      throw const LocationFailure(
        'GPS đang tắt. Bật dịch vụ vị trí rồi thử lại.',
        LocationHelp.disabled,
        status: GpsStatus.disabled,
      );
    }
    // getCurrentPosition owns the Web prompt; Web requestPermission can
    // incorrectly map timeout/unavailable to deniedForever.
    if (!isWeb) {
      var permission = await _platform.checkPermission().timeout(timeout);
      if (permission == LocationPermission.denied) {
        permission = await _platform.requestPermission().timeout(timeout);
      }
      if (permission == LocationPermission.deniedForever) {
        throw const LocationFailure(
          'Quyền vị trí đã bị chặn. Cấp quyền trong Cài đặt.',
          LocationHelp.permission,
          status: GpsStatus.deniedForever,
        );
      }
      if (permission == LocationPermission.denied) {
        throw const LocationFailure(
          'Chưa có quyền vị trí. Cho phép vị trí trong cài đặt ứng dụng hoặc trình duyệt.',
          LocationHelp.permission,
          status: GpsStatus.denied,
        );
      }
      if (permission == LocationPermission.unableToDetermine) {
        throw const LocationFailure(
          'Không xác định được quyền vị trí.',
          LocationHelp.permission,
        );
      }
    }
    final position = await _platform
        .getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 20),
          ),
        )
        .timeout(timeout);
    return fromPosition(position);
  }

  @override
  Stream<LocationSample> watch() async* {
    try {
      await for (final position in _platform.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 20,
        ),
      )) {
        yield fromPosition(position);
      }
    } catch (error) {
      throw failure(error);
    }
  }

  static void validate(LocationSample sample) {
    final age = DateTime.now().toUtc().difference(sample.capturedAt.toUtc());
    if (!sample.latitude.isFinite ||
        sample.latitude.abs() > 90 ||
        !sample.longitude.isFinite ||
        sample.longitude.abs() > 180 ||
        !sample.accuracy.isFinite ||
        sample.accuracy < 0 ||
        sample.accuracy > 100 ||
        age > const Duration(seconds: 120) ||
        age < const Duration(seconds: -30)) {
      throw const LocationFailure(
        'GPS chưa đủ chính xác (cần ≤100 m) hoặc vị trí đã cũ. Vui lòng thử lại.',
        LocationHelp.precision,
      );
    }
  }

  static LocationSample fromPosition(Position position) {
    final sample = LocationSample(
      position.latitude,
      position.longitude,
      position.accuracy,
      position.timestamp.toUtc(),
    );
    validate(sample);
    return sample;
  }

  static LocationFailure failure(Object error) {
    if (error is LocationFailure) return error;
    if (error is TimeoutException) {
      return const LocationFailure(
        'Chưa lấy được GPS sau 20 giây. Ra khu vực thoáng và thử lại.',
        LocationHelp.precision,
      );
    }
    if (error is PermissionDeniedException) {
      return const LocationFailure(
        'Quyền vị trí bị từ chối. Cho phép vị trí trong Cài đặt.',
        LocationHelp.permission,
        status: GpsStatus.denied,
      );
    }
    if (error is LocationServiceDisabledException) {
      return const LocationFailure(
        'GPS đang tắt. Bật GPS rồi thử lại.',
        LocationHelp.disabled,
        status: GpsStatus.disabled,
      );
    }
    return const LocationFailure(
      'Không thể lấy vị trí. Kiểm tra GPS và quyền vị trí. Trên web, cần HTTPS hoặc localhost.',
      LocationHelp.precision,
    );
  }

  @override
  Future<bool> openSettings({bool gps = false}) =>
      gps ? _platform.openLocationSettings() : _platform.openAppSettings();
}
