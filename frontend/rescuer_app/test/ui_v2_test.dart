import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuer/app/connected_app.dart';
import 'package:rescuer/app/rescuer_controller.dart';
import 'package:rescuer/models/backend_models.dart';
import 'package:rescuer/screens/preparation/active_job_panel.dart';
import 'package:rescuer/screens/preparation/account_overview.dart';
import 'package:rescuer/screens/preparation/history_panel.dart';

import 'connected_app_test.dart'
    show FakeService, FakeLocation, approved, mount;
import 'claim_request_test.dart' show request;
import 'job_finance_test.dart' show FinanceFake;

void main() {
  testWidgets(
    'five destinations directly open requests, active jobs, history and account on a narrow phone',
    (tester) async {
      final s = FakeService()
        ..userId = 'rescuer'
        ..snapshot = approved();
      final c = RescuerController(s, FakeLocation());
      addTearDown(() => s.changes.close());
      await mount(tester, c);
      tester.view.physicalSize = const Size(320, 740);
      await tester.pumpAndSettle();
      final nav = find.byType(NavigationBar);
      final destinations = tester
          .widget<NavigationBar>(nav)
          .destinations
          .cast<NavigationDestination>();
      expect(destinations.map((d) => d.label), [
        'Trang chủ',
        'Đơn mới',
        'Đang xử lý',
        'Lịch sử',
        'Tài khoản',
      ]);
      for (var i = 0; i < 5; i++) {
        final label = destinations.elementAt(i).label;
        await tester.tap(find.descendant(of: nav, matching: find.text(label)));
        await tester.pumpAndSettle();
        expect(c.tab, i);
        expect(tester.widget<NavigationBar>(nav).selectedIndex, i);
        if (i == 1) expect(find.text('Bạn đang offline'), findsOneWidget);
        if (i == 2) expect(find.byType(ActiveJobPanel), findsOneWidget);
        if (i == 3) expect(find.byType(HistoryPanel), findsOneWidget);
        if (i == 4) expect(find.byType(AccountOverview), findsOneWidget);
        expect(tester.takeException(), isNull);
      }
      expect(find.text('Lịch sử chuyến'), findsNothing);
      expect(find.byType(BackButton), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'order filter and ignore only change local visibility, never mutate server',
    (tester) async {
      final s = FakeService()
        ..userId = 'rescuer'
        ..snapshot = approved()
        ..page = const RequestPage([
          request,
          AvailableRequest(
            id: 'tow-request',
            service: 'towing',
            vehicle: 'car',
            latitude: 10.775,
            longitude: 106.695,
            distanceKm: 3,
          ),
        ], null);
      final c = RescuerController(s, FakeLocation());
      addTearDown(() => s.changes.close());
      await mount(tester, c);
      await c.setOnline(true);
      c.selectTab(1);
      await tester.pumpAndSettle();
      final before = s.calls.length;
      await tester.ensureVisible(find.byKey(const ValueKey('filter-towing')));
      await tester.tap(find.byKey(const ValueKey('filter-towing')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('preview-request')), findsNothing);
      expect(find.byKey(const ValueKey('preview-tow-request')), findsOneWidget);
      await tester.ensureVisible(find.text('Bỏ qua'));
      await tester.tap(find.text('Bỏ qua'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('preview-tow-request')), findsNothing);
      expect(c.requests.length, 2);
      expect(s.calls.length, before);
      await tester.ensureVisible(
        find.text('Hiện lại đơn đã bỏ qua trên thiết bị'),
      );
      await tester.tap(find.text('Hiện lại đơn đã bỏ qua trên thiết bị'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('preview-tow-request')), findsOneWidget);
      expect(s.calls.length, before);
      expect(find.text('Gọi ngay'), findsNothing);
      expect(find.text('Mở Google Maps'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'V2 quote and history fit 320px and optional fixture previews render all tabs',
    (tester) async {
      final save = Platform.environment['RESCUER_UI_PREVIEWS'] == '1';
      final previousShadows = debugDisableShadows;
      if (save) {
        debugDisableShadows = false;
        addTearDown(() => debugDisableShadows = previousShadows);
      }
      final fontDirectory = Platform.environment['RESCUER_FONT_DIR'];
      if (save && fontDirectory != null) {
        await tester.runAsync(() async {
          for (final entry in const {
            'Roboto': 'roboto-regular.ttf',
            'MaterialIcons': 'MaterialIcons-Regular.otf',
          }.entries) {
            final font = FontLoader(entry.key)
              ..addFont(
                File('$fontDirectory/${entry.value}')
                    .readAsBytes()
                    .then((bytes) => ByteData.sublistView(bytes)),
              );
            await font.load();
          }
        });
      }
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });
      final s = FinanceFake();
      final c = RescuerController(s, FakeLocation());
      addTearDown(() => s.changes.close());
      final boundary = GlobalKey();
      await tester.pumpWidget(
        RepaintBoundary(
          key: boundary,
          child: ConnectedRescuerApp(controller: c),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> capture(String name) async {
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (!save) return;
        final render =
            boundary.currentContext!.findRenderObject()
                as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final img = await render.toImage(pixelRatio: 1);
          final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
          img.dispose();
          final file = File('build/ui_v2_previews/${name}_fixture.png');
          await file.parent.create(recursive: true);
          await file.writeAsBytes(bytes!.buffer.asUint8List());
        });
      }

      c.selectTab(0);
      await capture('home');
      c.selectTab(4);
      await capture('account');
      c.selectTab(2);
      await capture('active_job');
      tester.view.physicalSize = const Size(320, 740);
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('quote-main')));
      await tester.enterText(
        find.byKey(const ValueKey('quote-main')),
        '100000',
      );
      await tester.enterText(
        find.byKey(const ValueKey('quote-extra')),
        '20000',
      );
      await tester.ensureVisible(find.byKey(const ValueKey('send-quote')));
      await tester.pumpAndSettle();
      expect(find.text('120.000 ₫'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await capture('quote_320');
      tester.view.physicalSize = const Size(390, 844);
      s.state = 'completed';
      s.quoteId = 'quote';
      s.total = 120000;
      s.missingJob = true;
      c.selectTab(3);
      await capture('history');
      await tester.tap(find.byKey(const ValueKey('filter-cancelled')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('history-assignment')), findsNothing);
      expect(c.historyItems.length, 1);
      s.page = const RequestPage([request], null);
      await c.refreshActiveJob();
      await c.setOnline(true);
      c.selectTab(1);
      await capture('orders');
      await tester.ensureVisible(find.byKey(const ValueKey('preview-request')));
      await capture('order_card');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      debugDisableShadows = previousShadows;
    },
  );
}
