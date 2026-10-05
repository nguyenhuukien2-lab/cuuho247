import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/app/app_theme.dart';
import 'package:cuu_ho_247/app/user_session.dart';
import 'package:cuu_ho_247/screens/new_tracking_screen.dart';
import 'package:cuu_ho_247/widgets/tracking_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'request_photos_test.dart' as photos;

RescueRequestData fixture(RequestStage stage, {int? price}) =>
    RescueRequestData(
      id: 'real-response-id',
      requestCode: 'CH-000042',
      service: RescueService.towing,
      vehicle: VehicleKind.car,
      address: 'Địa chỉ từ đơn',
      createdAt: DateTime(2026, 10, 4, 7, 9),
      stage: stage,
      price: price,
    );

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

  testWidgets('status displays database code, active badge and no simulated telemetry',
      (tester) async {
    for (final stage in RequestStage.values) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: TrackingStatusCard(request: fixture(stage))))));
      await tester.pumpAndSettle();
      expect(find.text('Mã đơn: CH-000042'), findsOneWidget);
      expect(find.textContaining('real-response-id'), findsNothing);
      expect(find.text(trackingHeadline(stage)), findsOneWidget);
      expect(find.text('Trực tiếp'),
          stage.isTerminal ? findsNothing : findsOneWidget);
      expect(find.text('Đang cập nhật'),
          stage.isTerminal ? findsNothing : findsOneWidget);
      for (final sample in ['03:44', '1.2', '38', 'Đã xác thực']) {
        expect(find.text(sample), findsNothing);
      }
    }
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
      // Mount all content by using a tall viewport; no real backend is called.
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
      expect(find.text('Gọi điện ngay'), findsNothing);
      expect(find.text('Nhắn tin'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}
