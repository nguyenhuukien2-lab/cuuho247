import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/app/app_theme.dart';
import 'package:cuu_ho_247/app/user_session.dart';
import 'package:cuu_ho_247/screens/new_account_screen.dart';
import 'package:cuu_ho_247/screens/new_home_screen.dart';
import 'package:cuu_ho_247/screens/new_tracking_screen.dart';
import 'package:cuu_ho_247/widgets/account_ui.dart';
import 'package:cuu_ho_247/widgets/tracking_ui.dart';
import 'package:cuu_ho_247/widgets/customer_gps_status.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'customer_profile_card_test.dart' as profiles;
import 'customer_saved_addresses_test.dart' as addresses;
import 'customer_vehicles_test.dart' as vehicles;
import 'request_photos_test.dart' as photos;
import 'tracking_ui_test.dart' as tracking;

Future<void> mountCompact(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(320, 740);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(MaterialApp(
    theme: AppTheme.light,
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: TextScaler.linear(1.5)),
      child: child!,
    ),
    home: Scaffold(body: screen),
  ));
  await tester.pumpAndSettle();
}

void main() {
  tearDown(UserSession.clear);

  for (final active in [false, true]) {
    testWidgets(
        'home hero ${active ? 'disables duplicate request' : 'opens booking'} on a small phone',
        (tester) async {
      final c = AppController()..restoringSession = false;
      addTearDown(c.dispose);
      if (active) c.activeRequest = tracking.fixture(RequestStage.searching);
      await mountCompact(tester, NewHomeScreen(controller: c));
      final action = find.widgetWithText(
          FilledButton, active ? 'YÊU CẦU ĐANG XỬ LÝ' : 'YÊU CẦU CỨU HỘ NGAY');
      await tester.scrollUntilVisible(action, 120,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(action.hitTestable(), findsOneWidget);
      expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
      expect(tester.getRect(action).bottom, lessThan(740));
      final button = tester.widget<FilledButton>(action);
      expect(button.style!.backgroundColor!.resolve({}), Colors.white);
      tracking.expectNoInventedTrackingData();
      expect(find.text('Theo dõi đơn'), findsNothing);
      if (active) {
        expect(button.onPressed, isNull);
        expect(c.tabIndex, 0);
        final track = find.widgetWithText(FilledButton, 'Theo dõi →');
        await tester.scrollUntilVisible(track, -120,
            scrollable: find.byType(Scrollable).first);
        await tester.pumpAndSettle();
        expect(track, findsOneWidget);
        expect(track.hitTestable(), findsOneWidget);
        await tester.tap(track);
      } else {
        expect(button.onPressed, isNotNull);
        await tester.tap(action);
      }
      expect(c.tabIndex, active ? 2 : 1);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'tracking separates location partner timeline quote and support with real data',
      (tester) async {
    final c = AppController()
      ..activeRequest = tracking.fixture(RequestStage.arriving,
          price: 0,
          quoteCode: 'BG-000018',
          updatedAt: DateTime(2026, 10, 4, 8, 17));
    addTearDown(c.dispose);
    await mountCompact(
        tester,
        NewTrackingScreen(
            controller: c,
            isActive: false,
            photoRepository: photos.FakePhotos()));
    expect(find.text('Mã đơn CH-000042'), findsOneWidget);
    final action = find.byTooltip('Cập nhật trạng thái');
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    expect(action.hitTestable(), findsOneWidget);
    for (final key in [
      'tracking-location',
      'tracking-partner',
      'tracking-progress',
      'tracking-quote',
      'tracking-request-info',
      'tracking-support',
    ]) {
      await tester.scrollUntilVisible(find.byKey(ValueKey(key)), 180,
          scrollable: find.byType(Scrollable).first);
      expect(find.byKey(ValueKey(key)), findsOneWidget);
    }
    final list = tester
        .widget<ListView>(find.byKey(const PageStorageKey('tracking-scroll')));
    final children =
        (list.childrenDelegate as SliverChildListDelegate).children;
    expect(children.where((w) => w is! SizedBox).map((w) => w.runtimeType), [
      TrackingStatusCard,
      TrackingMapCard,
      CustomerGpsStatus,
      RescuerInfoCard,
      TrackingTimeline,
      QuoteStatusCard,
      TrackingOrderCard,
      TrackingSupportCard,
    ]);
    expect(find.text('0đ'), findsOneWidget);
    expect(find.text('Mã báo giá: BG-000018'), findsOneWidget);
    await tester.scrollUntilVisible(find.byType(TrackingTimeline), -180,
        scrollable: find.byType(Scrollable).first);
    await tester.pumpAndSettle();
    final steps =
        tester.widgetList<TimelineStep>(find.byType(TimelineStep)).toList();
    expect(steps, hasLength(6));
    final current = steps.singleWhere((step) => step.current);
    expect(current.title, 'Đang trên đường tới');
    // A quote changes updated_at without a status transition. Only an event
    // timestamp may be attached to the current timeline milestone.
    expect(current.time, isNull);
    expect(steps.first.time, '07:09');
    expect(steps.skip(1).every((step) => step.time == null), isTrue);
    expect(current.activeColor, TrackingStyle.blue);
    expect(steps.where((step) => step.done), hasLength(1));
    tracking.expectNoInventedTrackingData();
    expect(tester.takeException(), isNull);
  });

  testWidgets('account sections show real previews and keep management screens',
      (tester) async {
    UserSession.userId = 'owner';
    final c = AppController();
    addTearDown(c.dispose);
    await mountCompact(
        tester,
        NewAccountScreen(
          controller: c,
          profileRepository: profiles.ProfileFake(),
          vehicleRepository: vehicles.VehiclesFake()
            ..vehicles = [vehicles.truck],
          addressRepository: addresses.AddressesFake()
            ..addresses = [addresses.saved],
        ));
    expect(find.byType(CustomerAccountHeaderCard), findsOneWidget);
    await tester.scrollUntilVisible(find.byType(AccountVehicleCard), 180,
        scrollable: find.byType(Scrollable).first);
    expect(find.byType(AccountVehicleCard), findsOneWidget);
    expect(find.text(vehicles.truck.brandModel), findsOneWidget);
    await tester.scrollUntilVisible(find.byType(AccountAddressSection), 180,
        scrollable: find.byType(Scrollable).first);
    expect(find.text(addresses.saved.label), findsOneWidget);
    expect(find.text(addresses.saved.address), findsOneWidget);
    for (final key in ['customer-account-settings']) {
      await tester.scrollUntilVisible(find.byKey(ValueKey(key)), 180,
          scrollable: find.byType(Scrollable).first);
      expect(find.byKey(ValueKey(key)), findsOneWidget);
    }
    expect(find.byType(AccountSectionTitle), findsWidgets);
    await tester.scrollUntilVisible(find.text('Đăng xuất tài khoản'), 180,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Đăng xuất tài khoản'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
