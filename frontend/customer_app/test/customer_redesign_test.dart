import 'customer_vehicles_test.dart' as accountVehicles;
import 'customer_saved_addresses_test.dart' as accountAddresses;
import 'package:cuu_ho_247/widgets/booking_ui.dart';
import 'request_steps.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/app/app_shell.dart';
import 'package:cuu_ho_247/app/app_theme.dart';
import 'package:cuu_ho_247/app/user_session.dart';
import 'package:cuu_ho_247/screens/new_account_screen.dart';
import 'package:cuu_ho_247/screens/new_auth_screen.dart';
import 'package:cuu_ho_247/screens/new_history_screen.dart';
import 'package:cuu_ho_247/screens/new_request_screen.dart';
import 'package:cuu_ho_247/screens/new_tracking_screen.dart';
import 'package:cuu_ho_247/widgets/customer_ui.dart';
import 'package:cuu_ho_247/widgets/rescue_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';

import 'customer_profile_card_test.dart' as profile;
import 'mobile_ui_test.dart' as mobile;
import 'request_location_test.dart' as location;
import 'request_photos_test.dart' as photos;

const captureUi = bool.fromEnvironment('CAPTURE_CUSTOMER_UI');

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!captureUi) return;
  await tester.pumpAndSettle();
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/ui_review');
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

