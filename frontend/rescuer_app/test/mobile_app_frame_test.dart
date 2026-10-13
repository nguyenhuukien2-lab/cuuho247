import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuer/app/connected_app.dart';
import 'package:rescuer/app/mobile_app_frame.dart';
import 'package:rescuer/app/rescuer_app.dart';
import 'package:rescuer/app/rescuer_controller.dart';

import 'active_job_ui_test.dart' show ActiveUiFake;
import 'connected_app_test.dart' show FakeLocation, FakeService, approved;

void setViewport(WidgetTester tester, double width) {
  tester.view.physicalSize = Size(width, 900);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

Rect expectFrame(WidgetTester tester, double viewportWidth) {
  final width = viewportWidth.clamp(0.0, 520.0);
  final frame = tester.getRect(find.byType(Navigator).first);
  expect(MobileAppFrame.maxWidth, 520);
  expect(frame.width, width);
  expect(frame.left, (viewportWidth - width) / 2);
  expect(frame.top, 0);
  expect(frame.height, 900);
  final scaffold = find.byType(Scaffold).first;
  expect(tester.getRect(scaffold), frame);
  expect(MediaQuery.sizeOf(tester.element(scaffold)), frame.size);
  return frame;
}

void expectInside(WidgetTester tester, Finder finder, Rect frame) {
  final rect = tester.getRect(finder);
  expect(rect.left, greaterThanOrEqualTo(frame.left));
  expect(rect.right, lessThanOrEqualTo(frame.right));
}

void main() {
  for (final width in [1440.0, 1920.0, 390.0, 320.0, 360.0, 412.0]) {
    testWidgets('all five tabs use the mobile frame at width $width', (
      tester,
    ) async {
      setViewport(tester, width);
      final service = FakeService()
        ..userId = 'rescuer'
        ..snapshot = approved();
      addTearDown(() => service.changes.close());
      await tester.pumpWidget(
        ConnectedRescuerApp(
          controller: RescuerController(service, FakeLocation()),
        ),
      );
      await tester.pumpAndSettle();
      const labels = [
        'Trang chủ',
        'Đơn mới',
        'Đang xử lý',
        'Lịch sử',
        'Tài khoản',
      ];
      for (var index = 0; index < labels.length; index++) {
        final nav = find.byType(NavigationBar);
        await tester.tap(
          find.descendant(of: nav, matching: find.text(labels[index])),
        );
        await tester.pumpAndSettle();
        final frame = expectFrame(tester, width);
        for (final finder in [
          find.byType(AppBar),
          nav,
          find.byType(ListView).first,
        ]) {
          final rect = tester.getRect(finder);
          expect(rect.left, frame.left);
          expect(rect.width, frame.width);
        }
        expect(tester.widget<NavigationBar>(nav).selectedIndex, index);
        expect(tester.widget<NavigationBar>(nav).destinations, hasLength(5));
        expect(tester.getRect(nav).bottom, frame.bottom);
        expect(tester.takeException(), isNull);
      }
      expect(service.calls, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  }

  for (final width in [1440.0, 320.0]) {
    testWidgets('active trip and overlays stay inside the $width frame', (
      tester,
    ) async {
      setViewport(tester, width);
      final service = ActiveUiFake();
      addTearDown(() => service.changes.close());
      await tester.pumpWidget(
        ConnectedRescuerApp(
          controller: RescuerController(service, FakeLocation()),
        ),
      );
      await tester.pumpAndSettle();
      final frame = expectFrame(tester, width);
      for (final key in [
        'active-job-map',
        'active-job-progress',
        'active-job-finance',
      ]) {
        expectInside(tester, find.byKey(ValueKey(key)), frame);
      }
      final context = tester.element(find.byType(Scaffold));
      showDialog<void>(
        context: context,
        builder: (_) => const AlertDialog(title: Text('Frame dialog')),
      );
      await tester.pumpAndSettle();
      expectInside(tester, find.byType(AlertDialog), frame);
      expectInside(tester, find.byType(ModalBarrier).last, frame);
      Navigator.of(context).pop();
      await tester.pumpAndSettle();
      showModalBottomSheet<void>(
        context: context,
        useSafeArea: true,
        builder: (_) => const SizedBox(
          height: 200,
          width: double.infinity,
          child: Text('Frame sheet'),
        ),
      );
      await tester.pumpAndSettle();
      final sheet = tester.getRect(find.byType(BottomSheet));
      expect(sheet.width, frame.width);
      expect(sheet.left, frame.left);
      expect(sheet.bottom, frame.bottom);
      Navigator.of(context).pop();
      await tester.pumpAndSettle();
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Frame snackbar')));
      await tester.pumpAndSettle();
      expectInside(tester, find.byType(SnackBar), frame);
      expect(tester.takeException(), isNull);
      expect(service.calls, isEmpty);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('mobile safe insets are preserved', (tester) async {
    setViewport(tester, 390);
    tester.view.padding = const FakeViewPadding(top: 24, bottom: 20);
    tester.view.viewPadding = const FakeViewPadding(top: 24, bottom: 20);
    addTearDown(tester.view.resetPadding);
    addTearDown(tester.view.resetViewPadding);
    await tester.pumpWidget(
      const ConnectedRescuerApp(configurationError: 'Test'),
    );
    await tester.pumpAndSettle();
    expectFrame(tester, 390);
    final data = MediaQuery.of(tester.element(find.byType(Scaffold)));
    expect(data.padding, const EdgeInsets.only(top: 24, bottom: 20));
    expect(data.viewPadding, data.padding);
    expect(tester.takeException(), isNull);
  });

  testWidgets('login and configuration routes use the desktop frame', (
    tester,
  ) async {
    setViewport(tester, 1920);
    await tester.pumpWidget(
      const ConnectedRescuerApp(configurationError: 'Test'),
    );
    await tester.pumpAndSettle();
    expectFrame(tester, 1920);
    await tester.pumpWidget(const SizedBox());
    final service = FakeService();
    addTearDown(() => service.changes.close());
    await tester.pumpWidget(
      ConnectedRescuerApp(
        controller: RescuerController(service, FakeLocation()),
      ),
    );
    await tester.pumpAndSettle();
    expectFrame(tester, 1920);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('fixture app uses the same root frame', (tester) async {
    setViewport(tester, 1440);
    await tester.pumpWidget(const RescuerApp());
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expectFrame(tester, 1440);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
