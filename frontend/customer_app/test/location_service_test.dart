import 'dart:async';

import 'package:cuu_ho_247/services/location_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

class FakeGeolocator extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.denied;
  LocationPermission requestedPermission = LocationPermission.whileInUse;
  int permissionRequests = 0;
  int positionRequests = 0;
  Object? error;
  Completer<Position>? pending;
  double latitude = 10.7769;

  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return requestedPermission;
  }

  @override
  Future<Position> getCurrentPosition(
      {LocationSettings? locationSettings}) async {
    positionRequests++;
    expect(locationSettings?.timeLimit, const Duration(seconds: 20));
    if (error != null) throw error!;
    if (pending != null) return pending!.future;
    return Position(
      latitude: latitude,
      longitude: 106.7009,
      timestamp: DateTime.utc(2026),
      accuracy: 10,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}

void main() {
  test('Android requests permission once and returns real coordinates',
      () async {
    final platform = FakeGeolocator();
    final result =
        await GeolocatorLocationService(platform: platform, isWeb: false)
            .getCurrentLocation();
    expect(result.status, LocationStatus.acquired);
    expect(result.coordinates?.latitude, 10.7769);
    expect(result.coordinates?.longitude, 106.7009);
    expect(platform.permissionRequests, 1);
  });

  test('already granted permission does not prompt again', () async {
    final platform = FakeGeolocator()
      ..permission = LocationPermission.whileInUse;
    final result =
        await GeolocatorLocationService(platform: platform, isWeb: false)
            .getCurrentLocation();
    expect(result.status, LocationStatus.acquired);
    expect(platform.permissionRequests, 0);
  });

  test('denied and permanently denied never read a position', () async {
    for (final permission in [
      LocationPermission.denied,
      LocationPermission.deniedForever
    ]) {
      final platform = FakeGeolocator()
        ..permission = permission
        ..requestedPermission = permission;
      final result =
          await GeolocatorLocationService(platform: platform, isWeb: false)
              .getCurrentLocation();
      expect(result.status, LocationStatus.denied);
      expect(result.coordinates, isNull);
      expect(platform.positionRequests, 0);
      expect(platform.permissionRequests,
          permission == LocationPermission.denied ? 1 : 0);
    }
  });

  test('disabled service returns unavailable without requesting permission',
      () async {
    final platform = FakeGeolocator()..enabled = false;
    final result =
        await GeolocatorLocationService(platform: platform, isWeb: false)
            .getCurrentLocation();
    expect(result.status, LocationStatus.unavailable);
    expect(platform.permissionRequests, 0);
    expect(platform.positionRequests, 0);
  });

  test('Web obtains permission through a single getCurrentPosition call',
      () async {
    final platform = FakeGeolocator();
    final result =
        await GeolocatorLocationService(platform: platform, isWeb: true)
            .getCurrentLocation();
    expect(result.status, LocationStatus.acquired);
    expect(platform.permissionRequests, 0);
    expect(platform.positionRequests, 1);
  });

  test('browser denial is distinct from timeout, unsupported and other errors',
      () async {
    final errors = <Object, LocationStatus>{
      const PermissionDeniedException('blocked'): LocationStatus.denied,
      TimeoutException('timeout'): LocationStatus.unavailable,
      UnsupportedError('geolocation'): LocationStatus.unavailable,
      const LocationServiceDisabledException(): LocationStatus.unavailable,
      const PositionUpdateException('unavailable'): LocationStatus.unavailable,
    };
    for (final entry in errors.entries) {
      final result = await GeolocatorLocationService(
              platform: FakeGeolocator()..error = entry.key, isWeb: true)
          .getCurrentLocation();
      expect(result.status, entry.value);
      expect(result.coordinates, isNull);
    }
  });

  testWidgets('a hanging position is bounded by the application timeout',
      (tester) async {
    final platform = FakeGeolocator()..pending = Completer<Position>();
    final result = GeolocatorLocationService(platform: platform, isWeb: true)
        .getCurrentLocation();
    await tester.pump(const Duration(seconds: 21));
    expect((await result).status, LocationStatus.unavailable);
  });

  test('invalid coordinates are rejected; zero is a valid coordinate',
      () async {
    for (final latitude in [double.nan, double.infinity, 91.0]) {
      final result = await GeolocatorLocationService(
              platform: FakeGeolocator()..latitude = latitude, isWeb: true)
          .getCurrentLocation();
      expect(result.status, LocationStatus.unavailable);
    }
    expect(const RescueCoordinates(0, 0).isValid, isTrue);
    expect(const RescueCoordinates(10, 181).isValid, isFalse);
  });
}
