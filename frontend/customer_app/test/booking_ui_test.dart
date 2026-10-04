import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/app/app_theme.dart';
import 'package:cuu_ho_247/screens/new_request_screen.dart';
import 'package:cuu_ho_247/widgets/booking_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('booking layout fits small screens and the keyboard',
      (tester) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = AppController()..restoringSession = false;
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(1.3)),
            child: child!),
        home: Scaffold(body: NewRequestScreen(controller: controller))));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byType(CustomerAppHeader)).height,
        lessThanOrEqualTo(80));
    expect(tester.takeException(), isNull);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'booking navigation maps visual order to existing controller tabs',
      (tester) async {
    final controller = AppController()..restoringSession = false;
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            bottomNavigationBar: CustomerBottomNav(controller: controller))));
    const items = [
      ('Trang chủ', 0),
      ('Theo dõi', 2),
      ('Đặt cứu hộ', 1),
      ('Lịch sử', 3),
      ('Tài khoản', 4)
    ];
    var previousX = -1.0;
    for (final item in items) {
      final finder = find.text(item.$1);
      expect(tester.getCenter(finder).dx, greaterThan(previousX));
      previousX = tester.getCenter(finder).dx;
      await tester.tap(finder);
      await tester.pump();
      expect(controller.tabIndex, item.$2);
    }
  });
}
