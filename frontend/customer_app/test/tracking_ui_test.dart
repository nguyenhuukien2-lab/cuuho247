import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/app/app_theme.dart';
import 'package:cuu_ho_247/app/mobile_ui.dart';
import 'package:cuu_ho_247/app/user_session.dart';
import 'package:cuu_ho_247/screens/new_tracking_screen.dart';
import 'package:cuu_ho_247/widgets/tracking_ui.dart';
import 'package:cuu_ho_247/widgets/request_location_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';

import 'request_photos_test.dart' as photos;

const requestUuid = '550e8400-e29b-41d4-a716-446655440000';

RescueRequestData fixture(RequestStage stage,
        {int? price,
        String? requestCode = 'CH-000042',
        String? quoteCode,
        DateTime? updatedAt,
        double? latitude,
        double? longitude}) =>
    RescueRequestData(
      id: requestUuid,
      requestCode: requestCode,
      quoteCode: quoteCode,
      service: RescueService.towing,
      vehicle: VehicleKind.car,
      address: 'Địa chỉ từ đơn',
      createdAt: DateTime(2026, 10, 4, 7, 9),
      stage: stage,
      price: price,
      updatedAt: updatedAt,
      latitude: latitude,
      longitude: longitude,
    );

void expectNoInventedTrackingData() {
  expect(
      find.textContaining(RegExp(
          r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
          caseSensitive: false)),
      findsNothing);
  for (final text in [
    'Trực tiếp',
    'Đang cập nhật',
    'Chưa có dữ liệu',
    'Kỹ thuật viên',
    'Vị trí đối tác',
    'Gọi điện ngay',
    'Nhắn tin',
  ]) {
    expect(find.textContaining(text), findsNothing);
  }
  expect(
      find.textContaining(RegExp(r'\bETA\b|\b\d+(?:[.,]\d+)?\s*(?:km|phút)\b',
          caseSensitive: false)),
      findsNothing);
  for (final sample in ['03:44', '1.2', '38', 'Đã xác thực']) {
    expect(find.text(sample), findsNothing);
  }
}

class RefreshTrackingController extends AppController {
  int refreshes = 0;
  @override
  Future<void> refreshRequests() async {
    refreshes++;
  }
}

