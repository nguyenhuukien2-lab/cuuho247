import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/app/app_theme.dart';
import 'package:cuu_ho_247/app/user_session.dart';
import 'package:cuu_ho_247/screens/new_home_screen.dart';
import 'package:cuu_ho_247/screens/new_request_screen.dart';
import 'package:cuu_ho_247/screens/new_tracking_screen.dart';
import 'package:cuu_ho_247/screens/new_history_screen.dart';
import 'package:cuu_ho_247/screens/new_account_screen.dart';
import 'package:cuu_ho_247/widgets/booking_ui.dart';
import 'package:cuu_ho_247/widgets/stitch_customer_header.dart';
import 'account_ui_test.dart' as account;
import 'customer_vehicles_test.dart' as vehicles;
import 'customer_saved_addresses_test.dart' as addresses;
import 'request_photos_test.dart' as photos;
import 'tracking_ui_test.dart' as tracking;

/// Checks real widgets at every requested width/scale, using repository fixtures
/// only inside tests. OSM tiles are deterministic through flutter_test_config.
void main() {
  tearDown(UserSession.clear);
  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 1.3, 1.5]) {
      for (var tab = 0; tab < 5; tab++) {
        testWidgets(
            'Stitch tab $tab at $width / $scale has readable scrolling content',
            (tester) async {
          tester.view.physicalSize = Size(width, 844);
          tester.view.devicePixelRatio = 1;
          tester.view.padding = const FakeViewPadding(bottom: 24);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPadding);
          UserSession.userId = 'owner';
          UserSession.fullName = 'Nguyễn An';
          final controller = AppController()
            ..restoringSession = false
            ..tabIndex = tab
            ..selectedService = RescueService.towing
            ..history = [
              tracking.fixture(RequestStage.completed, price: 125000)
            ];
          if (tab == 0 || tab == 2) {
            controller.activeRequest = tracking.fixture(RequestStage.arriving,
                latitude: 16.075, longitude: 108.235);
          }
          addTearDown(controller.dispose);
          final vehicleRepo = vehicles.VehiclesFake()
            ..vehicles = [vehicles.truck];
          final addressRepo = addresses.AddressesFake()
            ..addresses = [addresses.saved];
          final Widget screen = switch (tab) {
            0 => NewHomeScreen(controller: controller),
            1 => NewRequestScreen(
                controller: controller,
                vehicleRepository: vehicleRepo,
                addressRepository: addressRepo,
                photoRepository: photos.FakePhotos()),
            2 => NewTrackingScreen(
                controller: controller,
                isActive: false,
                photoRepository: photos.FakePhotos()),
            3 => NewHistoryScreen(controller: controller),
            _ => NewAccountScreen(
                controller: controller,
                vehicleRepository: vehicleRepo,
                addressRepository: addressRepo,
                profileRepository: account.CodedProfileFake()),
          };
          final boundaryKey = GlobalKey();
          await tester.pumpWidget(MaterialApp(
              theme: AppTheme.light,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!),
              home: RepaintBoundary(
                  key: boundaryKey,
                  child: Scaffold(
                      body: SafeArea(bottom: false, child: screen),
                      bottomNavigationBar:
                          CustomerBottomNav(controller: controller)))));
          await tester.pumpAndSettle();

          Future<void> capture(String position) async {
            if (!const bool.fromEnvironment('CAPTURE_STITCH_UI') ||
                width != 390 ||
                scale != 1) return;
            final boundary = boundaryKey.currentContext!.findRenderObject()!
                as RenderRepaintBoundary;
            await tester.runAsync(() async {
              final image = await boundary.toImage(pixelRatio: 2);
              final data =
                  await image.toByteData(format: ui.ImageByteFormat.png);
              final folder = Directory(
                  '${Directory.systemTemp.path}/stitch-customer-flutter-renders');
              await folder.create(recursive: true);
              await File('${folder.path}/tab-$tab-$position.png')
                  .writeAsBytes(data!.buffer.asUint8List());
              image.dispose();
            });
          }

          await capture('top');
          final header = tester.getRect(find.byType(StitchCustomerHeader));
          if (scale == 1) expect(header.height, 64);
          final nav = tester.getRect(find.byType(CustomerBottomNav));
          expect(
              tester.getSize(
                  find.byKey(const ValueKey('customer-booking-nav-circle'))),
              const Size(56, 56));
          final scrolling = find
              .byWidgetPredicate((widget) =>
                  widget is Scrollable && widget.axis == Axis.vertical)
              .first;
          final scroll = tester.state<ScrollableState>(scrolling);
          expect(tester.getRect(scrolling).top,
              greaterThanOrEqualTo(header.bottom));
          expect(tester.getRect(scrolling).bottom, lessThanOrEqualTo(nav.top));
          var reachedBottom = false;
          for (var page = 0; page < 60; page++) {
            expect(tester.takeException(), isNull);
            for (final element in find.byType(RichText).evaluate()) {
              final paragraph = element.renderObject;
              if (paragraph is RenderParagraph && paragraph.hasSize) {
                expect(paragraph.didExceedMaxLines, isFalse,
                    reason:
                        'Truncated text on tab $tab at $width/$scale: ${paragraph.text.toPlainText()}');
              }
            }
            if (scroll.position.pixels >=
                scroll.position.maxScrollExtent - .5) {
              reachedBottom = true;
              break;
            }
            scroll.position.jumpTo((scroll.position.pixels + 220)
                .clamp(0, scroll.position.maxScrollExtent));
            await tester.pumpAndSettle();
          }
          expect(reachedBottom, isTrue,
              reason: 'All content must be reachable');
          await capture('bottom');
          for (final label in [
            'Trang chủ',
            'Theo dõi',
            'Đặt cứu hộ',
            'Lịch sử',
            'Tài khoản'
          ]) {
            expect(
                find
                    .descendant(
                        of: find.byType(CustomerBottomNav),
                        matching: find.text(label))
                    .hitTestable(),
                findsOneWidget);
          }
          expect(find.textContaining('1900'), findsNothing);
          expect(find.textContaining('Điểm thưởng'), findsNothing);
          expect(find.textContaining('Visa'), findsNothing);
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        });
      }
    }
  }
}
