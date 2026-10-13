import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:rescuer/app/rescuer_controller.dart';
import 'package:rescuer/models/backend_models.dart';
import 'package:rescuer/services/location_service.dart';

import 'active_job_ui_test.dart' show ActiveUiFake;
import 'connected_app_test.dart' show FakeLocation;

class LiveGps extends FakeLocation implements LocationStreamService {
  int starts = 0, stops = 0, reads = 0;
  LocationSample? sample;
  late final positions = StreamController<LocationSample>.broadcast(
    sync: true,
    onListen: () => starts++,
    onCancel: () => stops++,
  );
  @override
  Future<LocationSample> current() async {
    reads++;
    return sample ?? await super.current();
  }

  @override
  Stream<LocationSample> watch() => positions.stream;
}

class LocationBackend extends ActiveUiFake {
  Completer<Json>? pendingLocation;
  bool locationNetworkFailure = false;
  @override
  Future<Json> mutate(String name, Json params) async {
    if (name != 'rescuer_update_location') return super.mutate(name, params);
    calls.add((name, params));
    if (locationNetworkFailure) throw StateError('Network unavailable');
    if (pendingLocation != null) return pendingLocation!.future;
    return {'sequence': params['p_sequence']};
  }
}

Future<void> flush(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.pump();
  }
}

LocationSample fix(double latitude) =>
    LocationSample(latitude, 106.69, 10, DateTime.now().toUtc());

class GpsPlatform extends GeolocatorPlatform {
  bool enabled = true;
  LocationPermission permission = LocationPermission.whileInUse;
  Object? failure;
  DateTime? capturedAt;
  int permissionRequests = 0, reads = 0;
  final positions = StreamController<Position>();
  @override
  Future<bool> isLocationServiceEnabled() async => enabled;
  @override
  Future<LocationPermission> checkPermission() async => permission;
  @override
  Future<LocationPermission> requestPermission() async {
    permissionRequests++;
    return permission;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    reads++;
    if (failure != null) throw failure!;
    return position();
  }

  Position position() => Position(
    latitude: 10.77,
    longitude: 106.69,
    timestamp: capturedAt ?? DateTime.now().toUtc(),
    accuracy: 10,
    altitude: 0,
    altitudeAccuracy: 0,
    heading: 0,
    headingAccuracy: 0,
    speed: 0,
    speedAccuracy: 0,
  );
  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    expect(locationSettings?.accuracy, LocationAccuracy.high);
    expect(locationSettings?.distanceFilter, 20);
    return positions.stream;
  }
}

