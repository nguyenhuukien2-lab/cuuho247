import 'request_steps.dart';
import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/screens/history_details_screen.dart';
import 'package:cuu_ho_247/screens/new_tracking_screen.dart';
import 'package:cuu_ho_247/services/location_service.dart';
import 'package:cuu_ho_247/services/request_details_service.dart';
import 'package:cuu_ho_247/widgets/request_location_card.dart';
import 'package:cuu_ho_247/widgets/rescue_location_map.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'request_location_test.dart' as form;
import 'history_details_test.dart' as history;

MapController mapController(WidgetTester tester) =>
    tester.widget<FlutterMap>(find.byType(FlutterMap)).mapController!;
void main() {
  testWidgets('coordinate card shows map and rescue marker', (tester) async {
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: RequestLocationCard(
                address: 'Địa chỉ',
                coordinates: RescueCoordinates(16.0544, 108.2022)))));
    await tester.pumpAndSettle();
    expect(find.byType(FlutterMap), findsOneWidget);
    final marker =
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.single;
    expect(marker.point.latitude, 16.0544);
    expect(marker.point.longitude, 108.2022);
    expect(
        find.byKey(const ValueKey('rescue-location-marker')), findsOneWidget);
  });
  for (final coordinates in [null, const RescueCoordinates(double.nan, 108)]) {
    testWidgets('missing/invalid coordinates has empty state', (tester) async {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: RequestLocationCard(
                  address: 'Địa chỉ', coordinates: coordinates))));
      expect(find.text('Chưa có tọa độ'), findsOneWidget);
      expect(find.byType(FlutterMap), findsNothing);
    });
  }
  testWidgets(
      'phone default map is Da Nang without a selected marker; GPS recenters',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: Padding(
                padding: EdgeInsets.all(18),
                child: RescueLocationMap(showDefaultLocation: true)))));
    await tester.pumpAndSettle();
    expect(mapController(tester).camera.center, RescueLocationMap.daNang);
    expect(
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers, isEmpty);
    await tester.pumpWidget(const MaterialApp(
        home: Scaffold(
            body: Padding(
                padding: EdgeInsets.all(18),
                child: RescueLocationMap(
                    showDefaultLocation: true,
                    coordinates: RescueCoordinates(10.7769, 106.7009))))));
    await tester.pumpAndSettle();
    expect(mapController(tester).camera.center.latitude,
        closeTo(10.7769, 0.00001));
    expect(mapController(tester).camera.zoom, 16);
    expect(tester.takeException(), isNull);
  });
  for (final hasCoordinates in [false, true]) {
    testWidgets('tracking map presence matches coordinates=$hasCoordinates',
        (tester) async {
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = AppController()
        ..activeRequest = RescueRequestData(
            id: 'request',
            service: RescueService.tire,
            vehicle: VehicleKind.car,
            address: 'Địa chỉ',
            createdAt: DateTime.utc(2026),
            stage: RequestStage.accepted,
            latitude: hasCoordinates ? 16.0544 : null,
            longitude: hasCoordinates ? 108.2022 : null);
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: NewTrackingScreen(
                  controller: controller,
                  isActive: false,
                  photoRepository: history.PhotosFake()))));
      await tester.pumpAndSettle();
      expect(find.byType(FlutterMap),
          hasCoordinates ? findsOneWidget : findsNothing);
      if (!hasCoordinates) expect(find.text('Chưa có tọa độ'), findsOneWidget);
    });
    testWidgets('history map presence matches coordinates=$hasCoordinates',
        (tester) async {
      tester.view.physicalSize = const Size(420, 1800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = AppController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
          home: HistoryDetailsScreen(
              requestId: 'request',
              controller: controller,
              repository: history.DetailsFake(RequestDetails({
                'id': 'request',
                'status': 'cancelled',
                'location_text': 'Địa chỉ',
                'latitude': hasCoordinates ? 16.0544 : null,
                'longitude': hasCoordinates ? 108.2022 : null
              }, [])),
              photoRepository: history.PhotosFake())));
      await tester.pumpAndSettle();
      expect(find.byType(FlutterMap),
          hasCoordinates ? findsOneWidget : findsNothing);
      if (!hasCoordinates) expect(find.text('Chưa có tọa độ'), findsOneWidget);
    });
  }
  testWidgets(
      'actual map tap updates submitted coordinates and invalidates confirmation, ignores late GPS',
      (tester) async {
    final controller = form.CapturingController();
    final gps = form.FakeLocationService();
    await form.mountForm(tester, controller, gps);
    await tester.pumpAndSettle();
    await tapRequest(tester, find.text('Lấy vị trí hiện tại'));
    await tester.pump();
    await tester.tapAt(
        tester.getCenter(find.byType(FlutterMap)) + const Offset(35, -20));
    await tester.pump(const Duration(milliseconds: 400));
    gps.pending.complete(form.located);
    await tester.pumpAndSettle();
    final marker =
        tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers.single;
    await requestStep(tester, 4);
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse);
    expect(marker.point.latitude, isNot(form.located.coordinates!.latitude));
    await form.sendRequest(tester);
    expect(controller.submissions.single.latitude,
        closeTo(marker.point.latitude, 0.000001));
    expect(controller.submissions.single.longitude,
        closeTo(marker.point.longitude, 0.000001));
    expect(controller.submissions.single.address, '123 Nguyễn Huệ');
  });
  testWidgets('GPS from form moves camera and marker to actual coordinates',
      (tester) async {
    final controller = form.CapturingController();
    final gps = form.FakeLocationService();
    await form.mountForm(tester, controller, gps);
    await tapRequest(tester, find.text('Lấy vị trí hiện tại'));
    gps.pending.complete(form.located);
    await tester.pumpAndSettle();
    expect(mapController(tester).camera.center.latitude,
        closeTo(10.7769, 0.000001));
    expect(mapController(tester).camera.zoom, 16);
  });
}
