import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/app/app_shell.dart';
import 'package:cuu_ho_247/app/app_theme.dart';
import 'package:cuu_ho_247/app/user_session.dart';
import 'package:cuu_ho_247/screens/customer_saved_addresses_screen.dart';
import 'package:cuu_ho_247/screens/customer_vehicles_screen.dart';
import 'package:cuu_ho_247/screens/history_details_screen.dart';
import 'package:cuu_ho_247/screens/new_history_screen.dart';
import 'package:cuu_ho_247/screens/new_request_screen.dart';
import 'package:cuu_ho_247/screens/new_tracking_screen.dart';
import 'package:cuu_ho_247/services/request_details_service.dart';
import 'package:cuu_ho_247/widgets/customer_profile_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'customer_profile_card_test.dart' as profile;
import 'customer_request_reviews_test.dart' as reviews;
import 'customer_saved_addresses_test.dart' as addresses;
import 'customer_vehicles_test.dart' as vehicles;
import 'history_details_test.dart' as details;
import 'request_photos_test.dart' as photos;

const longAddress =
    '123 đường Nguyễn Văn Linh, phường Hòa Cường Bắc, thành phố Đà Nẵng, gần ngã tư và cửa hàng tiện lợi';

RescueRequestData order(RequestStage stage) => RescueRequestData(
      id: '550e8400-e29b-41d4-a716-446655440000',
      service: RescueService.fuel,
      vehicle: VehicleKind.truck,
      address: longAddress,
      createdAt: DateTime(2026, 10, 1, 19, 30),
      stage: stage,
      price: 1250000,
      latitude: 16.0544,
      longitude: 108.2022,
    );