void main() {
  test(
    'production service uses granted GPS coordinates, accuracy and timestamp',
    () async {
      final platform = GpsPlatform();
      final service = DeviceLocationService(platform: platform, isWeb: false);
      final sample = await service.current();
      expect(sample.latitude, 10.77);
      expect(sample.accuracy, 10);
      expect(platform.permissionRequests, 0);
      final result = service.watch().first;
      platform.positions.add(platform.position());
      expect((await result).longitude, 106.69);
      await platform.positions.close();
    },
  );

  for (final permission in [
    LocationPermission.denied,
    LocationPermission.deniedForever,
  ]) {
    test('$permission cannot obtain GPS or fake a location', () async {
      final platform = GpsPlatform()..permission = permission;
      await expectLater(
        DeviceLocationService(platform: platform, isWeb: false).current(),
        throwsA(
          isA<LocationFailure>().having(
            (e) => e.status,
            'status',
            permission == LocationPermission.denied
                ? GpsStatus.denied
                : GpsStatus.deniedForever,
          ),
        ),
      );
      expect(platform.reads, 0);
      expect(
        platform.permissionRequests,
        permission == LocationPermission.denied ? 1 : 0,
      );
    });
  }

  test('disabled GPS, timeout, web permission failure and stale samples are rejected', () async {
    final off = GpsPlatform()..enabled = false;
    await expectLater(
      DeviceLocationService(platform: off, isWeb: false).current(),
      throwsA(
        isA<LocationFailure>().having(
          (e) => e.status,
          'status',
          GpsStatus.disabled,
        ),
      ),
    );
    for (final error in [
      TimeoutException('timeout'),
      const PermissionDeniedException('web'),
    ]) {
      final platform = GpsPlatform()..failure = error;
      await expectLater(
        DeviceLocationService(platform: platform, isWeb: true).current(),
        throwsA(isA<LocationFailure>()),
      );
      expect(platform.permissionRequests, 0);
    }
    final stale = GpsPlatform()
      ..capturedAt = DateTime.now().subtract(const Duration(minutes: 3));
    await expectLater(
      DeviceLocationService(platform: stale, isWeb: true).current(),
      throwsA(isA<LocationFailure>()),
    );
  });

  late LocationBackend backend;
  late LiveGps gps;
  late RescuerController controller;
  var disposed = false;
  late DateTime now;
  setUp(() async {
    backend = LocationBackend()..missingJob = true;
    gps = LiveGps();
    now = DateTime.now();
    controller = RescuerController(backend, gps, now: () => now);
    disposed = false;
  });
  tearDown(() async {
    if (!disposed) controller.dispose();
    await backend.changes.close();
    await gps.positions.close();
  });

  Future<void> online(WidgetTester tester) async {
    controller.start();
    await flush(tester);
    await controller.setOnline(true);
    await flush(tester);
  }

  int getWrites() =>
      backend.calls.where((c) => c.$1 == 'rescuer_update_location').length;

  testWidgets(
    'online starts one stream; samples throttle and preserve exact RPC fields',
    (tester) async {
      await online(tester);
      expect(gps.starts, 1);
      expect(controller.trackingGps, isTrue);
      expect(getWrites(), 1);
      gps.positions.add(fix(10.771));
      gps.positions.add(fix(10.772));
      await flush(tester);
      expect(getWrites(), 1);
      now = now.add(const Duration(seconds: 15));
      await tester.pump(const Duration(seconds: 15));
      await flush(tester);
      expect(getWrites(), 2);
      final payload = backend.calls
          .lastWhere((c) => c.$1 == 'rescuer_update_location')
          .$2;
      expect(payload.keys.toSet(), {
        'p_session_id',
        'p_sequence',
        'p_latitude',
        'p_longitude',
        'p_accuracy_m',
        'p_captured_at',
      });
      expect(payload['p_latitude'], 10.772);
      expect(payload['p_accuracy_m'], 10);
      expect(payload['p_sequence'], 2);
      await controller.checkGps();
      await flush(tester);
      expect(gps.starts, 1);
      await controller.setOnline(false);
      await flush(tester);
      expect(gps.stops, 1);
      expect(controller.trackingGps, isFalse);
      final before = getWrites();
      gps.positions.add(fix(10.8));
      await flush(tester);
      expect(getWrites(), before);
    },
  );

  testWidgets(
    'active job retains GPS while offline and keeps monotonic sequence',
    (tester) async {
      backend.missingJob = false;
      await online(tester);
      expect(controller.hasActiveJob, isTrue);
      await controller.setOnline(false);
      await flush(tester);
      expect(controller.online, isFalse);
      expect(controller.trackingGps, isTrue);
      expect(controller.sequence, 2);
      now = now.add(const Duration(seconds: 15));
      gps.positions.add(fix(10.78));
      await flush(tester);
      expect(controller.sequence, 3);
      expect(backend.calls.last.$2['p_session_id'], 'session');
      backend.missingJob = true;
      await controller.refreshActiveJob();
      await flush(tester);
      expect(controller.trackingGps, isFalse);
    },
  );

  testWidgets(
    'pause cancels GPS; resume refreshes current location exactly once',
    (tester) async {
      await online(tester);
      controller.setForeground(false);
      await flush(tester);
      expect(controller.trackingGps, isFalse);
      expect(controller.locationReady, isFalse);
      final before = getWrites();
      gps.positions.add(fix(10.79));
      await flush(tester);
      expect(getWrites(), before);
      controller.setForeground(true);
      controller.setForeground(true);
      await flush(tester);
      expect(getWrites(), before + 1);
      expect(gps.starts, 2);
      controller.dispose();
      disposed = true;
      await flush(tester);
    },
  );

  testWidgets(
    'network failure cannot mark GPS synced and retry remains throttled',
    (tester) async {
      await online(tester);
      backend.locationNetworkFailure = true;
      now = now.add(const Duration(seconds: 15));
      gps.positions.add(fix(10.78));
      await flush(tester);
      expect(controller.locationReady, isFalse);
      expect(controller.gpsError, contains('máy chủ'));
      final attempts = getWrites();
      gps.positions.add(fix(10.79));
      await flush(tester);
      expect(getWrites(), attempts);
      backend.locationNetworkFailure = false;
      now = now.add(const Duration(seconds: 15));
      await tester.pump(const Duration(seconds: 15));
      await flush(tester);
      expect(controller.locationReady, isTrue);
      controller.dispose();
      disposed = true;
      await flush(tester);
    },
  );

  testWidgets(
    'late upload after pause cannot restore ready state; logout stops GPS',
    (tester) async {
      await online(tester);
      backend.pendingLocation = Completer<Json>();
      now = now.add(const Duration(seconds: 15));
      gps.positions.add(fix(10.78));
      await flush(tester);
      controller.setForeground(false);
      backend.pendingLocation!.complete({'sequence': 2});
      backend.pendingLocation = null;
      await flush(tester);
      expect(controller.locationReady, isFalse);
      expect(controller.trackingGps, isFalse);
      await controller.signOut();
      await flush(tester);
      expect(controller.lastPosition, isNull);
      expect(controller.signedIn, isFalse);
    },
  );

  testWidgets('stale GPS cannot create an online session', (tester) async {
    gps.sample = LocationSample(
      10.77,
      106.69,
      10,
      DateTime.now().subtract(const Duration(minutes: 3)),
    );
    controller.start();
    await flush(tester);
    await controller.setOnline(true);
    expect(controller.online, isFalse);
    expect(backend.calls, isEmpty);
    expect(controller.gpsStatus, GpsStatus.unavailable);
  });

  testWidgets(
    'small movement is filtered; heartbeat refreshes stationary GPS',
    (tester) async {
      await online(tester);
      now = now.add(const Duration(seconds: 15));
      gps.positions.add(fix(10.77001));
      await flush(tester);
      expect(getWrites(), 1);
      now = now.add(const Duration(seconds: 30));
      await tester.pump(const Duration(seconds: 45));
      await flush(tester);
      expect(gps.reads, 2);
      expect(getWrites(), 2);
      controller.dispose();
      disposed = true;
      await flush(tester);
    },
  );

  testWidgets('logout stops stream even while a GPS upload is pending', (
    tester,
  ) async {
    await online(tester);
    final pending = Completer<Json>();
    backend.pendingLocation = pending;
    now = now.add(const Duration(seconds: 15));
    gps.positions.add(fix(10.78));
    await flush(tester);
    await controller.signOut();
    await flush(tester);
    expect(controller.trackingGps, isFalse);
    expect(controller.signedIn, isFalse);
    pending.complete({'sequence': 2});
    await flush(tester);
    expect(controller.locationReady, isFalse);
    expect(controller.lastPosition, isNull);
  });

  testWidgets('account switch clears GPS and ignores previous upload result', (
    tester,
  ) async {
    await online(tester);
    final pending = Completer<Json>();
    backend.pendingLocation = pending;
    now = now.add(const Duration(seconds: 15));
    gps.positions.add(fix(10.78));
    await flush(tester);
    backend.userId = 'other-rescuer';
    backend.changes.add(backend.userId);
    await flush(tester);
    expect(controller.userId, 'other-rescuer');
    expect(controller.trackingGps, isFalse);
    expect(controller.lastPosition, isNull);
    pending.complete({'sequence': 2});
    await flush(tester);
    expect(controller.locationReady, isFalse);
    expect(controller.lastPosition, isNull);
    expect(controller.sequence, 0);
  });

  testWidgets(
    'initial upload failure keeps existing online compensation rule',
    (tester) async {
      backend.locationNetworkFailure = true;
      await online(tester);
      expect(controller.online, isFalse);
      expect(controller.locationReady, isFalse);
      expect(controller.trackingGps, isFalse);
      expect(gps.starts, 0);
      expect(controller.gpsStatus, GpsStatus.active);
      expect(controller.gpsError, contains('máy chủ'));
      expect(
        backend.calls
            .where((c) => c.$1 == 'rescuer_set_online')
            .map((c) => c.$2['p_online']),
        [true, false],
      );
    },
  );

  testWidgets('active job resume refreshes GPS even after a brief pause', (
    tester,
  ) async {
    backend.missingJob = false;
    await online(tester);
    controller.setForeground(false);
    await flush(tester);
    final before = getWrites();
    gps.sample = fix(10.78);
    controller.setForeground(true);
    await flush(tester);
    expect(getWrites(), before + 1);
    expect(controller.lastPosition?.latitude, 10.78);
    expect(controller.trackingGps, isTrue);
    expect(gps.starts, 2);
    controller.dispose();
    disposed = true;
    await flush(tester);
  });
}
