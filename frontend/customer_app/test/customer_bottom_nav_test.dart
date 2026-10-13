import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/app/app_theme.dart';
import 'package:cuu_ho_247/widgets/booking_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  for (final setting in [
    for (final width in [320.0, 360.0, 390.0])
      for (final scale in [1.0, 1.3, 1.5]) (width, scale),
    (320.0, 1.8),
  ]) {
    testWidgets('raised booking circle keeps five tab callbacks at $setting',
        (tester) async {
      tester.view.physicalSize = Size(setting.$1, 740);
      tester.view.devicePixelRatio = 1;
      tester.view.padding = const FakeViewPadding(bottom: 24);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      addTearDown(tester.view.resetPadding);
      final controller = AppController();
      addTearDown(controller.dispose);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(setting.$2)),
              child: child!),
          home: AnimatedBuilder(
              animation: controller,
              builder: (context, _) => Scaffold(
                  bottomNavigationBar:
                      CustomerBottomNav(controller: controller)))));
      await tester.pumpAndSettle();
      final circle = find.byKey(const ValueKey('customer-booking-nav-circle'));
      expect(tester.getSize(circle), const Size(56, 56));
      expect(tester.getCenter(circle).dx, closeTo(setting.$1 / 2, .01));
      expect(tester.getRect(circle).top,
          lessThan(tester.getRect(find.byIcon(Icons.home_rounded)).top));
      expect(tester.getRect(circle).bottom, lessThan(740 - 24));
      expect(
          (tester.widget<Container>(circle).decoration as BoxDecoration).color,
          const Color(0xFF1D4ED8));
      await tester.tap(circle);
      await tester.pumpAndSettle();
      expect(controller.tabIndex, 1);
      const visualTabs = [
        ('Trang chủ', 0),
        ('Theo dõi', 2),
        ('Đặt cứu hộ', 1),
        ('Lịch sử', 3),
        ('Tài khoản', 4)
      ];
      double previous = -1;
      for (final item in visualTabs) {
        final label = find.text(item.$1);
        expect(label.hitTestable(), findsOneWidget);
        expect(tester.getCenter(label).dx, greaterThan(previous));
        previous = tester.getCenter(label).dx;
        await tester.tap(label);
        await tester.pumpAndSettle();
        expect(controller.tabIndex, item.$2);
        final selected = find.ancestor(
            of: label,
            matching: find.byWidgetPredicate((widget) =>
                widget is Semantics && widget.properties.selected == true));
        expect(selected, findsOneWidget);
        expect(tester.takeException(), isNull);
      }
    });
  }
}