void main() {
  setUp(() {
    UserSession.userId = 'owner';
    UserSession.fullName = 'Nguyễn Minh Anh';
  });
  tearDown(UserSession.clear);

  for (final textScale in [1.0, 1.3]) {
    for (final size in [const Size(360, 800), const Size(390, 844)]) {
      void viewport(WidgetTester tester) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        addTearDown(tester.view.resetViewInsets);
        tester.view.padding = const FakeViewPadding(top: 28, bottom: 20);
        addTearDown(tester.view.resetPadding);
      }

      Future<void> mount(WidgetTester tester, Widget screen,
          {double? scale}) async {
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(scale ?? textScale)),
              child: child!),
          home: screen,
        ));
        await tester.pump(const Duration(milliseconds: 300));
        expect(tester.takeException(), isNull);
      }

      Future<void> scrollAll(WidgetTester tester) async {
        final state =
            tester.state<ScrollableState>(find.byType(Scrollable).first);
        for (var i = 0; i < 14; i++) {
          state.position.jumpTo((state.position.pixels + 320)
              .clamp(0, state.position.maxScrollExtent));
          await tester.pump(const Duration(milliseconds: 200));
          expect(tester.takeException(), isNull,
              reason: 'Overflow while scrolling at $size');
        }
      }

      Future<void> scrollTo(WidgetTester tester, Finder target) async {
        final state =
            tester.state<ScrollableState>(find.byType(Scrollable).first);
        state.position.jumpTo(0);
        await tester.pump();
        for (var i = 0; i < 40 && target.evaluate().isEmpty; i++) {
          state.position.jumpTo((state.position.pixels + 200)
              .clamp(0, state.position.maxScrollExtent));
          await tester.pump(const Duration(milliseconds: 100));
        }
        await tester.ensureVisible(target);
        await tester.pump();
      }

      testWidgets(
          'five tabs, home emergency CTA and preserved draft at $size / $textScale',
          (tester) async {
        viewport(tester);
        final controller = AppController()..restoringSession = false;
        addTearDown(controller.dispose);
        await mount(tester, AppShell(controller: controller));
        final cta = find.text('Gọi cứu hộ ngay');
        expect(tester.getRect(cta).right, lessThanOrEqualTo(size.width - 16));
        await tester.tap(cta);
        await tester.pump(const Duration(milliseconds: 250));
        expect(controller.tabIndex, 1);
        final address = find.widgetWithText(TextFormField, 'Địa chỉ');
        await scrollTo(tester, address);
        await tester.enterText(address, longAddress);
        for (final index in [2, 3, 4, 0, 1]) {
          await tester.tap(find.byType(NavigationDestination).at(index));
          await tester.pump(const Duration(milliseconds: 250));
          expect(controller.tabIndex, index);
          expect(tester.takeException(), isNull);
        }
        await scrollTo(tester, address);
        final field = tester.widget<TextFormField>(address);
        expect(field.controller!.text, longAddress);
        expect(find.byType(NavigationDestination), findsNWidgets(5));
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'request photos, long input and keyboard leave CTA reachable at $size / $textScale',
          (tester) async {
        viewport(tester);
        final controller = AppController()
          ..selectedService = RescueService.tire;
        addTearDown(controller.dispose);
        await mount(
            tester,
            Scaffold(
                body: NewRequestScreen(
              controller: controller,
              photoPicker: photos.FakePicker(),
              photoRepository: photos.FakePhotos(),
              vehicleRepository: vehicles.VehiclesFake()
                ..vehicles = [vehicles.truck],
              addressRepository: addresses.AddressesFake()
                ..addresses = [addresses.saved],
            )));
        final choose = find.text('Chọn ảnh');
        await scrollTo(tester, choose);
        for (var i = 0; i < 3; i++) {
          await tester.ensureVisible(choose);
          await tester.tap(choose);
          await tester.pump(const Duration(milliseconds: 100));
        }
        expect(find.byTooltip('Bỏ ảnh'), findsNWidgets(3));
        expect(tester.takeException(), isNull);
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pump();
        await scrollTo(tester, find.text('Gửi yêu cầu cứu hộ'));
        await tester.ensureVisible(find.text('Gửi yêu cầu cứu hộ'));
        await tester.pump();
        expect(tester.getRect(find.text('Gửi yêu cầu cứu hộ')).bottom,
            lessThanOrEqualTo(size.height - 300));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'tracking stages and long history cards remain readable at $size / $textScale',
          (tester) async {
        viewport(tester);
        final controller = AppController();
        addTearDown(controller.dispose);
        for (final stage
            in RequestStage.values.where((stage) => !stage.isTerminal)) {
          controller.activeRequest = order(stage);
          await mount(
              tester,
              Scaffold(
                  body: NewTrackingScreen(
                      key: ValueKey(stage),
                      controller: controller,
                      isActive: false,
                      photoRepository: photos.FakePhotos())),
              scale: 1.3);
          await scrollAll(tester);
        }
        controller.history = RequestStage.values.map(order).toList();
        await mount(
            tester, Scaffold(body: NewHistoryScreen(controller: controller)),
            scale: 1.3);
        await scrollAll(tester);
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'receipt, timeline and tappable review stars at $size / $textScale',
          (tester) async {
        viewport(tester);
        final controller = AppController();
        addTearDown(controller.dispose);
        await mount(
            tester,
            HistoryDetailsScreen(
              controller: controller,
              requestId: 'own-id',
              repository: details.DetailsFake(RequestDetails({
                'id': order(RequestStage.completed).id,
                'status': 'completed',
                'service_code': 'fuel',
                'vehicle_kind': 'truck',
                'location_text': longAddress,
                'latitude': 16.0544,
                'longitude': 108.2022,
                'quoted_price': 1250000,
              }, const [
                {'status': 'searching', 'occurred_at': '2026-10-01T00:00:00Z'},
                {'status': 'completed', 'occurred_at': '2026-10-01T02:00:00Z'},
              ])),
              photoRepository: photos.FakePhotos(),
              reviewRepository: reviews.ReviewsFake(),
            ));
        await scrollAll(tester);
        await scrollTo(tester, find.byTooltip('5 sao'));
        expect(tester.getSize(find.byTooltip('5 sao')).width,
            greaterThanOrEqualTo(48));
        await tester.tap(find.byTooltip('5 sao'));
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });

      testWidgets(
          'saved vehicles, addresses and profile editors at $size / $textScale',
          (tester) async {
        viewport(tester);
        final controller = AppController();
        addTearDown(controller.dispose);
        await mount(
            tester,
            CustomerVehiclesScreen(
                controller: controller,
                repository: vehicles.VehiclesFake()
                  ..vehicles = [vehicles.truck]));
        await tester.tap(find.text('Sửa xe'));
        await tester.pumpAndSettle();
        await scrollAll(tester);
        await tester.pumpWidget(const SizedBox.shrink());
        await mount(
            tester,
            CustomerSavedAddressesScreen(
                controller: controller,
                repository: addresses.AddressesFake()
                  ..addresses = [addresses.saved]));
        await tester.tap(find.text('Sửa địa chỉ'));
        await tester.pumpAndSettle();
        await scrollAll(tester);
        await tester.pumpWidget(const SizedBox.shrink());
        await mount(
            tester,
            Scaffold(
                body: SingleChildScrollView(
                    padding: AppSpacing.page,
                    child: CustomerProfileCard(
                        controller: controller,
                        repository: profile.ProfileFake()))));
        await tester.ensureVisible(find.text('Chỉnh sửa thông tin'));
        await tester.tap(find.text('Chỉnh sửa thông tin'));
        await tester.pump();
        tester.view.viewInsets = const FakeViewPadding(bottom: 300);
        await tester.pump();
        await tester.ensureVisible(find.text('Lưu thay đổi'));
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
