import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuer/app/mobile_ui.dart';
import 'package:rescuer/app/history_payment_controller.dart';
import 'package:rescuer/app/rescuer_controller.dart';
import 'package:rescuer/models/backend_models.dart';
import 'package:rescuer/screens/payment/rescuer_cash_screen.dart';
import 'package:rescuer/screens/preparation/active_job_panel.dart';
import 'package:rescuer/screens/preparation/history_panel.dart';
import 'package:rescuer/services/payment_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'cash_payment_test.dart'
    show CashSource, controller, ready, mountCash, unmount;
import 'connected_app_test.dart' show FakeLocation;
import 'job_finance_test.dart' show FinanceFake;
import 'payment_realtime_test.dart' show dto, flush;

Future<void> scrollTo(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pump();
}

Future<RescuerController> mountJobs(
  WidgetTester tester,
  CashSource source, {
  bool history = true,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final jobs = FinanceFake()
    ..state = history ? 'completed' : 'in_progress'
    ..missingJob = history
    ..quoteId = 'quote'
    ..total = 100000;
  source.userId = 'rescuer';
  final c = RescuerController(jobs, FakeLocation(), paymentSource: source)
    ..start();
  await tester.pump();
  c.selectTab(history ? 3 : 2);
  await tester.pump();
  await tester.pumpWidget(
    MaterialApp(
      theme: RescueTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          child: ListenableBuilder(
            listenable: c,
            builder: (_, _) =>
                history ? HistoryPanel(c: c) : ActiveJobPanel(c: c),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  addTearDown(() async {
    c.dispose();
    await jobs.changes.close();
    await source.close();
  });
  return c;
}

void main() {
  for (final history in [false, true]) {
    testWidgets(
      '${history ? 'completed history' : 'active'} cash opens dialog, RPC and getter prove paid',
      (tester) async {
        final source = CashSource()..gate = Completer<void>();
        final c = await mountJobs(tester, source, history: history);
        if (history) {
          expect(c.activeJob, isNull);
          final detail = find.byKey(
            const ValueKey('history-detail-assignment'),
          );
          await scrollTo(tester, detail);
          final reads = source.reads;
          await tester.tap(detail);
          await tester.pumpAndSettle();
          expect(source.reads, greaterThan(reads));
          expect(c.historyDetail!.assignment.state, 'completed');
        } else {
          final progress = tester
              .getTopLeft(find.byKey(const ValueKey('active-job-progress')))
              .dy;
          final finance = tester
              .getTopLeft(find.byKey(const ValueKey('active-job-finance')))
              .dy;
          final payment = tester
              .getTopLeft(find.byKey(const ValueKey('active-job-payment')))
              .dy;
          expect(progress, lessThan(finance));
          expect(finance, lessThan(payment));
        }
        final section = find.byKey(
          ValueKey(
            history
                ? 'history-detail-payment-assignment'
                : 'active-job-payment',
          ),
        );
        expect(
          c.payments.payment?.status,
          'awaiting_payment',
          reason: '${c.payments.requestId} / ${c.payments.error}',
        );
        expect(section, findsOneWidget);
        final open = find.descendant(
          of: section,
          matching: find.byKey(const ValueKey('open-payment-assignment')),
        );
        await tester.ensureVisible(open);
        await tester.tap(open);
        await tester.pump();
        source.emit(PaymentSignalKind.connected);
        await tester.pumpAndSettle();
        expect(find.text('Thu tiền mặt'), findsOneWidget);
        final collect = find.byKey(const ValueKey('collect-cash'));
        await scrollTo(tester, collect);
        await tester.tap(collect);
        await tester.pumpAndSettle();
        expect(find.byType(RescuerCashConfirmDialog), findsOneWidget);
        expect(find.byType(TextField), findsNothing);
        final confirm = find.byKey(const ValueKey('confirm-cash'));
        await tester.ensureVisible(confirm);
        await tester.tap(confirm);
        await tester.pump(const Duration(milliseconds: 400));
        expect(source.calls, hasLength(1));
        expect(find.byKey(const ValueKey('cash-confirming')), findsOneWidget);
        final reads = source.reads;
        source.gate!.complete();
        await tester.pumpAndSettle();
        expect(source.reads, greaterThan(reads));
        expect(find.byKey(const ValueKey('cash-paid')), findsOneWidget);
        expect(find.byKey(const ValueKey('collect-cash')), findsNothing);
        if (history) expect(c.activeJob, isNull);
        await tester.pageBack();
        await tester.pumpAndSettle();
        expect(c.payments.payment!.status, 'paid');
        expect(c.historyPayments.stateFor('request').payment!.status, 'paid');
        await tester.pumpWidget(const SizedBox());
        c.setForeground(false);
      },
    );
  }

  for (final status in ['awaiting_payment', 'verifying', 'paid']) {
    testWidgets('bank $status is read-only and refresh calls getter', (
      tester,
    ) async {
      final source = CashSource()
        ..row = {...dto(status: status), 'method': 'bank_transfer'};
      // Verifying uses an animated spinner; disable animation for deterministic pumps.
      final c = controller(source);
      await tester.pumpWidget(
        MaterialApp(
          theme: RescueTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(disableAnimations: true),
            child: child!,
          ),
          home: RescuerCashScreen(controller: c),
        ),
      );
      await tester.pump();
      source.emit(PaymentSignalKind.connected);
      await tester.pumpAndSettle();
      expect(
        find.byKey(
          ValueKey(switch (status) {
            'paid' => 'bank-paid',
            'verifying' => 'bank-verifying',
            _ => 'bank-waiting',
          }),
        ),
        findsOneWidget,
      );
      final reads = source.reads;
      await c.refreshJobPayment();
      await tester.pumpAndSettle();
      expect(source.reads, greaterThan(reads));
      expect(find.byKey(const ValueKey('collect-cash')), findsNothing);
      expect(find.byKey(const ValueKey('confirm-cash')), findsNothing);
      expect(find.textContaining('Đã nhận chuyển khoản'), findsNothing);
      await c.confirm(c.payment!);
      expect(source.calls, isEmpty);
      await unmount(tester, source);
    });
  }

  for (final (method, status) in [
    ('cash', 'paid'),
    ('bank_transfer', 'awaiting_payment'),
    ('bank_transfer', 'verifying'),
    ('bank_transfer', 'paid'),
  ]) {
    testWidgets('history $method $status stays read-only in list and detail', (
      tester,
    ) async {
      final source = CashSource()
        ..row = {...dto(status: status), 'method': method};
      final c = await mountJobs(tester, source);
      await c.loadHistoryDetail('assignment');
      await tester.pumpAndSettle();
      expect(c.activeJob, isNull);
      expect(find.text('Xác nhận đã nhận đủ tiền'), findsNothing);
      final section = find.byKey(
        const ValueKey('history-detail-payment-assignment'),
      );
      final open = find.descendant(
        of: section,
        matching: find.byKey(const ValueKey('open-payment-assignment')),
      );
      await tester.ensureVisible(open);
      await tester.tap(open);
      await tester.pump();
      source.emit(PaymentSignalKind.connected);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('collect-cash')), findsNothing);
      expect(find.byKey(const ValueKey('confirm-cash')), findsNothing);
      expect(source.calls, isEmpty);
      await tester.pumpWidget(const SizedBox());
      c.setForeground(false);
    });
  }

  test('older getter cannot validate a cached paid snapshot', () async {
    final source = CashSource()..row = dto(status: 'paid', version: '3');
    final c = controller(source);
    await ready(c, source);
    final jobs = FinanceFake()..state = 'completed';
    final summary = HistoryPaymentController(source);
    final assignment = JobAssignment.fromJson(jobs.data);
    await summary.refresh([assignment]);
    source.row = dto(status: 'awaiting_payment', version: '2');
    await c.retry();
    await summary.refresh([assignment]);
    expect(summary.stateFor('request').error, isNotNull);
    expect(c.watcher.error, isNotNull);
    expect(c.watcher.stale, isTrue);
    expect(c.canConfirm, isFalse);
    expect(source.calls, isEmpty);
    c.dispose();
    summary.dispose();
    await jobs.changes.close();
    await source.close();
  });

  for (final message in [
    'VERSION_CONFLICT',
    'PAYMENT_ALREADY_SETTLED',
    'PAYMENT_STATE_CONFLICT',
  ]) {
    test('$message refetches backend paid without another mutation', () async {
      final source = CashSource()
        ..gate = Completer<void>()
        ..commandFailure = PostgrestException(message: message);
      final c = controller(source);
      await ready(c, source);
      final reads = source.reads;
      final pending = c.confirm(c.payment!);
      source.row = dto(status: 'paid', version: '2');
      source.gate!.complete();
      await pending;
      expect(source.reads, greaterThan(reads));
      expect(c.payment!.status, 'paid');
      expect(c.issue, isNull);
      expect(source.calls, hasLength(1));
      c.dispose();
      await source.close();
    });
  }

  testWidgets(
    'network error retry reads getter, never changes payment to failed',
    (tester) async {
      final source = CashSource()..failure = Exception('private backend trace');
      await mountCash(tester, source);
      expect(find.text('Không thể cập nhật trạng thái'), findsOneWidget);
      expect(find.textContaining('private backend trace'), findsNothing);
      expect(find.text('Thanh toán không thành công'), findsNothing);
      final reads = source.reads;
      source.failure = null;
      final retry = find.text('Thử lại');
      await scrollTo(tester, retry);
      await tester.tap(retry);
      await tester.pumpAndSettle();
      expect(source.reads, greaterThan(reads));
      expect(find.text('Thu tiền mặt'), findsOneWidget);
      expect(source.calls, isEmpty);
      await unmount(tester, source);
    },
  );

  testWidgets(
    'cached paid is hidden after network error until getter succeeds',
    (tester) async {
      final source = CashSource()..row = dto(status: 'paid');
      await mountCash(tester, source);
      expect(find.byKey(const ValueKey('cash-paid')), findsOneWidget);
      source.failure = TimeoutException('private');
      final screen = tester.widget<RescuerCashScreen>(
        find.byType(RescuerCashScreen),
      );
      await screen.controller.refreshJobPayment();
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('cash-paid')), findsNothing);
      expect(find.text('Không thể cập nhật trạng thái'), findsOneWidget);
      await unmount(tester, source);
    },
  );

  testWidgets(
    'history without payment never invents paid or collection action',
    (tester) async {
      final source = CashSource()..row = null;
      final c = await mountJobs(tester, source);
      await c.loadHistoryDetail('assignment');
      await tester.pumpAndSettle();
      expect(find.text('Chưa có thông tin thanh toán'), findsWidgets);
      expect(
        find.byKey(const ValueKey('open-payment-assignment')),
        findsNothing,
      );
      expect(find.text('Đã thanh toán'), findsNothing);
      expect(source.calls, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  test(
    'manual active refresh, completion and history resume refetch payment',
    () async {
      final source = CashSource()..userId = 'rescuer';
      final jobs = FinanceFake()
        ..quoteId = 'quote'
        ..total = 100000;
      final c = RescuerController(jobs, FakeLocation(), paymentSource: source)
        ..start();
      await flush();
      c.selectTab(2);
      await flush();
      var reads = source.reads;
      await c.refreshActiveJob();
      await flush();
      expect(source.reads, greaterThan(reads));
      reads = source.reads;
      await c.completeJob(c.activeJob!.assignment);
      await flush();
      expect(c.activeJob, isNull);
      expect(c.tab, 3);
      expect(source.reads, greaterThan(reads));
      reads = source.reads;
      c.setForeground(false);
      c.setForeground(true);
      await flush();
      expect(source.reads, greaterThan(reads));
      c.dispose();
      await source.close();
      await jobs.changes.close();
    },
  );
}
