import 'dart:async';

import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/app/app_theme.dart';
import 'package:cuu_ho_247/screens/new_request_screen.dart';
import 'package:cuu_ho_247/services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class FailingRequestController extends AppController {
  final keys = <String>[];
  final submittedAddresses = <String>[];
  Completer<void>? pending;
  @override
  bool get isLoggedIn => true;
  @override
  bool get backendConfigured => true;

  @override
  Future<RescueRequestData> createRequest(
      {required String clientRequestId,
      required String address,
      required String description,
      required String contactName,
      required String contactPhone,
      double? latitude,
      double? longitude,
      bool openTracking = true}) async {
    keys.add(clientRequestId);
    submittedAddresses.add(address);
    if (pending != null) await pending!.future;
    throw const AppFailure('Mất kết nối. Thông tin đã nhập vẫn được giữ.');
  }
}

void main() {
  testWidgets(
      'failed submit keeps inputs, tab and key; pending submit is disabled',
      (tester) async {
    // Tall viewport keeps all form fields mounted; this is a state test,
    // not a claim about real phone rendering or actual network transport.
    tester.view.physicalSize = const Size(420, 3100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = FailingRequestController()
      ..selectedService = RescueService.tire
      ..tabIndex = 1
      ..pending = Completer<void>();
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: NewRequestScreen(controller: controller))));
    final fields = find.byType(TextFormField);
    expect(fields, findsNWidgets(4));
    await tester.enterText(fields.at(0), 'Địa điểm kiểm thử do khách xác nhận');
    await tester.enterText(fields.at(1), 'Mô tả kiểm thử');
    await tester.enterText(fields.at(2), 'Khách kiểm thử');
    await tester.enterText(fields.at(3), '0900000000');
    await tester.tap(find.byType(CheckboxListTile));
    tester.testTextInput.hide();
    await tester.pump();
    await tester.tap(find.text('Gửi yêu cầu cứu hộ'));
    await tester.pump();
    expect(controller.keys, hasLength(1));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    controller.pending!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Mất kết nối. Thông tin đã nhập vẫn được giữ.'),
        findsOneWidget);
    for (final value in [
      'Địa điểm kiểm thử do khách xác nhận',
      'Mô tả kiểm thử',
      'Khách kiểm thử',
      '0900000000'
    ]) {
      expect(find.text(value), findsOneWidget);
    }
    expect(controller.tabIndex, 1);
    expect(controller.activeRequest, isNull);
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(controller.keys, hasLength(2));
    expect(controller.keys[1], controller.keys[0]);
    expect(controller.submittedAddresses[1], controller.submittedAddresses[0]);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
