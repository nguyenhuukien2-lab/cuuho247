import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuer/app/app_state.dart';
import 'package:rescuer/app/rescuer_app.dart';
import 'package:rescuer/models/request_preview.dart';

Future<void> showShell(WidgetTester tester, AppState state) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(RescuerApp(appState: state));
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pump();
}

void main() {
  testWidgets('shows all five navigation destinations', (tester) async {
    final state = AppState();
    await showShell(tester, state);

    for (final label in [
      'Trang chủ',
      'Đơn mới',
      'Đang làm',
      'Lịch sử',
      'Tài khoản',
    ]) {
      expect(find.text(label), findsWidgets);
    }
    await tester.tap(find.text('Đơn mới').last);
    await tester.pumpAndSettle();
    expect(find.text('Đơn mới chưa khả dụng'), findsOneWidget);

    await tester.tap(find.text('Đang làm').last);
    await tester.pumpAndSettle();
    expect(find.text('Bạn chưa có đơn đang làm'), findsOneWidget);

    await tester.tap(find.text('Lịch sử').last);
    await tester.pumpAndSettle();
    expect(find.text('Chưa có đơn trong lịch sử'), findsOneWidget);

    await tester.tap(find.text('Tài khoản').last);
    await tester.pumpAndSettle();
    expect(find.text('Xác minh đối tác'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    state.dispose();
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  testWidgets(
    'request preview and acceptance reveal no customer identity before acceptance',
    (tester) async {
      final state = AppState()
        ..requestFeedState = RequestFeedState.ready
        ..requestPreview = const RequestPreview(
          serviceType: 'Dịch vụ cứu hộ',
          vehicleType: 'Loại xe',
          approximateLocation: 'Khu vực gần đúng',
        );
      await showShell(tester, state);
      await tester.tap(find.text('Đơn mới').last);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Xem chi tiết').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Xem chi tiết').first);
      await tester.pumpAndSettle();

      expect(find.text('Khu vực gần đúng'), findsOneWidget);
      expect(find.text('Số điện thoại'), findsNothing);
      expect(find.text('Địa chỉ chính xác'), findsNothing);
      expect(
        find.text('Thông tin khách hàng sẽ hiển thị sau khi bạn nhận đơn.'),
        findsOneWidget,
      );

      await tester.pumpWidget(const SizedBox());
      state.dispose();
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    },
  );
}
