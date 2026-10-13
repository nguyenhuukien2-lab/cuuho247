import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rescuer/app/cash_payment_controller.dart';
import 'package:rescuer/app/mobile_ui.dart';
import 'package:rescuer/screens/payment/rescuer_cash_screen.dart';
import 'package:rescuer/services/payment_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'payment_realtime_test.dart' show FakePayments, dto, flush;

// All amounts/codes/timestamps below are isolated test fixtures, never app data.
class CashSource extends FakePayments implements CashPaymentCommands {
  CashSource() {
    row = dto(status: 'awaiting_payment');
  }
  final calls = <Map<String, dynamic>>[];
  Object? commandFailure;
  Completer<void>? gate;
  bool commit = true;
  @override
  Future<void> confirmCash(Map<String, dynamic> params) async {
    calls.add(params);
    if (gate != null) await gate!.future;
    if (commandFailure != null) throw commandFailure!;
    if (commit) row = dto(status: 'paid', version: '2');
  }
}

CashPaymentController controller(
  CashSource source, {
  bool completed = true,
  bool approved = true,
}) => CashPaymentController(
  source: source,
  requestId: 'request',
  assignmentId: 'assignment',
  completed: completed,
  canCollect: () => approved,
);

Future<void> ready(CashPaymentController c, CashSource source) async {
  await c.start();
  source.emit(PaymentSignalKind.connected);
  await flush();
}

Future<void> mountCash(
  WidgetTester tester,
  CashSource source, {
  double width = 390,
  double scale = 1,
}) async {
  tester.view.physicalSize = Size(width, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final c = controller(source);
  await tester.pumpWidget(
    MaterialApp(
      theme: RescueTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: RescuerCashScreen(controller: c, requestCode: 'CH-000001'),
    ),
  );
  await tester.pump();
  source.emit(PaymentSignalKind.connected);
  await tester.pumpAndSettle();
}

Future<void> unmount(WidgetTester tester, CashSource source) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump();
  await tester.runAsync(source.close);
}

