import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rescuer/app/rescuer_controller.dart';
import 'package:rescuer/models/backend_models.dart';
import 'package:rescuer/services/rescuer_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'connected_app_test.dart'
    show FakeService, FakeLocation, approved, mount;
import 'new_request_preview_test.dart' show openPreview;

const manualId = '11111111-1111-4111-8111-111111111111';

Json manualProjection() => {
  'request_id': manualId,
  'request_code': 'CH-000019',
  'status': 'searching',
  'provider_id': null,
  'service_type': 'tire',
  'vehicle_type': 'car',
  'location_text': '03 Quang Trung',
  'latitude': null,
  'longitude': null,
  'approximate_location': null,
  'estimated_distance_km': null,
  'contact_name': 'PRIVATE CUSTOMER',
  'contact_phone': 'PRIVATE PHONE',
};

Json gpsProjection() => {
  'request_id': '22222222-2222-4222-8222-222222222222',
  'request_code': 'CH-000020',
  'service_type': 'tire',
  'vehicle_type': 'car',
  'approximate_location': {
    'latitude': 10.775,
    'longitude': 106.695,
    'cell_size_degrees': 0.01,
    'precision': 'coarse',
  },
  'estimated_distance_km': 2,
};

// A permitted RPC result, not a query of rescue_requests or a bypass of RLS.
class ManualFeedFake extends FakeService {
  ManualFeedFake() {
    userId = 'rescuer';
    snapshot = approved();
    page = RequestPage([AvailableRequest.fromJson(manualProjection())], null);
  }

  ActiveJob? currentJob;

  @override
  Future<ActiveJob?> getActiveJob() async => currentJob;

  @override
  Future<Json> mutate(String name, Json params) async {
    final result = await super.mutate(name, params);
    if (name != 'rescuer_claim_request') return result;
    final assignment = {
      'assignment_id': 'assignment',
      'request_id': params['p_request_id'],
      'request_code': 'CH-000019',
      'vehicle_id': params['p_vehicle_id'],
      'state': 'accepted',
      'version': 1,
      'accepted_at': '2026-10-05T01:00:00Z',
    };
    currentJob = ActiveJob.fromJson({
      ...assignment,
      'service_type': 'tire',
      'vehicle_type': 'car',
      'location_text': '03 Quang Trung',
      'latitude': null,
      'longitude': null,
    });
    page = const RequestPage([], null);
    feedFailure = const PostgrestException(
      message: 'RESCUER_BUSY',
      code: 'P0001',
    );
    return assignment;
  }
}

void expectNoPrivateOrFakeData() {
  expect(find.textContaining('PRIVATE'), findsNothing);
  expect(find.textContaining('03 Quang Trung'), findsNothing);
  expect(find.textContaining('ETA'), findsNothing);
  expect(
    find.textContaining(
      RegExp(
        r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
        caseSensitive: false,
      ),
    ),
    findsNothing,
  );
}

