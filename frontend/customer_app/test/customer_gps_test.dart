import 'dart:async';

import 'package:cuu_ho_247/app/customer_gps_controller.dart';
import 'package:cuu_ho_247/services/location_service.dart';
import 'package:flutter_test/flutter_test.dart';

class LiveCustomerGps
    implements CustomerLocationService, CustomerLocationStreamService {
  int reads = 0, starts = 0, stops = 0;
  Completer<LocationResult>? pending;
  LocationResult? failure;
  late final positions = StreamController<LocationResult>.broadcast(
    sync: true,
    onListen: () => starts++,
    onCancel: () => stops++,
  );

  LocationResult fix(double latitude) => LocationResult(
        LocationStatus.acquired,
        'GPS thật từ thiết bị',
        coordinates: RescueCoordinates(latitude, 106.7),
        accuracy: 8,
        capturedAt: DateTime.now().toUtc(),
      );

  @override
  Future<LocationResult> getCurrentLocation() async {
    reads++;
    return pending == null ? failure ?? fix(10.77) : pending!.future;
  }

  @override
  Stream<LocationResult> watchLocation() => positions.stream;
}

Future<void> flush() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late LiveCustomerGps service;
  late CustomerGpsController gps;
  setUp(() {
    service = LiveCustomerGps();
    gps = CustomerGpsController(service);
  });
  tearDown(() async {
    gps.dispose();
    await flush();
    await service.positions.close();
  });

  test('opening a signed in app reads real GPS and starts only one stream',
      () async {
    gps.setUser('customer-a');
    await flush();
    expect(service.reads, 1);
    expect(gps.result.coordinates?.latitude, 10.77);
    expect(gps.result.accuracy, 8);
    expect(gps.tracking, isTrue);
    await Future.wait([gps.refresh(), gps.refresh(), gps.refresh()]);
    expect(service.reads, 2);
    expect(service.starts, 1);
    service.positions.add(service.fix(10.78));
    expect(gps.result.coordinates?.latitude, 10.78);
  });

  test(
      'pause cancels, resume refreshes, repeated resume cannot duplicate stream',
      () async {
    gps.setUser('customer-a');
    await flush();
    gps.setForeground(false);
    await flush();
    expect(service.stops, 1);
    expect(gps.tracking, isFalse);
    service.positions.add(service.fix(10.79));
    expect(gps.result.coordinates, isNull);
    gps.setForeground(true);
    gps.setForeground(true);
    await flush();
    expect(service.reads, 2);
    expect(service.starts, 2);
  });

  test('logout cancels GPS, clears coordinates and ignores late reads',
      () async {
    gps.setUser('customer-a');
    await flush();
    service.pending = Completer<LocationResult>();
    final read = gps.refresh();
    gps.setUser(null);
    service.pending!.complete(service.fix(10.8));
    await read;
    await flush();
    expect(gps.tracking, isFalse);
    expect(gps.lastFix, isNull);
    expect(gps.result.coordinates, isNull);
    expect(service.stops, 1);
  });

  test('another user cannot inherit previous GPS or late stream events',
      () async {
    gps.setUser('customer-a');
    await flush();
    final pending = Completer<LocationResult>();
    service.pending = pending;
    final old = gps.refresh();
    gps.setUser(null);
    service.pending = null;
    gps.setUser('customer-b');
    await flush();
    pending.complete(service.fix(11.0));
    await old;
    expect(gps.lastFix?.coordinates?.latitude, 10.77);
    expect(service.starts, 2);
    expect(service.stops, 1);
    expect(gps.result.coordinates?.latitude, 10.77);
  });

  for (final result in [
    const LocationResult(LocationStatus.denied, 'Denied'),
    const LocationResult(LocationStatus.denied, 'Blocked',
        issue: LocationIssue.deniedForever),
    const LocationResult(LocationStatus.unavailable, 'Off',
        issue: LocationIssue.disabled),
    const LocationResult(LocationStatus.unavailable, 'Timeout',
        issue: LocationIssue.timeout),
  ]) {
    test(
        '${result.issue ?? result.status} never starts a stream or invents GPS',
        () async {
      service.failure = result;
      gps.setUser('customer-a');
      await flush();
      expect(gps.result, same(result));
      expect(gps.result.coordinates, isNull);
      expect(service.starts, 0);
    });
  }

  test('stream permission failure stops the subscription and permits retry',
      () async {
    gps.setUser('customer-a');
    await flush();
    service.positions
        .add(const LocationResult(LocationStatus.denied, 'Revoked'));
    await flush();
    expect(gps.result.status, LocationStatus.denied);
    expect(gps.tracking, isFalse);
    expect(service.stops, 1);
    await gps.refresh();
    expect(gps.tracking, isTrue);
    expect(service.starts, 2);
  });

  test('stale stream sample cannot replace the last real fresh fix', () async {
    gps.setUser('customer-a');
    await flush();
    service.positions.add(LocationResult(LocationStatus.acquired, 'Old fix',
        coordinates: const RescueCoordinates(11, 106.7),
        capturedAt: DateTime.now().subtract(const Duration(minutes: 3))));
    await flush();
    expect(gps.result.issue, LocationIssue.stale);
    expect(gps.result.coordinates, isNull);
    expect(gps.lastFix?.coordinates?.latitude, 10.77);
    expect(gps.tracking, isFalse);
  });
}
