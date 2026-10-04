import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/app/app_theme.dart';
import 'package:cuu_ho_247/screens/new_history_screen.dart';
import 'package:cuu_ho_247/screens/history_details_screen.dart';
import 'package:cuu_ho_247/widgets/history_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

RescueRequestData trip(String id, RequestStage stage, RescueService service,
        {int? price}) =>
    RescueRequestData(
        id: id,
        stage: stage,
        service: service,
        vehicle: VehicleKind.car,
        address: 'Địa điểm thật từ phản hồi $id',
        createdAt: DateTime(2026, 10, id == 'latest' ? 3 : 1, 9, 15),
        price: price);

void main() {
  testWidgets(
      'history filters use loaded counts, newest first and keep detail route',
      (tester) async {
    final controller = AppController()
      ..history = [
        trip('older', RequestStage.cancelled, RescueService.battery),
        trip('latest', RequestStage.completed, RescueService.towing, price: 0),
      ];
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: NewHistoryScreen(controller: controller))));
    expect(
        tester.widget<Text>(find.byKey(const ValueKey('history-total'))).data,
        '2');
    expect(
        tester.widget<Text>(find.byKey(const ValueKey('history-count-1'))).data,
        '1');
    final first =
        tester.widget<HistoryTripCard>(find.byType(HistoryTripCard).first);
    expect(first.request.id, 'latest');
    await tester.tap(find.byKey(const ValueKey('history-filter-2')));
    await tester.pumpAndSettle();
    expect(
        tester.widget<HistoryTripCard>(find.byType(HistoryTripCard)).request.id,
        'older');
    await tester.tap(find.byKey(const ValueKey('history-filter-1')));
    await tester.pumpAndSettle();
    final details = find.text('Xem chi tiết');
    await tester.ensureVisible(details);
    await tester.pumpAndSettle();
    await tester.tap(details);
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<HistoryDetailsScreen>(find.byType(HistoryDetailsScreen))
            .requestId,
        'latest');
  });

  testWidgets('empty cancelled filter has specific message and request action',
      (tester) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: NewHistoryScreen(controller: controller))));
    expect(find.text('Chưa có lịch sử cứu hộ'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('history-filter-2')));
    await tester.pumpAndSettle();
    expect(find.text('Không có chuyến nào đã hủy'), findsOneWidget);
    expect(find.byType(HistoryTripCard), findsNothing);
    final action = find.text('Tạo yêu cầu cứu hộ');
    await tester.ensureVisible(action);
    await tester.tap(action);
    expect(controller.tabIndex, 1);
  });

  testWidgets('loading error does not invent zero statistics or empty result',
      (tester) async {
    final controller = AppController()..loadError = 'Không tải được lịch sử';
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: NewHistoryScreen(controller: controller))));
    expect(find.text('Chưa có dữ liệu'), findsOneWidget);
    expect(find.byKey(const ValueKey('history-total')), findsNothing);
    expect(find.byKey(const ValueKey('history-count-0')), findsNothing);
    expect(find.byType(HistoryEmptyState), findsNothing);
    expect(find.text('Không tải được lịch sử'), findsOneWidget);
  });

  testWidgets(
      'trip cost accepts zero, missing cost and policy statistics stay hidden',
      (tester) async {
    Future<void> mount(int? price) => tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
            body: SingleChildScrollView(
                child: Column(children: [
          HistoryTripCard(
              request: trip('id', RequestStage.completed, RescueService.tire,
                  price: price),
              onDetails: () {}),
          const WarrantyBanner(),
        ])))));
    await mount(null);
    expect(find.text('Chi phí / báo giá'), findsNothing);
    expect(find.textContaining('48 giờ'), findsNothing);
    expect(find.textContaining('100%'), findsNothing);
    expect(find.textContaining('VAT'), findsNothing);
    await mount(0);
    expect(find.text('Chi phí / báo giá'), findsOneWidget);
    expect(find.textContaining('0'), findsWidgets);
    expect(find.textContaining('Địa điểm thật từ phản hồi'), findsOneWidget);
  });
}