void main() {
  test('missing GPS parses without inventing coordinates or a distance', () {
    for (final location in [
      null,
      <String, dynamic>{'latitude': null, 'longitude': null},
      <String, dynamic>{
        'latitude': null,
        'longitude': null,
        'cell_size_degrees': 0.01,
        'precision': 'coarse',
      },
    ]) {
      final request = AvailableRequest.fromJson({
        ...manualProjection(),
        'approximate_location': location,
      });
      expect(request.requestCode, 'CH-000019');
      expect(request.latitude, isNull);
      expect(request.longitude, isNull);
      expect(request.distanceKm, isNull);
      expect(request.hasApproximateLocation, isFalse);
      expect(request.availableDistanceKm, isNull);
    }
  });

  test('precise preclaim coordinates still fail privacy validation', () {
    for (final location in [
      {'latitude': 10.771234, 'longitude': 106.691234},
      {
        'latitude': 10.771234,
        'longitude': 106.691234,
        'cell_size_degrees': 0.001,
        'precision': 'coarse',
      },
      {
        'latitude': 10.771234,
        'longitude': 106.691234,
        'cell_size_degrees': 0.01,
        'precision': 'exact',
      },
    ]) {
      expect(
        () => AvailableRequest.fromJson({
          ...gpsProjection(),
          'approximate_location': location,
        }),
        throwsFormatException,
      );
    }
  });

  test('unusable GPS cannot make a reported zero distance look real', () {
    for (final coordinates in [
      (null, null),
      (10.775, null),
      (double.nan, 106.695),
      (91.0, 106.695),
      (10.775, 181.0),
    ]) {
      final request = AvailableRequest(
        id: manualId,
        service: 'tire',
        vehicle: 'car',
        latitude: coordinates.$1,
        longitude: coordinates.$2,
        distanceKm: 0,
      );
      expect(request.hasApproximateLocation, isFalse);
      expect(request.availableDistanceKm, isNull);
    }
    final gps = AvailableRequest.fromJson(gpsProjection());
    expect(gps.hasApproximateLocation, isTrue);
    expect(gps.availableDistanceKm, 2);
  });

  test(
    'same discovery RPC retains manual rows alongside GPS rows and cursor',
    () async {
      const cursor = {'request_id': 'next', 'distance_km': 2};
      final calls = <http.Request>[];
      final client = SupabaseClient(
        'https://example.supabase.co',
        'anon-test-key',
        httpClient: MockClient((request) async {
          calls.add(request);
          expect(request.method, 'POST');
          expect(
            request.url.path,
            '/rest/v1/rpc/rescuer_list_available_requests',
          );
          expect(jsonDecode(request.body), {
            'p_vehicle_id': 'vehicle',
            'p_limit': 20,
            'p_cursor': cursor,
          });
          return http.Response(
            jsonEncode({
              'items': [manualProjection(), gpsProjection()],
              'next_cursor': cursor,
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);
      final page = await SupabaseRescuerService(client)
          .available('vehicle', cursor: cursor);
      expect(calls, hasLength(1));
      expect(page.items.map((r) => r.requestCode), ['CH-000019', 'CH-000020']);
      expect(page.items.first.availableDistanceKm, isNull);
      expect(page.items.last.availableDistanceKm, 2);
      expect(page.cursor, cursor);
    },
  );

  test(
    'manual cursor and coarse projection preserve explicit null distances',
    () async {
      const cursor = {
        'session_id': 'session',
        'sequence': 1,
        'request_id': manualId,
        'distance_km': null,
      };
      final transport = MockClient((request) async {
        expect(
          request.url.path,
          '/rest/v1/rpc/rescuer_list_available_requests',
        );
        expect(jsonDecode(request.body), {
          'p_vehicle_id': 'vehicle',
          'p_limit': 20,
          'p_cursor': cursor,
        });
        return http.Response(
          jsonEncode({
            'items': [
              {
                ...manualProjection(),
                'approximate_location': {
                  'latitude': null,
                  'longitude': null,
                  'cell_size_degrees': 0.01,
                  'precision': 'coarse',
                },
              },
            ],
            'next_cursor': cursor,
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      });
      final client = SupabaseClient(
        'https://example.supabase.co',
        'anon-test-key',
        httpClient: transport,
      );
      addTearDown(() async {
        await client.dispose();
        transport.close();
      });
      final page = await SupabaseRescuerService(client)
          .available('vehicle', cursor: cursor);
      expect(page.cursor, cursor);
      expect(page.cursor!.containsKey('distance_km'), isTrue);
      expect(page.cursor!['distance_km'], isNull);
      expect(page.items.single.requestCode, 'CH-000019');
      expect(page.items.single.hasApproximateLocation, isFalse);
      expect(page.items.single.availableDistanceKm, isNull);
    },
  );

  testWidgets(
    'manual RPC row appears in feed and can preview then claim when permitted',
    (tester) async {
      final service = ManualFeedFake();
      final c = RescuerController(service, FakeLocation());
      addTearDown(() => service.changes.close());
      await mount(tester, c);
      await c.setOnline(true);
      c.selectTab(1);
      await tester.pumpAndSettle();
      expect(c.feedStatus, FeedStatus.ready);
      expect(c.requests.single.requestCode, 'CH-000019');
      expect(find.text('Mã đơn: CH-000019'), findsOneWidget);
      expect(find.text('Vá/thay lốp'), findsOneWidget);
      expect(find.text('Loại xe: Ô tô'), findsOneWidget);
      expect(find.text('Chưa có tọa độ GPS'), findsOneWidget);
      expect(find.text('Chưa có khoảng cách ước tính'), findsNothing);
      expect(find.textContaining(RegExp(r'\d+\s*km')), findsNothing);
      expectNoPrivateOrFakeData();
      await openPreview(tester, c, manualId);
      expect(find.text('Xem trước yêu cầu'), findsOneWidget);
      expect(find.text('Chưa có tọa độ GPS'), findsWidgets);
      expect(find.text('Xem tọa độ khu vực'), findsNothing);
      expect(find.textContaining(RegExp(r'\d+\s*km')), findsNothing);
      expectNoPrivateOrFakeData();
      final claim = find.byKey(const ValueKey('claim-$manualId'));
      final button = find.descendant(
        of: claim,
        matching: find.byType(FilledButton),
      );
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      await tester.tap(claim);
      await tester.pumpAndSettle();
      final calls = service.calls
          .where((r) => r.$1 == 'rescuer_claim_request')
          .toList();
      expect(calls, hasLength(1));
      expect(calls.single.$2, {
        'p_request_id': manualId,
        'p_vehicle_id': 'vehicle',
      });
      expect(c.claimSuccessSerial, 1);
      expect(c.tab, 2);
      expect(c.activeJob?.latitude, isNull);
      expect(c.activeJob?.longitude, isNull);
      expect(find.text('03 Quang Trung'), findsOneWidget);
      expect(find.text('Mở Google Maps'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'GPS row uses server distance and coarse coordinates, never guessed place names',
    (tester) async {
      final service = ManualFeedFake()
        ..page = RequestPage([
          AvailableRequest.fromJson(gpsProjection()),
        ], null);
      final c = RescuerController(service, FakeLocation());
      addTearDown(() => service.changes.close());
      await mount(tester, c);
      await c.setOnline(true);
      c.selectTab(1);
      await tester.pumpAndSettle();
      expect(find.text('Khoảng cách ước tính · 2 km'), findsOneWidget);
      expect(find.text('Chưa có tọa độ GPS'), findsNothing);
      expectNoPrivateOrFakeData();
      await openPreview(tester, c, c.requests.single.id);
      expect(find.text('Khoảng cách ước tính · 2 km'), findsWidgets);
      final coords = find.text('Xem tọa độ khu vực');
      await tester.ensureVisible(coords);
      await tester.pumpAndSettle();
      await tester.tap(coords);
      await tester.pumpAndSettle();
      expect(find.text('10.775, 106.695'), findsOneWidget);
      expectNoPrivateOrFakeData();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'server rejection of a manual claim is respected without success or alternate queries',
    (tester) async {
      final service = ManualFeedFake()
        ..failedMutation = 'rescuer_claim_request'
        ..mutationFailure = const PostgrestException(
          message: 'REQUEST_UNAVAILABLE',
          code: 'P0001',
        );
      final c = RescuerController(service, FakeLocation());
      addTearDown(() => service.changes.close());
      await mount(tester, c);
      await c.setOnline(true);
      c.selectTab(1);
      await tester.pumpAndSettle();
      await openPreview(tester, c, manualId);
      await tester.tap(find.byKey(const ValueKey('claim-$manualId')));
      await tester.pumpAndSettle();
      expect(c.claimSuccessSerial, 0);
      expect(c.activeJob, isNull);
      expect(find.text('Chưa nhận được đơn'), findsOneWidget);
      expect(
        find.text('Đơn đã có người nhận hoặc không còn khả dụng.'),
        findsWidgets,
      );
      expect(
        service.calls.where((r) => r.$1 == 'rescuer_claim_request'),
        hasLength(1),
      );
      expectNoPrivateOrFakeData();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
