import 'dart:io';
import 'dart:ui' as ui;

import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/app/app_theme.dart';
import 'package:cuu_ho_247/screens/new_history_screen.dart';
import 'package:cuu_ho_247/services/customer_request_review_service.dart';
import 'package:cuu_ho_247/services/customer_vehicle_service.dart';
import 'package:cuu_ho_247/widgets/booking_ui.dart';
import 'package:cuu_ho_247/widgets/history_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const requestId = '550e8400-e29b-41d4-a716-446655440000';
const vehicleId = '550e8400-e29b-41d4-a716-446655440001';
const longAddress =
    '123 đường Nguyễn Văn Linh, phường Hòa Cường Bắc, thành phố Đà Nẵng, gần cửa hàng tiện lợi';

RescueRequestData fixture(RequestStage stage,
        {String? code = 'CH-000042',
        String address = longAddress,
        int? price,
        String? savedVehicleId}) =>
    RescueRequestData(
        id: requestId,
        requestCode: code,
        service: RescueService.fuel,
        vehicle: VehicleKind.truck,
        vehicleId: savedVehicleId,
        address: address,
        createdAt: DateTime(2026, 10, 7, 9, 15),
        stage: stage,
        price: price);

const savedVehicle = CustomerVehicle(
    id: vehicleId,
    customerId: 'owner',
    kind: VehicleKind.truck,
    brandModel: 'Tên xe trong fixture kiểm thử',
    licensePlate: '43C-123.45');

CustomerRequestReview review({String id = requestId}) => CustomerRequestReview(
    id: 'review',
    requestId: id,
    customerId: 'owner',
    rating: 4,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026));

void noInventedData() {
  expect(
      find.textContaining(RegExp(
          r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
          caseSensitive: false)),
      findsNothing);
  for (final text in [
    '100%',
    '48 giờ',
    '1900',
    'Hotline',
    'bảo hiểm',
    'VAT',
    'Hóa đơn',
    'garage',
    'Thời gian trung bình',
    'Rating trung bình',
  ]) {
    expect(find.textContaining(text), findsNothing);
  }
}

