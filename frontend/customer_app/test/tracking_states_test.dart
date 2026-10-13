import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/app/app_theme.dart';
import 'package:cuu_ho_247/services/location_service.dart';
import 'package:cuu_ho_247/widgets/rescue_location_map.dart';
import 'package:cuu_ho_247/widgets/tracking_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';

import 'tracking_ui_test.dart' as tracking;
import 'tracking_visual_test.dart' show OfflineTrackingTiles;

const customerPoint = RescueCoordinates(16.075, 108.235);
const partnerPoint = RescueCoordinates(16.077, 108.237);
// Test inputs only; production never supplies these fixtures.
const suppliedRoute = [
  partnerPoint,
  RescueCoordinates(16.077, 108.235),
  customerPoint,
];

Future<void> mount(WidgetTester tester, Widget child) =>
    tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: SingleChildScrollView(child: child))));

void main() {
  setUp(() => RescueLocationMap.tileProviderFactory = OfflineTrackingTiles.new);
  tearDown(() => RescueLocationMap.tileProviderFactory = null);

  testWidgets('searching ignores travel and partner inputs and stays compact',
      (tester) async {
    await mount(
        tester,
        Column(children: [
          TrackingStatusCard(
              request: tracking.fixture(RequestStage.searching),
              etaMinutes: 12,
              distanceKm: 2.4,
              speedKmh: 25),
          RescuerInfoCard(
              stage: RequestStage.searching,
              partnerName: 'Tên đối tác trong fixture',
              rating: 4.6,
              vehicleLabel: 'Xe cứu hộ',
              licensePlate: '43C-123.45',
              phone: '0901234567',
              onCall: () {},
              onChat: () {}),
        ]));
    expect(find.text('Đang tìm đối tác cứu hộ'), findsOneWidget);
    expect(find.byType(TrackingInfoBlock), findsNWidgets(3));
    expect(find.text('Trạng thái'), findsOneWidget);
    expect(find.text('Cập nhật'), findsOneWidget);
    expect(find.text('Dịch vụ'), findsOneWidget);
    expect(find.text('Chưa có đối tác nhận đơn'), findsOneWidget);
    expect(find.text('Tên đối tác trong fixture'), findsNothing);
    expect(
        find.byKey(const ValueKey('tracking-partner-vehicle')), findsNothing);
    expect(tester.getSize(find.byType(RescuerInfoCard)).height, lessThan(110));
    tracking.expectNoInventedTrackingData();
    expect(tester.takeException(), isNull);
  });

  for (final stage in [RequestStage.accepted, RequestStage.arriving]) {
    testWidgets(
        '$stage hides missing ETA and renders only supplied travel stats',
        (tester) async {
      await mount(tester, TrackingStatusCard(request: tracking.fixture(stage)));
      expect(find.text(trackingHeadline(stage)), findsOneWidget);
      expect(find.byType(TrackingInfoBlock), findsOneWidget);
      expect(find.text('Dịch vụ'), findsOneWidget);
      expect(find.text('Cập nhật'), findsNothing);
      tracking.expectNoInventedTrackingData();

      await mount(
          tester,
          TrackingStatusCard(
              request: tracking.fixture(stage), distanceKm: 2.4, speedKmh: 0));
      expect(find.text('ETA'), findsNothing);
      expect(find.text('2.4 km'), findsOneWidget);
      expect(find.text('0 km/h'), findsOneWidget);
      expect(find.byType(TrackingInfoBlock), findsNWidgets(2));

      await mount(
          tester,
          TrackingStatusCard(
              request: tracking.fixture(stage),
              etaMinutes: 12,
              distanceKm: 2.4,
              speedKmh: 25));
      expect(find.text('12 phút'), findsOneWidget);
      expect(find.text('2.4 km'), findsOneWidget);
      expect(find.text('25 km/h'), findsOneWidget);
      expect(find.byType(TrackingInfoBlock), findsNWidgets(3));

      await mount(
          tester,
          TrackingStatusCard(
              request: tracking.fixture(stage),
              etaMinutes: -1,
              distanceKm: double.nan,
              speedKmh: double.infinity));
      tracking.expectNoInventedTrackingData();
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('GPS alone or with partner never invents a route',
      (tester) async {
    for (final partner in <RescueCoordinates?>[null, partnerPoint]) {
      await mount(
          tester,
          TrackingMapCard(
              request: tracking.fixture(RequestStage.arriving,
                  latitude: customerPoint.latitude,
                  longitude: customerPoint.longitude),
              partnerCoordinates: partner));
      await tester.pumpAndSettle();
      final tiles = tester.widget<TileLayer>(find.byType(TileLayer));
      expect(
          tiles.urlTemplate, 'https://tile.openstreetmap.org/{z}/{x}/{y}.png');
      final markers =
          tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers;
      expect(markers, hasLength(partner == null ? 1 : 2));
      expect(markers.first.point.latitude, customerPoint.latitude);
      expect(find.byType(PolylineLayer), findsNothing);
      if (partner == null) {
        expect(find.text('Vị trí cứu hộ'), findsOneWidget);
        expect(find.text('Vị trí cứu hộ đã xác nhận'), findsOneWidget);
        expect(find.byKey(const ValueKey('tracking-partner-marker')),
            findsNothing);
      } else {
        expect(markers.last.point.longitude, partnerPoint.longitude);
        expect(find.text('Đối tác đang di chuyển đến'), findsOneWidget);
        expect(find.text('Vị trí đối tác đã cập nhật'), findsOneWidget);
        expect(find.text('Lộ trình đến vị trí cứu hộ'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('route uses exact supplied points and rejects incomplete data',
      (tester) async {
    for (final route in [
      suppliedRoute,
      <RescueCoordinates>[],
      [partnerPoint],
      [partnerPoint, const RescueCoordinates(95, 108)],
    ]) {
      await mount(
          tester,
          TrackingMapCard(
              request: tracking.fixture(RequestStage.accepted,
                  latitude: customerPoint.latitude,
                  longitude: customerPoint.longitude),
              partnerCoordinates: partnerPoint,
              routeCoordinates: route));
      await tester.pumpAndSettle();
      if (identical(route, suppliedRoute)) {
        final line = tester
            .widget<PolylineLayer>(find.byType(PolylineLayer))
            .polylines
            .single;
        expect(line.points.map((point) => point.latitude),
            suppliedRoute.map((point) => point.latitude));
        expect(line.points.map((point) => point.longitude),
            suppliedRoute.map((point) => point.longitude));
        expect(find.text('Lộ trình đến vị trí cứu hộ'), findsOneWidget);
      } else {
        expect(find.byType(PolylineLayer), findsNothing);
        expect(find.text('Lộ trình đến vị trí cứu hộ'), findsNothing);
      }
      expect(tester.takeException(), isNull);
    }
    await mount(
        tester,
        TrackingMapCard(
            request: tracking.fixture(RequestStage.searching,
                latitude: customerPoint.latitude,
                longitude: customerPoint.longitude),
            partnerCoordinates: partnerPoint,
            routeCoordinates: suppliedRoute));
    await tester.pumpAndSettle();
    expect(find.byType(PolylineLayer), findsNothing);
    expect(tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers,
        hasLength(1));
    tracking.expectNoInventedTrackingData();
  });

  testWidgets('assigned partner uses supplied profile and working actions only',
      (tester) async {
    var calls = 0, chats = 0;
    await mount(
        tester,
        RescuerInfoCard(
            stage: RequestStage.accepted,
            partnerName: 'Tên đối tác trong fixture',
            rating: 4.6,
            vehicleLabel: 'Xe cứu hộ',
            licensePlate: '43C-123.45',
            phone: '0901234567',
            onCall: () => calls++,
            onChat: () => chats++));
    expect(find.text('Tên đối tác trong fixture'), findsOneWidget);
    expect(find.text('Đã nhận'), findsOneWidget);
    expect(find.text('4.6'), findsOneWidget);
    expect(find.text('Xe cứu hộ'), findsOneWidget);
    expect(find.text('Biển số: 43C-123.45'), findsOneWidget);
    await tester.tap(find.text('Gọi đối tác'));
    await tester.tap(find.byTooltip('Nhắn tin'));
    expect(calls, 1);
    expect(chats, 1);
    expect(find.text('Đã xác thực'), findsNothing);

    await mount(
        tester,
        const RescuerInfoCard(
            stage: RequestStage.arriving,
            partnerName: 'Tên đối tác trong fixture'));
    expect(find.byIcon(Icons.star_rounded), findsNothing);
    expect(
        find.byKey(const ValueKey('tracking-partner-vehicle')), findsNothing);
    expect(find.text('Gọi đối tác'), findsNothing);
    expect(find.byTooltip('Nhắn tin'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing partner and UUID fields do not become a profile',
      (tester) async {
    for (final name in <String?>[null, '', tracking.requestUuid]) {
      await mount(
          tester,
          RescuerInfoCard(
              stage: RequestStage.accepted,
              partnerName: name,
              licensePlate: tracking.requestUuid,
              phone: tracking.requestUuid,
              rating: double.nan,
              onCall: () {}));
      expect(find.text('Đối tác đã nhận đơn'), findsOneWidget);
      expect(find.text('Chưa có thông tin liên hệ đối tác trong đơn.'),
          findsOneWidget);
      expect(find.byIcon(Icons.star_rounded), findsNothing);
      expect(find.text('Gọi đối tác'), findsNothing);
      expect(
          find.byKey(const ValueKey('tracking-partner-vehicle')), findsNothing);
      tracking.expectNoInventedTrackingData();
      expect(tester.takeException(), isNull);
    }
    await mount(
        tester,
        const RescuerInfoCard(
            stage: RequestStage.accepted, phone: '0901234567'));
    expect(find.text('Gọi đối tác'), findsNothing);
  });

  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 1.5]) {
      testWidgets('assigned profile and travel layout fits $width / $scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 1000);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: Scaffold(
                body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(children: [
                      TrackingStatusCard(
                          request: tracking.fixture(RequestStage.arriving),
                          etaMinutes: 12,
                          distanceKm: 2.4,
                          speedKmh: 25),
                      const SizedBox(height: 12),
                      RescuerInfoCard(
                          stage: RequestStage.arriving,
                          partnerName: 'Tên đối tác dài trong fixture kiểm thử',
                          rating: 4.6,
                          vehicleLabel: 'Xe cứu hộ sàn trượt trong fixture',
                          licensePlate: '43C-123.45',
                          phone: '0901234567',
                          onCall: () {},
                          onChat: () {}),
                    ])))));
        await tester.pumpAndSettle();
        expect(find.text('12 phút'), findsOneWidget);
        expect(find.text('Biển số: 43C-123.45'), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