void main() {
  setUp(() {
    UserSession.userId = 'owner';
    UserSession.fullName = '  nGUYỄN   mINH aNH  ';
  });
  tearDown(UserSession.clear);

  test('display name normalization affects presentation only', () {
    expect(displayCustomerName(UserSession.fullName), 'Nguyễn Minh Anh');
    expect(UserSession.fullName, '  nGUYỄN   mINH aNH  ');
    expect(displayCustomerName(null), '');
  });

  test('brand palette and principal text meet readable contrast', () {
    expect(AppColors.navy, const Color(0xFF0B2540));
    expect(AppColors.orange, const Color(0xFFC2410C));
    for (final pair in [
      (Colors.white, AppColors.orange),
      (Colors.white, AppColors.orangePressed),
      (Colors.white, AppColors.navy),
      (AppColors.muted, AppColors.background),
      (AppColors.text, AppColors.surface),
    ]) {
      final a = pair.$1.computeLuminance(), b = pair.$2.computeLuminance();
      final light = a > b ? a : b, dark = a > b ? b : a;
      expect((light + .05) / (dark + .05), greaterThanOrEqualTo(4.5));
    }
  });

  test('optional contact and update time come from response data', () {
    final row = <String, dynamic>{
      'id': 'request',
      'service_code': 'tire',
      'vehicle_kind': 'car',
      'location_text': 'Địa chỉ',
      'created_at': '2026-10-01T00:00:00Z',
      'status': 'searching',
    };
    final missing = RescueRequestData.fromJson(row);
    expect(missing.hasServerUpdateTime, isFalse);
    expect(missing.updatedAt, missing.createdAt);
    expect(missing.contactName, isEmpty);
    final supplied = RescueRequestData.fromJson({
      ...row,
      'updated_at': '2026-10-01T01:00:00Z',
      'contact_name': 'Tên thật từ phản hồi',
      'contact_phone': '0901234567'
    });
    expect(supplied.hasServerUpdateTime, isTrue);
    expect(supplied.contactName, 'Tên thật từ phản hồi');
    expect(supplied.contactPhone, '0901234567');
  });

  for (final size in [const Size(360, 800), const Size(390, 844)]) {
    Future<void> mount(WidgetTester tester, Widget screen,
        {double scale = 1.3,
        bool reduceMotion = false,
        GlobalKey? captureKey}) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(top: 28, bottom: 20);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      addTearDown(tester.view.resetViewInsets);
      if (captureUi) {
        await tester.runAsync(() async {
          final root = Platform.environment['FLUTTER_ROOT'];
          final fontDirectory = root ?? 'C:/Users/ADMIN/development/flutter';
          final font = File(
              '$fontDirectory/bin/cache/artifacts/material_fonts/roboto-regular.ttf');
          if (await font.exists()) {
            final loader = FontLoader('Roboto')
              ..addFont(
                  Future.value(ByteData.sublistView(await font.readAsBytes())));
            await loader.load();
          }
          final icons = File(
              '$fontDirectory/bin/cache/artifacts/material_fonts/materialicons-regular.otf');
          if (await icons.exists()) {
            final loader = FontLoader('MaterialIcons')
              ..addFont(Future.value(
                  ByteData.sublistView(await icons.readAsBytes())));
            await loader.load();
          }
        });
      }
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(scale),
                  disableAnimations: reduceMotion),
              child: RepaintBoundary(key: captureKey, child: child!)),
          home: screen));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }

    testWidgets(
        'nav labels, selected tiles, safe areas and reduce motion at $size',
        (tester) async {
      final controller = AppController()..restoringSession = false;
      addTearDown(controller.dispose);
      final key = GlobalKey();
      await mount(tester, AppShell(controller: controller),
          reduceMotion: true, captureKey: key);
      expect(find.text('Xin chào, Nguyễn Minh Anh'), findsOneWidget);
      expect(find.byType(CustomerBottomNav), findsOneWidget);
      expect(tester.getSize(find.byType(CustomerBottomNav)).height,
          lessThanOrEqualTo(size.height * .22));
      for (final label in [
        'Trang chủ',
        'Đặt cứu hộ',
        'Theo dõi',
        'Lịch sử',
        'Tài khoản'
      ]) {
        final paragraph =
            tester.renderObject<RenderParagraph>(find.text(label));
        expect(paragraph.didExceedMaxLines, isFalse,
            reason: '$label was truncated');
      }
      expect(
          tester
              .getSize(find.widgetWithText(FilledButton, 'YÊU CẦU CỨU HỘ NGAY'))
              .height,
          greaterThanOrEqualTo(52));
      await capture(tester, key, 'home-${size.width.toInt()}-large');
      await tapRequest(tester, find.text('Đặt cứu hộ'));
      await tester.pump();
      final fade = tester.widget<FadeTransition>(find
          .ancestor(
              of: find.byType(IndexedStack),
              matching: find.byType(FadeTransition))
          .first);
      expect(fade.opacity.value, 1);
      await tapRequest(tester, find.text('Vá lốp'));
      await tester.pump();
      expect(controller.selectedService, RescueService.tire);
      final tile =
          tester.widget<ChoiceTile>(find.widgetWithText(ChoiceTile, 'Vá lốp'));
      expect(tile.selected, isTrue);
      expect(tester.getSize(find.widgetWithText(ChoiceTile, 'Vá lốp')).height,
          greaterThanOrEqualTo(48));
      await capture(tester, key, 'request-${size.width.toInt()}-large');
      if (captureUi) {
        await requestStep(tester, 1);
        await capture(
            tester, key, 'booking-vehicle-${size.width.toInt()}-large');
      }
    });

    testWidgets(
        'sticky CTA validates offscreen contacts and preserves draft at $size',
        (tester) async {
      UserSession.fullName = null;
      UserSession.phoneNumber = null;
      final controller = location.CapturingController()
        ..selectedService = RescueService.tire;
      addTearDown(controller.dispose);
      final key = GlobalKey();
      await mount(
          tester, Scaffold(body: NewRequestScreen(controller: controller)),
          captureKey: key);
      final scroll = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!;
      await requestStep(tester, 2);
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      final address = find.widgetWithText(TextFormField, 'Địa chỉ');
      await revealRequest(tester, address);
      await enterRequest(tester, address, mobile.longAddress);
      tester.testTextInput.hide();
      scroll.jumpTo(0);
      await tester.pumpAndSettle();
      await tapRequest(tester, find.text('XÁC NHẬN ĐẶT CỨU HỘ'));
      await tester.pumpAndSettle();
      expect(controller.submissions, isEmpty);
      await capture(tester, key, 'contact-error-${size.width.toInt()}-large');
      expect(find.text('Vui lòng nhập họ tên'), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      final button = find.widgetWithText(FilledButton, 'XÁC NHẬN ĐẶT CỨU HỘ');
      expect(
          tester.getRect(button).bottom, lessThanOrEqualTo(size.height - 300));
      expect(tester.takeException(), isNull);
    });

    testWidgets('vertical drag on map scrolls page at $size', (tester) async {
      final controller = AppController()..selectedService = RescueService.tire;
      addTearDown(controller.dispose);
      await mount(
          tester, Scaffold(body: NewRequestScreen(controller: controller)));
      final scroll = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!;
      await requestStep(tester, 2);
      for (var i = 0;
          i < 12 && find.byType(FlutterMap).evaluate().isEmpty;
          i++) {
        scroll.jumpTo(scroll.position.pixels + 160);
        await tester.pumpAndSettle();
      }
      await revealRequest(tester, find.byType(FlutterMap));
      await tester.pumpAndSettle();
      final before = scroll.offset;
      await tester.drag(find.byType(FlutterMap), const Offset(0, 160));
      await tester.pumpAndSettle();
      expect(scroll.offset, lessThan(before));
    });

    testWidgets('history filters and account editor keep real values at $size',
        (tester) async {
      final controller = AppController()
        ..history = [
          mobile.order(RequestStage.completed),
          mobile.order(RequestStage.cancelled)
        ];
      addTearDown(controller.dispose);
      final key = GlobalKey();
      await mount(
          tester, Scaffold(body: NewHistoryScreen(controller: controller)),
          captureKey: key);
      expect(
          tester.widget<Text>(find.byKey(const ValueKey('history-total'))).data,
          '2');
      expect(find.text('Tiếp nhiên liệu'), findsAtLeastNWidgets(1));
      await tapRequest(tester, find.text('Hoàn tất').first);
      await tester.pumpAndSettle();
      expect(find.text('Tiếp nhiên liệu'), findsOneWidget);
      expect(find.text(mobile.longAddress),
          findsOneWidget); // The trip card now shows the actual location.
      tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position
          .jumpTo(0);
      await tester.pumpAndSettle();
      await capture(tester, key, 'history-${size.width.toInt()}-large');
      await mount(
          tester,
          Scaffold(
              body: NewAccountScreen(
                  controller: controller,
                  profileRepository: profile.ProfileFake(),
                  vehicleRepository: accountVehicles.VehiclesFake()
                    ..vehicles = [accountVehicles.truck],
                  addressRepository: accountAddresses.AddressesFake()
                    ..addresses = [accountAddresses.saved])),
          captureKey: key);
      expect(find.text(profile.original.phone!), findsOneWidget);
      expect(find.text(profile.original.email!), findsOneWidget);
      await capture(tester, key, 'account-${size.width.toInt()}-large');
      await tapRequest(tester, find.text('Chỉnh sửa thông tin'));
      await tester.pumpAndSettle();
      expect(find.byType(AppBar), findsOneWidget);
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await revealRequest(tester, find.text('Lưu thay đổi'));
      await tester.pumpAndSettle();
      expect(tester.getRect(find.text('Lưu thay đổi')).bottom,
          lessThanOrEqualTo(size.height - 300));
      await capture(
          tester, key, 'profile-editor-${size.width.toInt()}-keyboard');
      expect(tester.takeException(), isNull);
    });

    testWidgets('tracking and auth have no made up content at $size',
        (tester) async {
      final controller = AppController()
        ..activeRequest = mobile.order(RequestStage.arriving);
      addTearDown(controller.dispose);
      final key = GlobalKey();
      await mount(
          tester,
          Scaffold(
              body: NewTrackingScreen(
                  controller: controller,
                  isActive: false,
                  photoRepository: photos.FakePhotos())),
          captureKey: key);
      expect(find.text('Kỹ thuật viên đang di chuyển đến'), findsOneWidget);
      expect(find.textContaining(RegExp(r'^Cập nhật \d')), findsNothing);
      expect(find.textContaining('ETA'), findsNothing);
      await capture(tester, key, 'tracking-${size.width.toInt()}-large');
      await mount(tester, NewAuthScreen(controller: controller),
          captureKey: key);
      await capture(tester, key, 'auth-${size.width.toInt()}-large');
      await tapRequest(tester, find.text('Đăng ký').first);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextFormField, 'Họ và tên'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
