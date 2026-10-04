import 'dart:async';
import 'package:cuu_ho_247/services/location_service.dart';
import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/app/app_theme.dart';
import 'package:cuu_ho_247/app/user_session.dart';
import 'package:cuu_ho_247/screens/new_home_screen.dart';
import 'package:cuu_ho_247/widgets/home_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'request_location_test.dart' as gps;

void main() {
  tearDown(UserSession.clear);
  testWidgets('GPS refresh uses real result, denial is shown and retry works',
      (tester) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    final location = gps.FakeLocationService();
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
            body: NewHomeScreen(
                controller: controller, locationService: location))));
    expect(find.text('Đang xác định vị trí'), findsOneWidget);
    expect(location.calls, 0);
    await tester.tap(find.byTooltip('Làm mới vị trí'));
    await tester.pump();
    expect(location.calls, 1);
    location.pending.complete(
        const LocationResult(LocationStatus.denied, 'Quyền vị trí bị từ chối'));
    await tester.pumpAndSettle();
    expect(find.text('Quyền vị trí bị từ chối'), findsOneWidget);
    location.pending = Completer<LocationResult>();
    await tester.tap(find.byTooltip('Làm mới vị trí'));
    location.pending.complete(gps.located);
    await tester.pumpAndSettle();
    expect(find.text('10.776900, 106.700900'), findsOneWidget);
    expect(find.text('Đã cập nhật GPS'), findsOneWidget);
    expect(find.textContaining('chính xác'), findsNothing);
  });
  testWidgets('home exposes active order only while nonterminal',
      (tester) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    Future<void> mount() => tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: NewHomeScreen(controller: controller))));
    await mount();
    expect(find.byType(ActiveOrderBanner), findsNothing);
    controller.activeRequest = RescueRequestData(
        id: 'real-order',
        service: RescueService.tire,
        vehicle: VehicleKind.car,
        address: 'Địa chỉ từ đơn',
        createdAt: DateTime(2026),
        stage: RequestStage.searching);
    await mount();
    expect(find.byType(ActiveOrderBanner), findsOneWidget);
    await tester.tap(find.text('Theo dõi'));
    expect(controller.tabIndex, 2);
    for (final stage in [RequestStage.completed, RequestStage.cancelled]) {
      controller.activeRequest!.stage = stage;
      await mount();
      expect(find.byType(ActiveOrderBanner), findsNothing);
    }
  });
  testWidgets('service cards forward supported codes and preserve fallback',
      (tester) async {
    RescueService? selection;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: HomeServiceGrid(
                    onSelected: (service) => selection = service)))));
    for (final service in HomeServiceGrid.services) {
      final card = find.widgetWithText(ServiceCard, service.$1);
      await tester.ensureVisible(card);
      await tester.tap(card);
      expect(selection, service.$5);
    }
  });
}
