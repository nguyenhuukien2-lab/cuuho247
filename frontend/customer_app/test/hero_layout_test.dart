import 'dart:io';

import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/app/app_theme.dart';
import 'package:cuu_ho_247/app/user_session.dart';
import 'package:cuu_ho_247/screens/new_home_screen.dart';
import 'package:cuu_ho_247/services/location_service.dart';
import 'package:cuu_ho_247/widgets/booking_ui.dart';
import 'package:cuu_ho_247/widgets/home_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'request_photos_test.dart' as photos;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    // Ahem has square glyphs unlike the app font. Use the SDK's bundled Roboto
    // so line wrapping and clipping checks represent the shipped typography.
    final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
    final root = Platform.environment['FLUTTER_ROOT'];
    final candidates = [
      File('${artifacts.path}/material_fonts/roboto-regular.ttf'),
      if (root != null)
        File('$root/bin/cache/artifacts/material_fonts/roboto-regular.ttf'),
    ];
    final font = candidates.firstWhere((candidate) => candidate.existsSync());
    final loader = FontLoader('Roboto')
      ..addFont(Future.value(ByteData.sublistView(await font.readAsBytes())));
    await loader.load();
  });
  tearDown(UserSession.clear);

  testWidgets('supplied avatar is used only for a received request',
      (tester) async {
    final image = MemoryImage(photos.png());
    for (final stage in [RequestStage.searching, RequestStage.arriving]) {
      final request = RescueRequestData(
          id: 'real-request',
          requestCode: 'CH-000042',
          service: RescueService.tire,
          vehicle: VehicleKind.car,
          address: '',
          createdAt: DateTime(2026),
          stage: stage);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
              body: ActiveOrderBanner(
                  request: request,
                  onTrack: () {},
                  partnerName: 'Đối tác Minh',
                  partnerAvatar: image))));
      await tester.pumpAndSettle();
      final avatar = tester.widget<CircleAvatar>(find.byType(CircleAvatar));
      expect(avatar.foregroundImage,
          stage == RequestStage.searching ? isNull : same(image));
      expect(find.text('Đối tác Minh'),
          stage == RequestStage.searching ? findsNothing : findsOneWidget);
      expect(find.byKey(const ValueKey('home-active-eta')), findsNothing);
      expect(find.byKey(const ValueKey('home-active-distance')), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets('compact greeting spacing at $width / $scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final mode in ['gps', 'selected-gps', 'address', 'unknown']) {
          var refreshes = 0;
          await tester.pumpWidget(MaterialApp(
              theme: AppTheme.light,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!),
              home: Scaffold(
                  body: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: HomeGreetingLocation(
                          name: 'Tuấn Anh',
                          selectedAddress:
                              mode == 'unknown' ? null : 'Địa chỉ đã chọn',
                          selectedCoordinates: mode == 'selected-gps'
                              ? const RescueCoordinates(10.7, 106.7)
                              : null,
                          loading: false,
                          location: mode == 'gps'
                              ? const LocationResult(
                                  LocationStatus.acquired, '',
                                  coordinates: RescueCoordinates(10.7, 106.7))
                              : null,
                          onRefresh: () => refreshes++)))));
          final title = find.byKey(const ValueKey('home-greeting-title'));
          final address = find.byKey(const ValueKey('home-greeting-address'));
          final row = tester
              .getRect(find.byKey(const ValueKey('home-greeting-address-row')));
          final chip =
              find.byKey(const ValueKey('home-greeting-location-badge'));
          expect(find.text('Xin chào, Tuấn Anh'), findsOneWidget);
          expect(tester.widget<Text>(title).style!.fontSize, 18);
          expect(tester.widget<Text>(title).style!.fontWeight, FontWeight.w700);
          expect(tester.widget<Text>(title).style!.color, HomeVisual.ink);
          expect(tester.widget<Text>(title).maxLines, isNull);
          expect(tester.widget<Text>(title).overflow, isNull);
          expect(find.text('👋'), findsOneWidget);
          expect(tester.widget<Text>(address).style!.fontSize, 13);
          expect(
              tester.widget<Text>(address).style!.fontWeight, FontWeight.w600);
          expect(tester.widget<Text>(address).style!.color,
              mode == 'unknown' ? HomeVisual.muted : const Color(0xFF1F2937));
          expect(tester.widget<Text>(address).maxLines, isNull);
          expect(tester.widget<Text>(address).overflow, isNull);
          final refresh = find.byKey(const ValueKey('home-greeting-refresh'));
          final refreshButton = tester.widget<IconButton>(refresh);
          expect(refreshButton.tooltip, 'Làm mới vị trí');
          expect(
              refreshButton.style!.fixedSize!.resolve({}), const Size(40, 40));
          expect(refreshButton.style!.backgroundColor!.resolve({}),
              const Color(0xFFEAF2FF));
          expect(refreshButton.style!.foregroundColor!.resolve({}),
              HomeVisual.blue);
          expect(refreshButton.style!.shape!.resolve({}), isA<CircleBorder>());
          expect(
              tester.getRect(refresh).top,
              closeTo(
                  tester.getRect(find.byType(HomeGreetingLocation)).top, .01));
          expect(row.top - tester.getRect(title).bottom, closeTo(4, .01));
          expect(
              tester.getRect(chip).bottom,
              closeTo(tester.getRect(find.byType(HomeGreetingLocation)).bottom,
                  .01));
          expect(find.text('Chưa chọn vị trí'),
              mode == 'unknown' ? findsNWidgets(2) : findsNothing);
          expect(find.text('GPS sẵn sàng'),
              mode == 'gps' ? findsOneWidget : findsNothing);
          expect(
              find.text('Vị trí đã chọn'),
              mode == 'address' || mode == 'selected-gps'
                  ? findsOneWidget
                  : findsNothing);
          expect(find.text('Vị trí nhập tay'), findsNothing);
          expect(chip, findsOneWidget);
          expect(find.byKey(const ValueKey('home-greeting-status-row')),
              findsOneWidget);
          expect(tester.getSize(chip).height, inInclusiveRange(21, 22));
          expect(tester.getRect(chip).top - row.bottom, closeTo(5, .01));
          final gps = mode == 'gps';
          final decoration =
              tester.widget<Container>(chip).decoration as BoxDecoration;
          expect(
              decoration.color,
              gps
                  ? const Color(0xFFDCFCE7)
                  : mode == 'address' || mode == 'selected-gps'
                      ? const Color(0xFFDBEAFE)
                      : const Color(0xFFFEF3C7));
          final statusText = tester.widget<Text>(
              find.descendant(of: chip, matching: find.byType(Text)));
          expect(
              statusText.style!.color,
              gps
                  ? const Color(0xFF15803D)
                  : mode == 'address' || mode == 'selected-gps'
                      ? const Color(0xFF1D4ED8)
                      : const Color(0xFFB45309));
          expect(find.textContaining('Thời tiết'), findsNothing);
          await tester.tap(find.byTooltip('Làm mới vị trí'));
          expect(refreshes, 1);
          expect(tester.takeException(), isNull);
        }
      });

      testWidgets(
          'long greeting and address remain readable at $width / $scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const addressText =
            '75 Điện Biên Phủ, phường Đa Kao, quận 1, Thành phố Hồ Chí Minh';
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: Scaffold(
                body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: HomeGreetingLocation(
                        name: 'Nguyễn Hữu Kiên',
                        selectedAddress: addressText,
                        loading: false,
                        location: const LocationResult(
                            LocationStatus.acquired, '',
                            coordinates: RescueCoordinates(10.7, 106.7)),
                        onRefresh: () {})))));
        final title = find.byKey(const ValueKey('home-greeting-title'));
        final address = find.byKey(const ValueKey('home-greeting-address'));
        final refresh = find.byKey(const ValueKey('home-greeting-refresh'));
        final chip = find.byKey(const ValueKey('home-greeting-location-badge'));
        final titleParagraph = tester.renderObject<RenderParagraph>(title);
        final addressParagraph = tester.renderObject<RenderParagraph>(address);
        expect(find.text('Xin chào, Nguyễn Hữu Kiên'), findsOneWidget);
        expect(titleParagraph.maxLines, isNull);
        expect(titleParagraph.overflow, TextOverflow.clip);
        final wave = find.byKey(const ValueKey('home-greeting-wave'));
        expect(wave, findsOneWidget);
        expect(tester.getRect(title).right + 4,
            lessThanOrEqualTo(tester.getRect(wave).left + .01));
        expect(tester.getRect(wave).right,
            lessThanOrEqualTo(tester.getRect(refresh).left - 8));
        expect(find.text(addressText), findsOneWidget);
        expect(addressParagraph.maxLines, isNull);
        expect(addressParagraph.overflow, TextOverflow.clip);
        expect(addressParagraph.didExceedMaxLines, isFalse);
        expect(tester.getRect(address).right,
            lessThanOrEqualTo(tester.getRect(refresh).left - 8));
        expect(
            tester.getRect(chip).top -
                tester
                    .getRect(
                        find.byKey(const ValueKey('home-greeting-address-row')))
                    .bottom,
            closeTo(5, .01));
        expect(find.text('GPS sẵn sàng'), findsOneWidget);
        expect(find.text('Chưa chọn vị trí'), findsNothing);
        expect(find.textContaining('GPS chính xác'), findsNothing);
        expect(find.textContaining('Thời tiết'), findsNothing);
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('missing or invalid coordinates never claim GPS is ready',
      (tester) async {
    for (final result in [
      const LocationResult(LocationStatus.acquired, ''),
      const LocationResult(LocationStatus.acquired, '',
          coordinates: RescueCoordinates(91, 106.7)),
      const LocationResult(LocationStatus.denied, '',
          coordinates: RescueCoordinates(10.7, 106.7)),
    ]) {
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
              body: HomeGreetingLocation(
                  name: 'Khách hàng',
                  location: result,
                  selectedCoordinates: const RescueCoordinates(10.7, 181),
                  selectedAddress: 'Địa chỉ từ yêu cầu',
                  loading: false,
                  onRefresh: () {}))));
      expect(
          find.text(result.status == LocationStatus.denied
              ? 'Chưa cấp quyền vị trí'
              : 'Không thể lấy vị trí'),
          findsOneWidget);
      expect(find.text('GPS sẵn sàng'), findsNothing);
      expect(find.text('Chưa chọn vị trí'), findsNothing);
      expect(find.textContaining('chính xác'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'request coordinates are a selected address, never current device GPS',
      (tester) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    controller.activeRequest = RescueRequestData(
        id: '11111111-1111-4111-8111-111111111111',
        requestCode: 'CH-000042',
        service: RescueService.tire,
        vehicle: VehicleKind.car,
        address: '75 Điện Biên Phủ',
        latitude: 10.7,
        longitude: 106.7,
        createdAt: DateTime(2026),
        stage: RequestStage.searching);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: NewHomeScreen(controller: controller))));
    await tester.pumpAndSettle();
    final greeting = find.byType(HomeGreetingLocation);
    expect(
        find.descendant(of: greeting, matching: find.text('75 Điện Biên Phủ')),
        findsOneWidget);
    expect(find.descendant(of: greeting, matching: find.text('GPS sẵn sàng')),
        findsNothing);
    expect(find.descendant(of: greeting, matching: find.text('Vị trí đã chọn')),
        findsOneWidget);
    expect(find.textContaining('11111111-1111'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('location refresh stays disabled while acquiring GPS',
      (tester) async {
    var refreshes = 0;
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
            body: Padding(
                padding: const EdgeInsets.all(16),
                child: HomeGreetingLocation(
                    name: 'Tuấn Anh',
                    location: null,
                    loading: true,
                    onRefresh: () => refreshes++)))));
    final refresh = find.byKey(const ValueKey('home-greeting-refresh'));
    expect(tester.widget<IconButton>(refresh).onPressed, isNull);
    expect(find.text('Chưa chọn vị trí'), findsOneWidget);
    expect(find.text('Đang cập nhật vị trí'), findsOneWidget);
    expect(find.byKey(const ValueKey('home-greeting-location-badge')),
        findsOneWidget);
    expect(find.text('GPS sẵn sàng'), findsNothing);
    expect(
        tester
            .widget<CircularProgressIndicator>(
                find.byType(CircularProgressIndicator))
            .color,
        HomeVisual.blue);
    await tester.tap(refresh);
    expect(refreshes, 0);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 1.3, 1.5]) {
      testWidgets('active summary and inset tracking footer at $width / $scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final stage in [
          RequestStage.searching,
          RequestStage.accepted,
          RequestStage.arriving,
          RequestStage.inProgress
        ]) {
          var tracked = 0;
          final request = RescueRequestData(
              id: '11111111-1111-4111-8111-111111111111',
              requestCode: 'CH-000042',
              service: RescueService.fuel,
              vehicle: VehicleKind.truck,
              address: 'Địa chỉ từ đơn',
              createdAt: DateTime(2026, 10, 6, 9),
              updatedAt: DateTime(2026, 10, 6, 9, 10),
              stage: stage,
              contactName: 'Tên khách đặt đơn',
              contactPhone: '0901234567');
          await tester.pumpWidget(MaterialApp(
              theme: AppTheme.light,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!),
              home: Scaffold(
                  body: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: ActiveOrderBanner(
                          request: request, onTrack: () => tracked++)))));
          await tester.pumpAndSettle();
          final card = tester.getRect(find.byType(ActiveOrderBanner));
          final summary =
              tester.getRect(find.byKey(const ValueKey('home-active-summary')));
          final footer =
              tester.getRect(find.byKey(const ValueKey('home-active-footer')));
          final action = find.widgetWithText(FilledButton, 'Theo dõi →');
          final button = tester.getRect(action);
          final label = find.text('Tiếp nhiên liệu');
          expect(find.text('CH-000042 • Xe tải'), findsOneWidget);
          expect(find.textContaining('Mã đơn:'), findsNothing);
          expect(find.text('Cập nhật: 09:10'), findsOneWidget);
          expect(label, findsOneWidget);
          expect(tester.getSize(find.byKey(const ValueKey('home-active-icon'))),
              const Size(46, 46));
          expect(summary.bottom, lessThan(footer.top));
          expect(footer.contains(button.topLeft), isTrue);
          expect(footer.contains(button.bottomRight), isTrue);
          expect(footer.right - button.right, greaterThanOrEqualTo(8));
          expect(footer.bottom - button.bottom, greaterThanOrEqualTo(2));
          expect(card.right - footer.right, greaterThanOrEqualTo(12));
          expect(card.bottom - footer.bottom, greaterThanOrEqualTo(12));
          expect(footer.top - summary.bottom, closeTo(10, .01));
          if (scale == 1) {
            expect(card.height, inInclusiveRange(120, 132),
                reason:
                    'Summary ${summary.height}; footer ${footer.height}; button width ${button.width}');
            expect(summary.height, inInclusiveRange(54, 58));
            expect(footer.height, inInclusiveRange(40, 44));
            expect(button.height, inInclusiveRange(30, 34));
          }
          final texts = find.descendant(
              of: find.byKey(const ValueKey('home-active-footer')),
              matching: find.byType(Text));
          for (final text in texts.evaluate()) {
            if ((text.widget as Text).data != 'Theo dõi →') {
              expect(
                  tester.getRect(find.byWidget(text.widget)).overlaps(button),
                  isFalse);
            }
          }
          for (final paragraph in find
              .descendant(
                  of: find.byType(ActiveOrderBanner),
                  matching: find.byType(RichText))
              .evaluate()) {
            expect(
                (paragraph.renderObject! as RenderParagraph).didExceedMaxLines,
                isFalse);
          }
          final surface = tester.widget<Container>(
              find.byKey(const ValueKey('home-active-surface')));
          final decoration = surface.decoration as BoxDecoration;
          expect((decoration.gradient as LinearGradient).colors,
              [const Color(0xFFDCEEFF), const Color(0xFFDDFBEF)]);
          expect(decoration.borderRadius, BorderRadius.circular(20));
          expect(decoration.border, isNull);
          final shell = surface.child! as Column;
          expect(shell.children, hasLength(3));
          expect(
              shell.children.first.key, const ValueKey('home-active-summary'));
          expect((shell.children[1] as SizedBox).height, 10);
          expect(shell.children.last.key, const ValueKey('home-active-footer'));
          expect(
              find.descendant(
                  of: find.byKey(const ValueKey('home-active-main-content')),
                  matching: find.text('Cập nhật: 09:10')),
              findsNothing);
          expect(
              tester
                  .getRect(find.byKey(const ValueKey('home-active-meta')))
                  .left,
              greaterThan(tester
                  .getRect(
                      find.byKey(const ValueKey('home-active-main-content')))
                  .right));
          expect(decoration.boxShadow, isNotEmpty);
          expect(decoration.boxShadow!.single.blurRadius, 14);
          expect(decoration.boxShadow!.single.offset, const Offset(0, 6));
          expect(decoration.boxShadow!.single.color.a, closeTo(.08, .005));
          expect(find.text('ĐANG TÌM ĐỐI TÁC'),
              stage == RequestStage.searching ? findsOneWidget : findsNothing);
          expect(find.byType(Image), findsNothing);
          for (final forbidden in [
            'Tên khách đặt đơn',
            '0901234567',
            'ETA',
            'km',
            'phút',
            '11111111-1111',
            '�'
          ]) {
            expect(find.textContaining(forbidden), findsNothing);
          }
          expect(action.hitTestable(), findsOneWidget);
          await tester.tap(action);
          expect(tracked, 1);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
          'searching and assigned share card skeleton at $width / $scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 740);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        for (final stage in [
          RequestStage.searching,
          RequestStage.accepted,
          RequestStage.arriving
        ]) {
          for (final supplied in [false, true]) {
            var tracked = 0;
            final request = RescueRequestData(
                id: '11111111-1111-4111-8111-111111111111',
                requestCode: 'CH-000042',
                service: RescueService.tire,
                vehicle: VehicleKind.car,
                address: 'Địa chỉ từ đơn',
                createdAt: DateTime(2026, 10, 6),
                stage: stage);
            await tester.pumpWidget(MaterialApp(
                theme: AppTheme.light,
                builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!),
                home: Scaffold(
                    body: SingleChildScrollView(
                        padding: const EdgeInsets.all(16),
                        child: ActiveOrderBanner(
                            request: request,
                            onTrack: () => tracked++,
                            partnerName: supplied ? 'Đối tác Minh' : null,
                            etaMinutes: supplied ? 8 : null,
                            distanceKm: supplied ? 2.4 : null)))));
            await tester.pumpAndSettle();
            final assigned = stage != RequestStage.searching && supplied;
            final shell = tester
                .widget<Container>(
                    find.byKey(const ValueKey('home-active-surface')))
                .child! as Column;
            expect(shell.children, hasLength(3));
            expect(shell.children.first.key,
                const ValueKey('home-active-summary'));
            expect(
                shell.children.last.key, const ValueKey('home-active-footer'));
            expect(find.text('Đối tác Minh'),
                assigned ? findsOneWidget : findsNothing);
            expect(find.text('Vá / thay lốp'),
                assigned ? findsNothing : findsOneWidget);
            expect(find.text('CH-000042 • Ô tô'), findsOneWidget);
            expect(
                find.text('ĐANG TÌM ĐỐI TÁC'),
                stage == RequestStage.searching
                    ? findsOneWidget
                    : findsNothing);
            expect(find.text('ĐANG DI CHUYỂN'),
                stage == RequestStage.arriving ? findsOneWidget : findsNothing);
            expect(find.text('ĐÃ NHẬN YÊU CẦU'),
                stage == RequestStage.accepted ? findsOneWidget : findsNothing);
            expect(
                find.text('8 phút'), assigned ? findsOneWidget : findsNothing);
            expect(
                find.text('2.4 km'), assigned ? findsOneWidget : findsNothing);
            expect(find.byKey(const ValueKey('home-active-meta')),
                assigned ? findsOneWidget : findsNothing);
            expect(find.textContaining('Cập nhật'), findsNothing);
            final avatar =
                tester.widget<CircleAvatar>(find.byType(CircleAvatar));
            expect(avatar.backgroundImage, isNull);
            expect(find.byIcon(Icons.person_outline_rounded),
                assigned ? findsOneWidget : findsNothing);
            final action = find.widgetWithText(FilledButton, 'Theo dõi →');
            final footer = tester
                .getRect(find.byKey(const ValueKey('home-active-footer')));
            expect(footer.contains(tester.getCenter(action)), isTrue);
            expect(action.hitTestable(), findsOneWidget);
            for (final paragraph in find
                .descendant(
                    of: find.byType(ActiveOrderBanner),
                    matching: find.byType(RichText))
                .evaluate()) {
              expect(
                  (paragraph.renderObject! as RenderParagraph)
                      .didExceedMaxLines,
                  isFalse);
            }
            await tester.tap(action);
            expect(tracked, 1);
            expect(find.textContaining('11111111-1111'), findsNothing);
            expect(tester.takeException(), isNull);
          }
        }
      });
    }
  }

  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 1.3, 1.5]) {
      for (final active in [false, true]) {
        testWidgets('home with bottom nav at $width / $scale / active=$active',
            (tester) async {
          tester.view.physicalSize = Size(width, 740);
          tester.view.devicePixelRatio = 1;
          tester.view.padding = const FakeViewPadding(bottom: 24);
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          addTearDown(tester.view.resetPadding);
          UserSession.fullName = 'Tuấn Anh';
          final controller = AppController()..restoringSession = false;
          addTearDown(controller.dispose);
          if (active) {
            controller.activeRequest = RescueRequestData(
                id: '11111111-1111-4111-8111-111111111111',
                requestCode: 'CH-000042',
                service: RescueService.tire,
                vehicle: VehicleKind.car,
                address: 'Địa chỉ đã chọn',
                createdAt: DateTime(2026, 10, 6, 9),
                updatedAt: DateTime(2026, 10, 6, 9, 10),
                stage: RequestStage.searching);
          }
          await tester.pumpWidget(MaterialApp(
              theme: AppTheme.light,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!),
              home: Scaffold(
                  body: NewHomeScreen(controller: controller),
                  bottomNavigationBar:
                      CustomerBottomNav(controller: controller))));
          await tester.pumpAndSettle();
          expect(find.textContaining('Xin chào,'), findsOneWidget);
          expect(find.text('Chưa chọn vị trí'),
              active ? findsNothing : findsOneWidget);
          expect(find.text('Địa chỉ đã chọn'),
              active ? findsOneWidget : findsNothing);
          expect(find.text('Vị trí đã chọn'),
              active ? findsOneWidget : findsNothing);
          expect(find.text('GPS sẵn sàng'), findsNothing);
          final header = tester.getRect(find.byType(HomeAppHeader));
          if (scale == 1) expect(header.height, inInclusiveRange(56, 64));
          expect(
              tester.getCenter(find.byTooltip('Mở tài khoản')).dy,
              closeTo(
                  tester.getCenter(find.byTooltip('Tải lại yêu cầu')).dy, 1));

          final scrolling = find.byType(Scrollable).first;
          Future<void> reveal(Finder finder) async {
            await tester.scrollUntilVisible(finder, 100, scrollable: scrolling);
            await tester.pumpAndSettle();
            expect(finder.hitTestable(), findsOneWidget);
            expect(
                tester.getRect(finder).bottom,
                lessThanOrEqualTo(
                    tester.getRect(find.byType(CustomerBottomNav)).top));
            expect(tester.takeException(), isNull);
          }

          if (active) {
            final banner = find.byType(ActiveOrderBanner);
            expect(find.text('CH-000042 • Ô tô'), findsOneWidget);
            expect(find.text('Cập nhật: 09:10'), findsOneWidget);
            expect(find.textContaining('Hệ thống đang tìm đối tác phù hợp'),
                findsOneWidget);
            final card = tester.getRect(banner);
            final greeting = tester.getRect(find.byType(HomeGreetingLocation));
            expect(card.top - greeting.bottom, closeTo(12, .01));
            if (scale == 1) expect(card.height, inInclusiveRange(120, 132));
            final track = find.widgetWithText(FilledButton, 'Theo dõi →');
            await reveal(track);
            final button = tester.getRect(track);
            expect(card.right - button.right, greaterThanOrEqualTo(12));
            expect(card.bottom - button.bottom, greaterThanOrEqualTo(12));
            await tester.tap(track);
            expect(controller.tabIndex, 2);
          } else {
            expect(find.byType(ActiveOrderBanner), findsNothing);
          }
          final action = find.widgetWithText(FilledButton,
              active ? 'YÊU CẦU ĐANG XỬ LÝ' : 'YÊU CẦU CỨU HỘ NGAY');
          await reveal(action);
          expect(tester.widget<FilledButton>(action).onPressed == null, active);
          expect(find.text('Theo dõi đơn'), findsNothing);
          if (!active) {
            await tester.tap(action);
            expect(controller.tabIndex, 1);
          }
          for (final service in HomeServiceGrid.services) {
            final card = find.widgetWithText(ServiceCard, service.$1);
            await reveal(card);
            if (scale == 1) {
              expect(
                  find.descendant(
                      of: card,
                      matching: find.byWidgetPredicate((widget) =>
                          widget is Padding &&
                          widget.padding == const EdgeInsets.all(10))),
                  findsOneWidget);
            }
            final title =
                find.descendant(of: card, matching: find.text(service.$1));
            final paragraph =
                find.descendant(of: title, matching: find.byType(RichText));
            expect(
                (tester.renderObject(paragraph) as RenderParagraph)
                    .didExceedMaxLines,
                isFalse);
            final previousService = controller.selectedService;
            await tester.tap(card);
            expect(controller.tabIndex, 1);
            expect(controller.selectedService, service.$5 ?? previousService);
          }
          await reveal(find.text('Minh bạch thông tin'));
          await reveal(find.text('Thông tin yêu cầu rõ ràng'));
          await reveal(find.text('Theo dõi trạng thái đơn'));
          await reveal(find.text('Bật đèn cảnh báo'));
          await tester.dragFrom(tester.getCenter(find.text('Bật đèn cảnh báo')),
              const Offset(-600, 0));
          await tester.pumpAndSettle();
          expect(find.text('Giữ khoảng cách an toàn').hitTestable(),
              findsOneWidget);
          for (final forbidden in [
            '1900',
            'ETA',
            '142 xe',
            '99.8%',
            '10–15p',
            '₫',
            'Thời tiết',
            'Kỹ thuật viên',
            '�'
          ]) {
            expect(find.textContaining(forbidden), findsNothing);
          }
          expect(
              find.textContaining(RegExp(
                  r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
                  caseSensitive: false)),
              findsNothing);
          for (final tab in const [
            ('Trang chủ', 0),
            ('Theo dõi', 2),
            ('Đặt cứu hộ', 1),
            ('Lịch sử', 3),
            ('Tài khoản', 4)
          ]) {
            final label = find.descendant(
                of: find.byType(CustomerBottomNav),
                matching: find.text(tab.$1));
            expect(label.hitTestable(), findsOneWidget);
            await tester.tap(label);
            expect(controller.tabIndex, tab.$2);
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }

  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 1.3, 1.5]) {
      for (final active in [false, true]) {
        testWidgets(
            'hero has separate, unclipped sections at $width / $scale / active=$active',
            (tester) async {
          tester.view.physicalSize = Size(width, 740);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          var requested = 0;
          await tester.pumpWidget(MaterialApp(
              theme: AppTheme.light,
              builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!),
              home: Scaffold(
                  body: SingleChildScrollView(
                      padding: const EdgeInsets.all(16),
                      child: EmergencyHeroCard(
                          hasActiveRequest: active,
                          onRequest: () => requested++)))));
          await tester.pumpAndSettle();

          final hero =
              tester.getRect(find.byKey(const ValueKey('sos-hero-surface')));
          final badge =
              tester.getRect(find.byKey(const ValueKey('sos-hero-badge')));
          final header =
              tester.getRect(find.byKey(const ValueKey('sos-hero-header')));
          final title = tester.getRect(find.text('Bạn cần cứu hộ khẩn cấp?'));
          final subtitle =
              tester.getRect(find.byKey(const ValueKey('sos-hero-subtitle')));
          final action = find.widgetWithText(FilledButton,
              active ? 'YÊU CẦU ĐANG XỬ LÝ' : 'YÊU CẦU CỨU HỘ NGAY');
          final cta = tester.getRect(action);
          final row =
              tester.getRect(find.byKey(const ValueKey('sos-hero-trust-row')));
          expect(hero.height, greaterThanOrEqualTo(180));
          expect(title.top - header.bottom, closeTo(16, .01));
          expect(subtitle.top - title.bottom, closeTo(4, .01));
          expect(cta.top - subtitle.bottom, closeTo(20, .01));
          expect(row.top - cta.bottom, closeTo(16, .01));
          expect(hero.bottom - row.bottom, greaterThanOrEqualTo(16));
          if (scale == 1) expect(cta.height, equals(56));
          for (final block in [badge, header, title, subtitle, cta, row]) {
            expect(block.left, greaterThanOrEqualTo(hero.left + 16));
            expect(block.right, lessThanOrEqualTo(hero.right - 16));
            expect(block.top, greaterThanOrEqualTo(hero.top + 16));
            expect(block.bottom, lessThanOrEqualTo(hero.bottom - 16));
          }

          final content = find.byKey(const ValueKey('sos-hero-content'));
          for (final type in [Positioned, Transform, FittedBox]) {
            expect(find.descendant(of: content, matching: find.byType(type)),
                findsNothing);
          }
          for (final paragraph in find
              .descendant(of: content, matching: find.byType(RichText))
              .evaluate()) {
            expect(
                (paragraph.renderObject! as RenderParagraph).didExceedMaxLines,
                isFalse,
                reason: 'Hero text was clipped at $width / $scale');
          }
          final tiles = ['Gửi yêu cầu', 'Xem báo giá', 'Theo dõi trạng thái']
              .map((text) =>
                  tester.getRect(find.byKey(ValueKey('hero-trust-$text'))))
              .toList();
          for (final tile in tiles) {
            expect(tile.width, closeTo(tiles.first.width, .01));
            expect(tile.height, closeTo(tiles.first.height, .01));
            expect(tile.top, closeTo(row.top, .01));
            expect(tile.height, greaterThanOrEqualTo(44));
            expect(tile.overlaps(cta), isFalse);
          }
          for (var i = 1; i < tiles.length; i++) {
            expect(tiles[i].left - tiles[i - 1].right, closeTo(4, .01));
          }
          final button = tester.widget<FilledButton>(action);
          expect(button.onPressed == null, active);
          if (!active) {
            expect(action.hitTestable(), findsOneWidget);
            await tester.tap(action);
            expect(requested, 1);
          } else {
            expect(requested, 0);
          }
          expect(find.text('Theo dõi đơn'), findsNothing);
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