void main() {
  tearDown(UserSession.clear);

  for (final stage in RequestStage.values) {
    testWidgets(
        'vertical timeline reflects $stage without invented event times',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
              body: SingleChildScrollView(
                  child: TrackingTimeline(request: fixture(stage))))));
      final steps =
          tester.widgetList<TimelineStep>(find.byType(TimelineStep)).toList();
      expect(steps, hasLength(6));
      expect(steps.where((step) => step.done).length,
          [1, 2, 3, 4, 6, 1][stage.index]);
      expect(
          steps.where((step) => step.current).length, stage.isTerminal ? 0 : 1);
      expect(steps.first.time, '07:09');
      expect(steps.skip(1).every((step) => step.time == null), isTrue);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets(
      'quote renders response amount including zero and missing-data copy',
      (tester) async {
    for (final value in <int?>[null, 0, 123456]) {
      await tester.pumpWidget(
          MaterialApp(home: Scaffold(body: QuoteStatusCard(price: value))));
      if (value == null) {
        expect(find.text('Đối tác sẽ gửi báo giá sau khi kiểm tra.'),
            findsOneWidget);
        expect(find.text('Tổng báo giá'), findsNothing);
      } else {
        expect(find.text(value == 0 ? '0đ' : '123.456đ'), findsOneWidget);
        expect(find.text('Tổng báo giá'), findsOneWidget);
      }
      expect(find.text('Đã chốt giá'), findsNothing);
      expect(find.textContaining('VAT'), findsNothing);
    }
  });

  testWidgets(
      'status displays CH code, clear stage badge and honest update state',
      (tester) async {
    const expectedCopy = {
      RequestStage.searching: ('Đang chờ đối tác nhận đơn', 'Chờ nhận đơn'),
      RequestStage.accepted: ('Đối tác đã tiếp nhận yêu cầu', 'Đã nhận'),
      RequestStage.arriving: ('Đối tác đang di chuyển đến', 'Đang đến'),
      RequestStage.inProgress: ('Đối tác đang hỗ trợ', 'Đang hỗ trợ'),
      RequestStage.completed: ('Yêu cầu đã hoàn tất', 'Hoàn tất'),
      RequestStage.cancelled: ('Yêu cầu đã hủy', 'Đã hủy'),
    };
    for (final stage in RequestStage.values) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: TrackingStatusCard(request: fixture(stage))))));
      await tester.pumpAndSettle();
      expect(find.text('Mã đơn: CH-000042'), findsOneWidget);
      final (headline, badge) = expectedCopy[stage]!;
      expect(find.text(headline), findsOneWidget);
      expect(
          find.descendant(
              of: find.byType(RescueStatusBadge), matching: find.text(badge)),
          findsOneWidget);
      expect(find.text('Cập nhật gần nhất'), findsOneWidget);
      expect(
          find.text('Chưa có thời gian cập nhật trạng thái.'), findsOneWidget);
      expectNoInventedTrackingData();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'latest update uses server time and never substitutes creation time',
      (tester) async {
    for (final updatedAt in <DateTime?>[null, DateTime(2026, 10, 4, 8, 17)]) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: TrackingStatusCard(
                  request:
                      fixture(RequestStage.arriving, updatedAt: updatedAt)))));
      if (updatedAt == null) {
        expect(find.text('Chưa có thời gian cập nhật trạng thái.'),
            findsOneWidget);
        expect(find.textContaining('07:09'), findsNothing);
        expect(find.textContaining('08:17'), findsNothing);
      } else {
        expect(find.text('04/10/2026 • 08:17'), findsOneWidget);
        expect(
            find.text('Chưa có thời gian cập nhật trạng thái.'), findsNothing);
        expect(find.textContaining('07:09'), findsNothing);
      }
      expectNoInventedTrackingData();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets(
      'order summary shows real codes and quote without inventing a partner',
      (tester) async {
    for (final price in <int?>[null, 0, 123456]) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: TrackingOrderCard(
                      request: fixture(RequestStage.searching,
                          price: price,
                          quoteCode: price == null ? null : 'BG-000018'))))));
      expect(find.text('CH-000042'), findsOneWidget);
      expect(find.text('Kéo xe'), findsOneWidget);
      expect(find.text('Ô tô'), findsOneWidget);
      expect(find.text('Địa chỉ từ đơn'), findsOneWidget);
      expect(find.text('04/10/2026 • 07:09'), findsOneWidget);
      expect(find.text('Chưa có đối tác nhận đơn'), findsOneWidget);
      expect(find.text('Hệ thống đang chờ đối tác phù hợp'), findsOneWidget);
      expect(find.text('Đối tác đã nhận đơn'), findsNothing);
      if (price == null) {
        expect(find.text('Chưa có báo giá'), findsOneWidget);
        expect(find.text('Mã báo giá'), findsNothing);
      } else {
        expect(find.text(price == 0 ? '0đ' : '123.456đ'), findsOneWidget);
        expect(find.text('BG-000018'), findsOneWidget);
        expect(find.text('Chưa có báo giá'), findsNothing);
      }
      expectNoInventedTrackingData();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('missing or UUID codes stay missing in header, summary and quote',
      (tester) async {
    for (final code in <String?>[null, ' ', requestUuid]) {
      final request = fixture(RequestStage.accepted,
          requestCode: code, quoteCode: code, price: 123456);
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: Column(children: [
        TrackingStatusCard(request: request),
        TrackingOrderCard(request: request),
        QuoteStatusCard(price: request.price, quoteCode: request.quoteCode),
      ])))));
      expect(find.text('Mã đơn: Chưa có mã'), findsOneWidget);
      expect(find.text('Chưa có mã'), findsOneWidget);
      expect(find.text('Mã báo giá: Chưa có mã'), findsOneWidget);
      expect(find.text('Đối tác đã nhận đơn'), findsOneWidget);
      expect(find.text('Chưa có thông tin liên hệ đối tác trong đơn.'),
          findsOneWidget);
      expectNoInventedTrackingData();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('map has only the saved rescue marker and no invented location',
      (tester) async {
    for (final hasCoordinates in [false, true]) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: TrackingMapCard(
                      request: fixture(RequestStage.arriving,
                          latitude: hasCoordinates ? 16.075 : null,
                          longitude: hasCoordinates ? 108.235 : null))))));
      await tester.pumpAndSettle();
      expect(find.text('Vị trí cứu hộ đã gửi'), findsOneWidget);
      expect(find.text('Địa chỉ từ đơn'), findsOneWidget);
      final location =
          tester.widget<RequestLocationCard>(find.byType(RequestLocationCard));
      if (hasCoordinates) {
        expect(location.coordinates!.latitude, 16.075);
        expect(location.coordinates!.longitude, 108.235);
        final markers =
            tester.widget<MarkerLayer>(find.byType(MarkerLayer)).markers;
        expect(markers, hasLength(1));
        expect(markers.single.point.latitude, 16.075);
        expect(markers.single.point.longitude, 108.235);
        expect(find.byKey(const ValueKey('rescue-location-marker')),
            findsOneWidget);
      } else {
        expect(location.coordinates, isNull);
        expect(find.text('Chưa có tọa độ'), findsOneWidget);
        expect(find.byType(FlutterMap), findsNothing);
        expect(find.byType(MarkerLayer), findsNothing);
      }
      expectNoInventedTrackingData();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('primary refresh is in status header above order details',
      (tester) async {
    final controller = RefreshTrackingController()
      ..activeRequest = fixture(RequestStage.searching);
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
            body: NewTrackingScreen(
                controller: controller,
                isActive: false,
                photoRepository: photos.FakePhotos()))));
    await tester.pumpAndSettle();
    final action = find.widgetWithText(FilledButton, 'Cập nhật trạng thái');
    expect(
        find.descendant(of: find.byType(TrackingStatusCard), matching: action),
        findsOneWidget);
    expect(tester.getTopLeft(action).dy,
        lessThan(tester.getTopLeft(find.text('Thông tin yêu cầu')).dy));
    await tester.tap(action);
    await tester.pump();
    expect(controller.refreshes, 1);
    expect(controller.activeRequest!.stage, RequestStage.searching);
    expectNoInventedTrackingData();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'empty state guides customer to create a request with a working CTA',
      (tester) async {
    final controller = AppController()..restoringSession = false;
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
            body: NewTrackingScreen(
                controller: controller,
                isActive: false,
                photoRepository: photos.FakePhotos()))));
    expect(find.text('Bạn chưa có yêu cầu cứu hộ đang xử lý'), findsOneWidget);
    expect(find.text('Tạo yêu cầu mới để được hỗ trợ'), findsOneWidget);
    expect(find.byType(TrackingStatusCard), findsNothing);
    expect(find.byType(TrackingOrderCard), findsNothing);
    final action = find.widgetWithText(FilledButton, 'Tạo yêu cầu cứu hộ');
    expect(action, findsOneWidget);
    expect(tester.widget<FilledButton>(action).onPressed, isNotNull);
    await tester.tap(action);
    await tester.pump();
    expect(controller.tabIndex, 1);
    expect(controller.activeRequest, isNull);
    expectNoInventedTrackingData();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'rescuer placeholder follows acceptance and cancellation remains gated',
      (tester) async {
    final controller = AppController()..restoringSession = false;
    addTearDown(controller.dispose);
    for (final stage in RequestStage.values) {
      controller.activeRequest = fixture(stage);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
              body: NewTrackingScreen(
                  key: ValueKey(stage),
                  controller: controller,
                  isActive: false,
                  photoRepository: photos.FakePhotos()))));
      await tester.pumpAndSettle();
      // Reveal the real screen content without calling the backend.
      final scrollable = find.byType(Scrollable).first;
      if (stage == RequestStage.searching || stage == RequestStage.accepted) {
        await tester.scrollUntilVisible(find.text('Hủy yêu cầu'), 350,
            scrollable: scrollable);
        expect(find.text('Hủy yêu cầu'), findsOneWidget);
        await tester.tap(find.text('Hủy yêu cầu'));
        await tester.pumpAndSettle();
        expect(find.text('Hủy yêu cầu cứu hộ?'), findsOneWidget);
        await tester.tap(find.text('Giữ yêu cầu'));
        await tester.pumpAndSettle();
        expect(controller.activeRequest?.stage, stage);
      } else {
        await tester.scrollUntilVisible(find.byType(EmergencySupportCard), 350,
            scrollable: scrollable);
        expect(find.text('Hủy yêu cầu'), findsNothing);
      }
      expectNoInventedTrackingData();
      expect(tester.takeException(), isNull);
    }
  });
}
