import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/screens/history_details_screen.dart';
import 'package:cuu_ho_247/screens/new_history_screen.dart';
import 'package:cuu_ho_247/services/request_details_service.dart';
import 'package:cuu_ho_247/services/request_photo_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class DetailsFake implements RequestDetailsRepository {
  DetailsFake(this.value, {this.fail = false});
  final RequestDetails? value;
  bool fail;
  @override
  Future<RequestDetails?> load(String id) async {
    if (fail) throw Exception('offline');
    return value;
  }
}

class PhotosFake implements RequestPhotoRepository {
  @override
  Future<List<RequestPhoto>> list(String id) async => [];
  @override
  Future<void> upload(String id, SelectedRequestPhoto photo) async {}
}

void main() {
  test('terminal time ignores initial snapshots and uses matching final event',
      () {
    final data = RequestDetails({
      'status': 'cancelled'
    }, [
      {'status': 'completed', 'occurred_at': '2026-10-01T01:00:00Z'},
      {'status': 'cancelled', 'occurred_at': '2026-10-01T02:00:00Z'},
      {
        'status': 'cancelled',
        'occurred_at': '2026-10-01T03:00:00Z',
        'is_initial_snapshot': true
      },
    ]);
    expect(data.terminalTime, DateTime.utc(2026, 10, 1, 2));
    expect(
        RequestDetails({
          'status': 'completed'
        }, [
          {
            'status': 'completed',
            'occurred_at': '2026-10-01T03:00:00Z',
            'is_initial_snapshot': true
          }
        ]).terminalTime,
        isNull);
  });

  testWidgets(
      'missing optional fields, photos and timeline have empty states on phone',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = AppController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        home: HistoryDetailsScreen(
      requestId: 'own-id',
      controller: controller,
      repository: DetailsFake(
          const RequestDetails({'id': 'own-id', 'status': 'cancelled'}, [])),
      photoRepository: PhotosFake(),
    )));
    await tester.pumpAndSettle();
    expect(find.text('own-id'), findsOneWidget);
    await tester.scrollUntilVisible(
        find.text('Chưa có lịch sử trạng thái.'), 200,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Chưa có ảnh sự cố.'), findsOneWidget);
    expect(find.text('Chi phí / báo giá'), findsNothing);
    expect(find.text('Chờ báo giá'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('load failure retries and missing request is explained',
      (tester) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    final repo = DetailsFake(null, fail: true);
    await tester.pumpWidget(MaterialApp(
        home: HistoryDetailsScreen(
      requestId: 'id',
      controller: controller,
      repository: repo,
      photoRepository: PhotosFake(),
    )));
    await tester.pumpAndSettle();
    expect(find.text('Không tải được chi tiết yêu cầu. Vui lòng thử lại.'),
        findsOneWidget);
    repo.fail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Không tìm thấy yêu cầu trong lịch sử của bạn.'),
        findsOneWidget);
  });

  testWidgets('history card opens a separate detail route', (tester) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    controller.history = [
      RescueRequestData(
          id: 'id',
          service: RescueService.tire,
          vehicle: VehicleKind.car,
          address: 'Test address',
          createdAt: DateTime(2026),
          stage: RequestStage.completed)
    ];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: NewHistoryScreen(controller: controller))));
    await tester.tap(find.text('Vá lốp'));
    await tester.pumpAndSettle();
    expect(find.byType(HistoryDetailsScreen), findsOneWidget);
    expect(find.text('Chi tiết yêu cầu'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(NewHistoryScreen), findsOneWidget);
    expect(find.text('Nhật Ký Cứu Hộ An Toàn'), findsOneWidget);
  });
}