Future<void> mount(WidgetTester tester, Widget child) =>
    tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: SingleChildScrollView(child: child))));

Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
  if (!const bool.fromEnvironment('CAPTURE_HISTORY_UI')) return;
  final boundary =
      key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final bitmap = await boundary.toImage(pixelRatio: 2);
    final bytes = await bitmap.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/history_review');
    await directory.create(recursive: true);
    await File('${directory.path}/$name.png')
        .writeAsBytes(bytes!.buffer.asUint8List());
    bitmap.dispose();
  });
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
    final icons = File('${font.parent.path}/materialicons-regular.otf');
    await (FontLoader('MaterialIcons')
          ..addFont(
              Future.value(ByteData.sublistView(await icons.readAsBytes()))))
        .load();
  });

  testWidgets('hero contains exactly the two supplied loaded-history metrics',
      (tester) async {
    await mount(tester, const HistorySummaryCard(count: 12, completedCount: 8));
    expect(find.text('NHẬT KÝ CỨU HỘ'), findsOneWidget);
    expect(find.text('Tổng số chuyến'), findsOneWidget);
    expect(find.text('Chuyến hoàn tất'), findsOneWidget);
    expect(find.text('12'), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.text('Thống kê từ các chuyến đã tải'), findsOneWidget);
    final hero =
        tester.widget<Container>(find.byKey(const ValueKey('history-hero')));
    final decoration = hero.decoration! as BoxDecoration;
    expect((decoration.gradient! as LinearGradient).colors,
        [const Color(0xFF0037B0), const Color(0xFF1D4ED8)]);
    expect(decoration.borderRadius, BorderRadius.circular(24));
    noInventedData();
    await mount(
        tester, const HistorySummaryCard(count: null, completedCount: null));
    expect(find.byKey(const ValueKey('history-total')), findsNothing);
    expect(find.byKey(const ValueKey('history-completed-total')), findsNothing);
    expect(find.text('0'), findsNothing);
    expect(find.text('Chưa tải được số chuyến'), findsOneWidget);
  });

  for (final entry in [
    (
      RequestStage.completed,
      'Hoàn tất',
      const Color(0xFFDCFCE7),
      const Color(0xFF15803D)
    ),
    (
      RequestStage.cancelled,
      'Đã hủy',
      const Color(0xFFFFDAD6),
      const Color(0xFFB91C1C)
    ),
    (
      RequestStage.inProgress,
      'Đang hỗ trợ',
      const Color(0xFFFFF1E8),
      const Color(0xFF1D4ED8)
    ),
  ]) {
    testWidgets('${entry.$1} has the specified status colors', (tester) async {
      await mount(tester, HistoryStatusBadge(stage: entry.$1));
      final badge = tester.widget<Container>(find.byType(Container));
      expect((badge.decoration! as BoxDecoration).color, entry.$3);
      expect(tester.widget<Text>(find.text(entry.$2)).style!.color, entry.$4);
    });
  }

  testWidgets('card shows supplied kind/location/cost and a working detail CTA',
      (tester) async {
    var opened = 0;
    await mount(
        tester,
        HistoryTripCard(
            request: fixture(RequestStage.completed, price: 1250000),
            onDetails: () => opened++));
    expect(find.text('Mã đơn: CH-000042'), findsOneWidget);
    expect(find.text('07/10/2026 • 09:15'), findsOneWidget);
    expect(find.text('Xe tải'), findsOneWidget);
    expect(find.text(longAddress), findsOneWidget);
    expect(tester.widget<Text>(find.text(longAddress)).maxLines, isNull);
    expect(find.text('Chi phí dịch vụ'), findsOneWidget);
    expect(find.text('1.250.000đ'), findsOneWidget);
    expect(find.text('Đánh giá'), findsNothing); // Review state is unknown.
    await tester.tap(find.text('Xem chi tiết'));
    expect(opened, 1);
    noInventedData();
    expect(tester.takeException(), isNull);
  });

  testWidgets('missing location/quote/saved vehicle adds no invented fields',
      (tester) async {
    for (final price in <int?>[null, 0]) {
      await mount(
          tester,
          HistoryTripCard(
              request:
                  fixture(RequestStage.cancelled, address: ' ', price: price),
              onDetails: () {}));
      expect(find.byKey(const ValueKey('history-location')), findsNothing);
      expect(find.textContaining('Biển số'), findsNothing);
      expect(find.text('Tên xe trong fixture kiểm thử'), findsNothing);
      expect(find.text('Xe tải'), findsOneWidget); // Required, real kind only.
      expect(find.text('Chi phí dịch vụ'),
          price == null ? findsNothing : findsOneWidget);
      expect(find.text('0đ'), price == null ? findsNothing : findsOneWidget);
      noInventedData();
    }
    await mount(tester, const HistoryVehicleStrip());
    expect(find.byKey(const ValueKey('history-vehicle')), findsNothing);
    await mount(
        tester,
        const HistoryVehicleStrip(
            vehicle: CustomerVehicle(
                id: vehicleId,
                customerId: 'owner',
                kind: VehicleKind.truck,
                brandModel: vehicleId,
                licensePlate: vehicleId)));
    expect(find.text('Xe tải'), findsOneWidget);
    expect(find.textContaining('Biển số'), findsNothing);
    noInventedData();
  });

  testWidgets('saved vehicle metadata is shown only for the matching request',
      (tester) async {
    for (final id in <String?>[null, vehicleId]) {
      await mount(
          tester,
          HistoryTripCard(
              request: fixture(RequestStage.completed, savedVehicleId: id),
              vehicleDetails: savedVehicle,
              onDetails: () {}));
      expect(find.text('Tên xe trong fixture kiểm thử'),
          id == null ? findsNothing : findsOneWidget);
      expect(find.text('Xe tải • Biển số: 43C-123.45'),
          id == null ? findsNothing : findsOneWidget);
      noInventedData();
    }
  });

  testWidgets('missing/UUID codes never fall back to internal identifiers',
      (tester) async {
    for (final code in <String?>[null, '', requestId, 'DT-000042']) {
      await mount(
          tester,
          HistoryTripCard(
              request: fixture(RequestStage.completed, code: code),
              onDetails: () {}));
      expect(find.text('Chưa có mã'), findsOneWidget);
      noInventedData();
    }
  });

  testWidgets(
      'review chip requires an actual review for this completed request',
      (tester) async {
    for (final stage in [RequestStage.completed, RequestStage.cancelled]) {
      for (final result in <CustomerRequestReview?>[
        null,
        review(),
        review(id: 'other')
      ]) {
        await mount(
            tester,
            HistoryTripCard(
                request: fixture(stage), review: result, onDetails: () {}));
        expect(
            find.text('Đã đánh giá 4★'),
            stage == RequestStage.completed && result?.requestId == requestId
                ? findsOneWidget
                : findsNothing);
        expect(find.text('Đánh giá'), findsNothing);
        noInventedData();
      }
    }
    var opened = 0;
    await mount(
        tester,
        HistoryTripCard(
            request: fixture(RequestStage.completed),
            onDetails: () {},
            onReview: () => opened++));
    await tester.tap(find.text('Đánh giá'));
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 1.3, 1.5]) {
      testWidgets('history hierarchy/filter/empty state fits $width / $scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final controller = AppController()
          ..tabIndex = 3
          ..history = [
            fixture(RequestStage.completed, price: 1250000),
            fixture(RequestStage.cancelled)
          ];
        addTearDown(controller.dispose);
        final key = GlobalKey();
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: RepaintBoundary(
                key: key,
                child: Scaffold(
                    body: NewHistoryScreen(controller: controller),
                    bottomNavigationBar:
                        CustomerBottomNav(controller: controller)))));
        await tester.pumpAndSettle();
        expect(find.text('NHẬT KÝ CỨU HỘ'), findsOneWidget);
        expect(
            tester
                .widget<Text>(find.byKey(const ValueKey('history-total')))
                .data,
            '2');
        expect(
            tester
                .widget<Text>(
                    find.byKey(const ValueKey('history-completed-total')))
                .data,
            '1');
        final scrollable = find
            .descendant(
                of: find.byKey(const PageStorageKey('history-scroll')),
                matching: find.byType(Scrollable))
            .first;
        for (var filter = 0; filter < 3; filter++) {
          tester.state<ScrollableState>(scrollable).position.jumpTo(0);
          await tester.pumpAndSettle();
          await tester.tap(find.byKey(ValueKey('history-filter-$filter')));
          await tester.pumpAndSettle();
          final selected = tester.widget<TextButton>(
              find.byKey(ValueKey('history-filter-$filter')));
          expect(selected.style!.backgroundColor!.resolve({}),
              HistoryStyle.darkBlue);
          final card = find.byType(HistoryTripCard).first;
          await tester.scrollUntilVisible(card, 150, scrollable: scrollable);
          await tester.ensureVisible(
              find.descendant(of: card, matching: find.text('Xem chi tiết')));
          await tester.pumpAndSettle();
          expect(tester.getRect(card).left, 20);
          expect(tester.getRect(card).right, width - 20);
          final stage = tester.widget<HistoryTripCard>(card).request.stage;
          expect(stage,
              filter == 2 ? RequestStage.cancelled : RequestStage.completed);
          noInventedData();
          expect(tester.takeException(), isNull);
        }
        await tester.tap(find.byTooltip('Mở tài khoản'));
        expect(controller.tabIndex, 4);
        controller.tabIndex = 3;
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
        // Capture the default loaded list with the shared navigation.
        tester.state<ScrollableState>(scrollable).position.jumpTo(0);
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('history-filter-0')));
        await tester.pumpAndSettle();
        tester.state<ScrollableState>(scrollable).position.jumpTo(0);
        await tester.pumpAndSettle();
        await capture(tester, key, 'history-${width.toInt()}-$scale');

        controller.history = [];
        await tester.tap(find.byKey(const ValueKey('history-filter-1')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('history-filter-0')));
        await tester.pumpAndSettle();
        expect(find.text('Chưa có chuyến cứu hộ'), findsOneWidget);
        expect(find.byType(HistoryTripCard), findsNothing);
        final action = find.widgetWithText(FilledButton, 'Đặt cứu hộ');
        await tester.ensureVisible(action);
        await tester.pumpAndSettle();
        await tester.tap(action);
        expect(controller.tabIndex, 1);
        noInventedData();
        expect(tester.takeException(), isNull);
      });
    }
  }
}
