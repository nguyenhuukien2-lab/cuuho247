import 'request_steps.dart';
import 'dart:async';

import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/app/app_theme.dart';
import 'package:cuu_ho_247/screens/new_request_screen.dart';
import 'package:cuu_ho_247/services/location_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeLocationService implements CustomerLocationService {
  Completer<LocationResult> pending = Completer<LocationResult>();
  int calls = 0;
  @override
  Future<LocationResult> getCurrentLocation() {
    calls++;
    return pending.future;
  }
}

class CapturingController extends AppController {
  final submissions =
      <({String address, double? latitude, double? longitude})>[];
  @override
  bool get isLoggedIn => true;
  @override
  bool get backendConfigured => true;
  @override
  Future<RescueRequestData> createRequest({
    required String clientRequestId,
    required String address,
    required String description,
    required String contactName,
    required String contactPhone,
    double? latitude,
    double? longitude,
    bool openTracking = true,
  }) async {
    submissions
        .add((address: address, latitude: latitude, longitude: longitude));
    return RescueRequestData(
        id: 'test-request',
        clientRequestId: clientRequestId,
        service: RescueService.tire,
        vehicle: VehicleKind.car,
        address: address,
        createdAt: DateTime.utc(2026),
        stage: RequestStage.searching);
  }
}

const located = LocationResult(LocationStatus.acquired, 'Đã định vị',
    coordinates: RescueCoordinates(10.7769, 106.7009));

Future<void> mountForm(WidgetTester tester, CapturingController controller,
    FakeLocationService service) async {
  tester.view.physicalSize = const Size(420, 3100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(controller.dispose);
  controller.selectedService = RescueService.tire;
  await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
          body: NewRequestScreen(
              controller: controller, locationService: service))));
  final fields = find.byType(TextFormField, skipOffstage: false);
  await enterRequest(tester, fields.at(0), '  123 Nguyễn Huệ  ');
  await enterRequest(tester, fields.at(2), 'Khách hàng');
  await enterRequest(tester, fields.at(3), '0900000000');
  tester.testTextInput.hide();
  await tester.pump();
  await requestStep(tester, 2);
}

Future<void> sendRequest(WidgetTester tester) async {
  await tapRequest(tester, find.byType(CheckboxListTile));
  await tester.pump();
  await tapRequest(tester, find.text('XÁC NHẬN ĐẶT CỨU HỘ'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('no automatic prompt; manual form sends null coordinates',
      (tester) async {
    final controller = CapturingController();
    final service = FakeLocationService();
    await mountForm(tester, controller, service);
    expect(service.calls, 0);
    await sendRequest(tester);
    expect(controller.submissions.single,
        (address: '123 Nguyễn Huệ', latitude: null, longitude: null));
  });

  testWidgets(
      'loading then success sends GPS with text and clears for next order',
      (tester) async {
    final controller = CapturingController();
    final service = FakeLocationService();
    await mountForm(tester, controller, service);
    await tapRequest(tester, find.text('Lấy vị trí hiện tại'));
    await tester.pump();
    expect(find.text('Đang lấy vị trí…'), findsOneWidget);
    await tapRequest(tester, find.text('Lấy vị trí hiện tại'));
    expect(service.calls, 1);
    service.pending.complete(located);
    await tester.pumpAndSettle();
    expect(find.text('Đã lấy vị trí'), findsOneWidget);
    expect(find.text('Tọa độ: 10.776900, 106.700900'), findsOneWidget);
    await sendRequest(tester);
    expect(controller.submissions.single,
        (address: '123 Nguyễn Huệ', latitude: 10.7769, longitude: 106.7009));
    await requestStep(tester, 2);
    expect(find.text('Chưa lấy vị trí'), findsOneWidget);
    await sendRequest(tester);
    expect(controller.submissions.last.latitude, isNull);
  });

  for (final status in [LocationStatus.denied, LocationStatus.unavailable]) {
    testWidgets('$status allows manual submission and retry', (tester) async {
      final controller = CapturingController();
      final service = FakeLocationService();
      await mountForm(tester, controller, service);
      await tapRequest(tester, find.text('Lấy vị trí hiện tại'));
      service.pending.complete(LocationResult(status, 'Thử lại hoặc nhập tay'));
      await tester.pumpAndSettle();
      expect(
          find.text(status == LocationStatus.denied
              ? 'Bạn đã từ chối quyền vị trí'
              : 'Không hỗ trợ/lỗi vị trí'),
          findsOneWidget);
      await sendRequest(tester);
      expect(controller.submissions.single.latitude, isNull);
      service.pending = Completer<LocationResult>();
      await tapRequest(tester, find.text('Lấy vị trí hiện tại'));
      service.pending.complete(located);
      await tester.pumpAndSettle();
      expect(find.text('Đã lấy vị trí'), findsOneWidget);
    });
  }

  testWidgets('submit during GPS ignores a late position', (tester) async {
    final controller = CapturingController();
    final service = FakeLocationService();
    await mountForm(tester, controller, service);
    await tapRequest(tester, find.text('Lấy vị trí hiện tại'));
    await tester.pump();
    await sendRequest(tester);
    service.pending.complete(located);
    await tester.pumpAndSettle();
    expect(controller.submissions.single.latitude, isNull);
    expect(find.text('Đã lấy vị trí'), findsNothing);
  });

  testWidgets(
      'manual selection clears acquired GPS and invalidates confirmation',
      (tester) async {
    final controller = CapturingController();
    final service = FakeLocationService();
    await mountForm(tester, controller, service);
    await tapRequest(tester, find.text('Lấy vị trí hiện tại'));
    service.pending.complete(located);
    await tester.pumpAndSettle();
    await tapRequest(tester, find.byType(CheckboxListTile));
    await tester.pump();
    await tapRequest(tester, find.text('Chỉ dùng địa chỉ nhập tay'));
    await tester.pump();
    await requestStep(tester, 4);
    expect(tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
        isFalse);
    await sendRequest(tester);
    expect(controller.submissions.single.longitude, isNull);
  });

  testWidgets('GPS result after disposal is ignored', (tester) async {
    final controller = CapturingController();
    final service = FakeLocationService();
    await mountForm(tester, controller, service);
    await tapRequest(tester, find.text('Lấy vị trí hiện tại'));
    await tester.pumpWidget(const SizedBox.shrink());
    service.pending.complete(located);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