void main() {
  test(
    'only approved, VND, positive authoritative awaiting cash can confirm',
    () async {
      for (final change in <Map<String, dynamic>>[
        {'method': 'bank_transfer'},
        {'method': null},
        {'status': 'paid'},
        {'status': 'cancelled'},
        {'status': 'verifying'},
        {'amount_expected': '0'},
        {'currency': 'USD'},
        {'assignment_id': 'different'},
      ]) {
        final source = CashSource()
          ..row = {...dto(status: 'awaiting_payment'), ...change};
        final c = controller(source);
        await ready(c, source);
        expect(c.canConfirm, isFalse, reason: '$change');
        if (c.payment != null) await c.confirm(c.payment!);
        expect(source.calls, isEmpty);
        c.dispose();
        await source.close();
      }
      for (final allowed in [(false, false), (true, false)]) {
        final source = CashSource();
        final c = controller(
          source,
          completed: allowed.$1,
          approved: allowed.$2,
        );
        await ready(c, source);
        expect(c.canConfirm, isFalse);
        c.dispose();
        await source.close();
      }
    },
  );

  test(
    'double tap sends once, exact amount/version strings; getter proves paid',
    () async {
      final source = CashSource()..gate = Completer<void>();
      final c = controller(source);
      await ready(c, source);
      final reviewed = c.payment!;
      final first = c.confirm(reviewed);
      await c.confirm(reviewed);
      expect(source.calls, hasLength(1));
      expect(c.submitting, isTrue);
      expect(c.payment!.status, 'awaiting_payment');
      expect(source.calls.single['p_amount_received'], '100000');
      expect(source.calls.single['p_expected_version'], '1');
      expect(source.calls.single.keys.toSet(), {
        'p_request_id',
        'p_payment_id',
        'p_amount_received',
        'p_expected_version',
        'p_operation_id',
      });
      source.gate!.complete();
      await first;
      expect(c.payment!.status, 'paid');
      expect(c.payment!.cashReceivedAt, DateTime.parse('2026-10-10T02:00:00Z'));
      c.dispose();
      await source.close();
    },
  );

  test(
    'lost response stays error, read retry discovers backend commit',
    () async {
      final source = CashSource()..commandFailure = TimeoutException('lost');
      final c = controller(source);
      await ready(c, source);
      await c.confirm(c.payment!);
      expect(c.issue, CashIssue.timeout);
      expect(c.payment!.status, 'awaiting_payment');
      source.row = dto(status: 'paid', version: '2');
      await c.retry();
      expect(c.payment!.status, 'paid');
      expect(source.calls, hasLength(1));
      c.dispose();
      await source.close();
    },
  );

  test(
    'uncertain retry reuses original operation after explicit confirmation',
    () async {
      final source = CashSource()..commandFailure = TimeoutException('lost');
      final c = controller(source);
      await ready(c, source);
      await c.confirm(c.payment!);
      await c.retry();
      source.commandFailure = null;
      await c.confirm(c.payment!);
      expect(source.calls, hasLength(2));
      expect(source.calls.first, source.calls.last);
      c.dispose();
      await source.close();
    },
  );

  test(
    'old confirmation snapshot is rejected after realtime version update',
    () async {
      final source = CashSource();
      final c = controller(source);
      await ready(c, source);
      final reviewed = c.payment!;
      source.row = dto(status: 'awaiting_payment', version: '2');
      await c.watcher.refresh();
      await c.confirm(reviewed);
      expect(source.calls, isEmpty);
      expect(c.issue, CashIssue.conflict);
      c.dispose();
      await source.close();
    },
  );

  test('backend conflicts and rejected statuses never imply paid', () async {
    for (final (message, issue) in [
      ('VERSION_CONFLICT', CashIssue.conflict),
      ('PAYMENT_ALREADY_SETTLED', CashIssue.settled),
      ('PAYMENT_NOT_ELIGIBLE', CashIssue.unavailable),
      ('PAYMENT_NOT_ACCESSIBLE', CashIssue.unavailable),
    ]) {
      final source = CashSource()
        ..commandFailure = PostgrestException(message: message);
      final c = controller(source);
      await ready(c, source);
      await c.confirm(c.payment!);
      expect(c.issue, issue);
      expect(c.payment!.status, 'awaiting_payment');
      expect(c.canConfirm, isFalse);
      c.dispose();
      await source.close();
    }
  });

  test(
    'successful command without paid getter cannot manufacture success',
    () async {
      final source = CashSource()..commit = false;
      final c = controller(source);
      await ready(c, source);
      await c.confirm(c.payment!);
      expect(c.issue, CashIssue.failed);
      expect(c.payment!.status, 'awaiting_payment');
      c.dispose();
      await source.close();
    },
  );

  test(
    'disconnect and logout disable cash; late command cannot restore old data',
    () async {
      final source = CashSource()..gate = Completer<void>();
      final c = controller(source);
      await ready(c, source);
      source.emit(PaymentSignalKind.disconnected);
      await flush();
      expect(c.canConfirm, isFalse);
      source.emit(PaymentSignalKind.connected);
      await flush();
      final pending = c.confirm(c.payment!);
      source.login(null);
      source.gate!.complete();
      await pending;
      expect(c.payment, isNull);
      expect(c.canConfirm, isFalse);
      c.dispose();
      await source.close();
    },
  );

  test(
    'cash RPC preserves bigint payload and uses authenticated client',
    () async {
      final requests = <http.Request>[];
      final client = SupabaseClient(
        'https://example.invalid',
        'test-anon',
        httpClient: MockClient((request) async {
          requests.add(request);
          if (request.url.path.contains('/auth/')) {
            return http.Response(
              jsonEncode({
                'access_token': 'test-token',
                'refresh_token': 'refresh',
                'token_type': 'bearer',
                'expires_in': 3600,
                'user': {
                  'id': 'owner',
                  'aud': 'authenticated',
                  'created_at': '2026-10-10T00:00:00Z',
                  'app_metadata': {},
                  'user_metadata': {},
                },
              }),
              200,
            );
          }
          return http.Response(
            '{}',
            200,
            request: request,
            headers: {'content-type': 'application/json'},
          );
        }),
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
      await client.auth.signInWithPassword(
        email: 'test@example.invalid',
        password: 'test-only',
      );
      final source = SupabasePaymentSource(client);
      final params = {
        'p_request_id': 'request',
        'p_payment_id': 'payment',
        'p_amount_received': '9007199254740993',
        'p_expected_version': '1',
        'p_operation_id': 'operation',
      };
      await source.confirmCash(params);
      expect(
        requests.last.url.path,
        endsWith('/rpc/rescuer_confirm_cash_received'),
      );
      expect(jsonDecode(requests.last.body), params);
      expect(requests.last.headers['Authorization'], 'Bearer test-token');
      await client.dispose();
    },
  );

  for (final width in [320.0, 390.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'cash and confirmation fit width $width at text scale $scale',
        (tester) async {
          final source = CashSource();
          await mountCash(tester, source, width: width, scale: scale);
          expect(find.text('100.000'), findsOneWidget);
          expect(find.byType(TextField), findsNothing);
          final collect = find.byKey(const ValueKey('collect-cash'));
          await tester.scrollUntilVisible(
            collect,
            300,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.tap(collect);
          await tester.pumpAndSettle();
          expect(find.text('Xác nhận đã nhận tiền?'), findsOneWidget);
          final confirm = find.byKey(const ValueKey('confirm-cash'));
          await tester.ensureVisible(confirm);
          expect(tester.takeException(), isNull);
          await tester.tap(confirm);
          await tester.pumpAndSettle();
          expect(find.text('Đã nhận tiền mặt'), findsOneWidget);
          expect(
            find.text('Đã xác nhận nhận đủ tiền mặt từ khách hàng.'),
            findsOneWidget,
          );
          await tester.scrollUntilVisible(
            find.text('Xem chi tiết chuyến'),
            300,
            scrollable: find.byType(Scrollable).first,
          );
          expect(find.byKey(const ValueKey('collect-cash')), findsNothing);
          expect(tester.takeException(), isNull);
          await unmount(tester, source);
        },
      );
    }
  }

  testWidgets('bank reference has read only status and no cash action', (
    tester,
  ) async {
    final source = CashSource()
      ..row = {...dto(status: 'awaiting_payment'), 'method': 'bank_transfer'};
    await mountCash(tester, source, width: 320, scale: 2);
    expect(find.text('Đang chờ hệ thống xác minh'), findsOneWidget);
    expect(find.byKey(const ValueKey('collect-cash')), findsNothing);
    expect(find.byKey(const ValueKey('confirm-cash')), findsNothing);
    expect(tester.takeException(), isNull);
    await unmount(tester, source);
  });

  testWidgets('submitting blocks repeated taps, cancellation and back', (
    tester,
  ) async {
    final source = CashSource()..gate = Completer<void>();
    await mountCash(tester, source);
    final collect = find.byKey(const ValueKey('collect-cash'));
    await tester.scrollUntilVisible(
      collect,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(collect);
    await tester.pumpAndSettle();
    final confirm = find.byKey(const ValueKey('confirm-cash'));
    await tester.ensureVisible(confirm);
    final point = tester.getCenter(confirm);
    await tester.tapAt(point);
    await tester.tapAt(point);
    await tester.pump(const Duration(milliseconds: 400));
    expect(source.calls, hasLength(1));
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('cash-processing')),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    final processing = tester.widget<RescueButton>(
      find.byKey(const ValueKey('cash-processing')),
    );
    expect(processing.onPressed, isNull);
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.byType(RescuerCashScreen), findsOneWidget);
    source.gate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Đã nhận tiền mặt'), findsOneWidget);
    await unmount(tester, source);
  });

  testWidgets(
    'offline, unavailable and backend error show retry without paid',
    (tester) async {
      for (final mode in ['offline', 'unavailable', 'error']) {
        final source = CashSource();
        if (mode == 'unavailable') source.row = null;
        if (mode == 'error') source.failure = TimeoutException('timeout');
        await mountCash(tester, source, width: 320, scale: 2);
        if (mode == 'offline') {
          source.emit(PaymentSignalKind.disconnected);
          await tester.pump();
          await tester.pump();
        }
        expect(find.text('Thử lại'), findsOneWidget, reason: mode);
        expect(find.text('Đã nhận tiền mặt'), findsNothing);
        expect(find.byKey(const ValueKey('collect-cash')), findsNothing);
        expect(tester.takeException(), isNull);
        await unmount(tester, source);
      }
    },
  );

  testWidgets('loading and null paid metadata never fabricate values', (
    tester,
  ) async {
    final source = CashSource();
    final gate = Completer<Map<String, dynamic>?>();
    source.loader = (_) => gate.future;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: RescueTheme.light,
        home: RescuerCashScreen(controller: controller(source)),
      ),
    );
    await tester.pump();
    expect(find.text('Đang tải thanh toán'), findsOneWidget);
    expect(find.byKey(const ValueKey('collect-cash')), findsNothing);
    source.emit(PaymentSignalKind.connected);
    gate.complete({
      ...dto(status: 'paid', version: '2'),
      'amount_received': null,
      'cash_received_at': null,
      'paid_at': null,
    });
    await tester.pumpAndSettle();
    expect(find.text('Chưa có số tiền'), findsOneWidget);
    expect(find.text('Chưa có thời gian xác nhận'), findsOneWidget);
    expect(find.text('Chưa có mã'), findsOneWidget);
    await unmount(tester, source);
  });
}
