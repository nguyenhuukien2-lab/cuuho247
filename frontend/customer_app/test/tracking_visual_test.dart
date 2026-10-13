import 'dart:io';

import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/app/app_theme.dart';
import 'package:cuu_ho_247/app/user_session.dart';
import 'package:cuu_ho_247/widgets/booking_ui.dart';
import 'package:cuu_ho_247/screens/new_tracking_screen.dart';
import 'package:cuu_ho_247/widgets/rescue_location_map.dart';
import 'package:cuu_ho_247/widgets/tracking_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';

import 'request_photos_test.dart' as photos;
import 'tracking_ui_test.dart' as tracking;

class OfflineTrackingTiles extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(photos.png());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
    final root = Platform.environment['FLUTTER_ROOT'];
    final font = [
      File('${artifacts.path}/material_fonts/roboto-regular.ttf'),
      if (root != null)
        File('$root/bin/cache/artifacts/material_fonts/roboto-regular.ttf'),
    ].firstWhere((file) => file.existsSync());
    await (FontLoader('Roboto')
          ..addFont(
              Future.value(ByteData.sublistView(await font.readAsBytes()))))
        .load();
  });
  setUp(() => RescueLocationMap.tileProviderFactory = OfflineTrackingTiles.new);
  tearDown(() {
    RescueLocationMap.tileProviderFactory = null;
    UserSession.clear();
  });

  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 1.3, 1.5]) {
      testWidgets(
          'tracking full hierarchy at $width / $scale for all real statuses',
          (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = AppController()..tabIndex = 2;
        addTearDown(controller.dispose);
        for (final stage in RequestStage.values) {
          // Isolate fixtures so PageStorage does not reuse scroll/expansion
          // state from the previous status; realtime transitions have their
          // separate lifecycle tests.
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pumpAndSettle();
          final hasGps = stage.index.isOdd;
          final hasQuote = stage == RequestStage.inProgress ||
              stage == RequestStage.completed;
          controller.activeRequest = tracking.fixture(
            stage,
            updatedAt: DateTime(2026, 10, 4, 8, 17),
            latitude: hasGps ? 16.075 : null,
            longitude: hasGps ? 108.235 : null,
            price: hasQuote ? 123456 : null,
            quoteCode: hasQuote ? 'BG-000018' : null,
          );
          await tester.pumpWidget(MaterialApp(
              theme: AppTheme.light,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!),
              home: Scaffold(
                  body: NewTrackingScreen(
                      key: ValueKey(stage),
                      controller: controller,
                      isActive: false,
                      photoRepository: photos.FakePhotos()),
                  bottomNavigationBar:
                      CustomerBottomNav(controller: controller))));
          await tester.pumpAndSettle();
          final trackingScroll = find
              .descendant(
                  of: find.byKey(const PageStorageKey('tracking-scroll')),
                  matching: find.byType(Scrollable))
              .first;
          tester.state<ScrollableState>(trackingScroll).position.jumpTo(0);
          await tester.pumpAndSettle();
          expect(
              find.descendant(
                  of: find.byType(TrackingStatusCard),
                  matching: find.text(trackingHeadline(stage))),
              findsOneWidget);
          expect(find.text('Mã đơn CH-000042'), findsOneWidget);
          expect(find.text('08:17'), findsOneWidget);
          expect(
              find.byType(TrackingInfoBlock),
              findsNWidgets(stage == RequestStage.accepted ||
                      stage == RequestStage.arriving
                  ? 2
                  : 3));
          expect(find.byType(TrackingHeader), findsOneWidget);
          expect(find.byTooltip('Mở tài khoản'), findsOneWidget);
          expect(find.text('Theo dõi'), findsOneWidget);
          final navLabels = [
            'Trang chủ',
            'Theo dõi',
            'Đặt cứu hộ',
            'Lịch sử',
            'Tài khoản'
          ];
          for (final label in navLabels) {
            expect(
                find.descendant(
                    of: find.byType(CustomerBottomNav),
                    matching: find.text(label)),
                findsOneWidget);
          }
          final scroll = find.byKey(const PageStorageKey('tracking-scroll'));
          final scrollable = find
              .descendant(of: scroll, matching: find.byType(Scrollable))
              .first;
          Future<void> reveal(Finder target) async {
            await tester.scrollUntilVisible(target, 160,
                scrollable: scrollable);
            await tester.pumpAndSettle();
            final rect = tester.getRect(target);
            expect(rect.left, greaterThanOrEqualTo(20));
            expect(rect.right, lessThanOrEqualTo(width - 20));
            expect(tester.takeException(), isNull);
          }

          await reveal(find.byType(TrackingMapCard));
          if (hasGps) {
            expect(find.byType(FlutterMap), findsOneWidget);
            final map = tester.widget<FlutterMap>(find.byType(FlutterMap));
            expect(map.mapController!.camera.center.latitude,
                closeTo(16.075, .00001));
            final markers =
                tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers;
            expect(markers, hasLength(1));
            expect(markers.single.point.longitude, 108.235);
            expect(find.byType(PolylineLayer), findsNothing);
            // Recenter changes only the camera, never the saved rescue point.
            map.mapController!.move(const LatLng(16.08, 108.24), 14);
            await tester.pump();
            final recenter = find.byTooltip('Định vị điểm cứu hộ');
            await tester.ensureVisible(recenter);
            await tester.pumpAndSettle();
            expect(recenter.hitTestable(), findsOneWidget);
            await tester.tap(recenter);
            await tester.pumpAndSettle();
            expect(map.mapController!.camera.center.latitude,
                closeTo(16.075, .00001));
            expect(controller.activeRequest!.latitude, 16.075);
          } else {
            expect(find.byType(FlutterMap), findsNothing);
            expect(
                find.descendant(
                    of: find.byType(TrackingMapCard),
                    matching: find.text('Vị trí nhập tay')),
                findsOneWidget);
          }
          await reveal(find.byType(RescuerInfoCard));
          expect(
              find.descendant(
                  of: find.byType(RescuerInfoCard),
                  matching: find.byType(Image)),
              findsNothing);
          if (stage == RequestStage.searching) {
            expect(find.text('Chưa có đối tác nhận đơn'), findsOneWidget);
          } else if (!stage.isTerminal) {
            expect(find.text('Đối tác đã nhận đơn'), findsOneWidget);
            expect(find.text('Chưa có thông tin liên hệ đối tác trong đơn.'),
                findsOneWidget);
          }
          await reveal(find.byType(TrackingTimeline));
          final steps = tester
              .widgetList<TimelineStep>(find.byType(TimelineStep))
              .toList();
          expect(steps, hasLength(stage == RequestStage.cancelled ? 7 : 6));
          expect(steps.where((step) => step.done),
              hasLength(stage == RequestStage.completed ? 2 : 1));
          expect(steps.where((step) => step.current), hasLength(1));
          expect(
              steps
                  .where((step) => !step.current && !step.done)
                  .every((step) => step.time == null),
              isTrue);
          await reveal(find.byType(QuoteStatusCard));
          if (hasQuote) {
            expect(find.text('Mã báo giá: BG-000018'), findsOneWidget);
            expect(find.text('123.456đ'), findsOneWidget);
          } else {
            expect(find.text('Chưa có báo giá'), findsOneWidget);
            expect(find.byKey(const ValueKey('tracking-quote-total')),
                findsNothing);
          }
          await reveal(find.byType(TrackingOrderCard));
          final details = find.text('Vị trí, liên hệ & ảnh');
          await tester.ensureVisible(details);
          await tester.pumpAndSettle();
          expect(details.hitTestable(), findsOneWidget);
          await tester.tap(details);
          await tester.pumpAndSettle();
          expect(find.text('Chưa có ảnh sự cố.'), findsOneWidget);
          await reveal(find.byType(TrackingSupportCard));
          expect(find.text('Hỗ trợ'), findsOneWidget);
          expect(find.textContaining('1900'), findsNothing);
          final cancel = find.text('Hủy yêu cầu cứu hộ');
          if (stage == RequestStage.searching ||
              stage == RequestStage.accepted) {
            await tester.scrollUntilVisible(cancel, 120,
                scrollable: scrollable);
            await tester.pumpAndSettle();
            expect(cancel.hitTestable(), findsOneWidget);
            expect(
                tester.getRect(cancel).bottom,
                lessThanOrEqualTo(
                    tester.getRect(find.byType(CustomerBottomNav)).top));
          } else {
            expect(cancel, findsNothing);
          }
          tracking.expectNoInventedTrackingData();
          expect(find.text('Gọi điện'), findsNothing);
          expect(find.text('Chỉ đường'), findsNothing);
          expect(find.textContaining('VAT'), findsNothing);
          expect(find.textContaining('km/h'), findsNothing);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }
}
