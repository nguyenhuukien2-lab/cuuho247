import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rescuer/app/rescuer_controller.dart';
import 'package:rescuer/models/backend_models.dart';
import 'package:rescuer/screens/preparation/job_finance_section.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'claim_request_test.dart' show RpcHarness;
import 'connected_app_test.dart' show FakeLocation, mount;
import 'job_status_test.dart' show JobFake, start;

class FinanceFake extends JobFake {
  FinanceFake() {
    state = 'in_progress';
    version = 4;
  }
  String? quoteId;
  int? total;
  bool lostQuote = false, lostCompletion = false, cancelInstead = false;
  Object? historyFailure;
  Completer<void>? gate;
  @override
  Json get data => {
    ...super.data,
    'service_type': 'tire',
    'vehicle_type': 'car',
    'current_quote_id': quoteId,
    'completion_quote_id': state == 'completed' ? quoteId : null,
    'total_vnd': total,
    'currency': 'VND',
    if (state == 'completed') 'completed_at': '2026-10-03T02:00:00Z',
  };
  @override
  Future<Json> mutate(String name, Json params) async {
    if (name != 'rescuer_create_quote' && name != 'rescuer_update_job_status') {
      return super.mutate(name, params);
    }
    calls.add((name, params));
    if (name == failedMutation) throw mutationFailure!;
    if (gate != null) await gate!.future;
    version++;
    if (name == 'rescuer_create_quote') {
      quoteId = 'quote';
      total = (params['p_items'] as List).fold<int>(
        0,
        (sum, item) => sum + item['unit_price_vnd'] as int,
      );
      if (lostQuote) throw http.ClientException('lost response');
      return {
        'quote_id': quoteId,
        'assignment_id': 'assignment',
        'status': 'issued',
        'currency': 'VND',
        'total_vnd': total,
        'assignment_version': version,
        'items': params['p_items'],
        'note': params['p_note'],
      };
    }
    state = cancelInstead ? 'cancelled' : 'completed';
    missingJob = true;
    if (lostCompletion) throw http.ClientException('lost response');
    return data;
  }

  @override
  Future<HistoryPage> history({Json? cursor}) async {
    if (historyFailure != null) throw historyFailure!;
    return HistoryPage(
      ['completed', 'cancelled'].contains(state)
          ? [HistoryJob.fromJson(data)]
          : [],
      null,
    );
  }

  @override
  Future<HistoryJob> historyJob(String assignmentId) async {
    if (historyFailure != null) throw historyFailure!;
    return HistoryJob.fromJson(data);
  }
}

void main() {
  test(
    'validates required integer VND, bounds, optional surcharge and note',
    () {
      for (final input in ['', '-1', '1.5', '1,000', '2147483648']) {
        expect(
          () => QuoteDraft.parse(input, '', ''),
          throwsA(isA<RescuerFailure>()),
        );
      }
      expect(
        () => QuoteDraft.parse('1', '-1', ''),
        throwsA(isA<RescuerFailure>()),
      );
      expect(
        () => QuoteDraft.parse('2147483647', '1', ''),
        throwsA(isA<RescuerFailure>()),
      );
      expect(
        () => QuoteDraft.parse('0', '', 'x' * 1001),
        throwsA(isA<RescuerFailure>()),
      );
      final zero = QuoteDraft.parse('0', '', '  ghi chú  ');
      expect(zero.total, 0);
      expect(zero.note, 'ghi chú');
      expect(zero.items('tire'), [
        {'service_code': 'tire', 'quantity': 1, 'unit_price_vnd': 0},
      ]);
    },
  );

  test(
    'quote uses request service and current version, then blocks revisions',
    () async {
      final s = FinanceFake();
      final c = await start(s);
      await c.sendQuote(QuoteDraft.parse('100000', '20000', '  Vá lốp  '));
      expect(c.error, isNull);
      expect(s.calls.single.$1, 'rescuer_create_quote');
      expect(s.calls.single.$2, {
        'p_assignment_id': 'assignment',
        'p_items': [
          {'service_code': 'tire', 'quantity': 1, 'unit_price_vnd': 100000},
          {'service_code': 'tire', 'quantity': 1, 'unit_price_vnd': 20000},
        ],
        'p_note': 'Vá lốp',
        'p_expected_version': 4,
      });
      expect(c.currentQuote?.note, 'Vá lốp');
      expect(c.activeJob?.assignment.totalVnd, 120000);
      expect(c.canSendQuote, isFalse);
      expect(c.canCompleteJob, isTrue);
      await c.sendQuote(const QuoteDraft(1, 0, ''));
      expect(s.calls.length, 1);
    },
  );

  test(
    'lost quote response reconciles server total without a second mutation',
    () async {
      final s = FinanceFake()..lostQuote = true;
      final c = await start(s);
      await c.sendQuote(const QuoteDraft(0, 0, ''));
      expect(c.error, isNull);
      expect(c.activeJob?.assignment.hasQuote, isTrue);
      expect(
        c.currentQuote,
        isNull,
      ); // No fabricated note/items after lost receipt.
      expect(s.calls.length, 1);
    },
  );

  test('server conflict reloads existing quote but remains an error', () async {
    final s = FinanceFake();
    final c = await start(s);
    s.quoteId = 'other-quote';
    s.total = 200;
    s.version++;
    s.failedMutation = 'rescuer_create_quote';
    s.mutationFailure = const PostgrestException(
      message: 'VERSION_CONFLICT',
      code: 'P0001',
    );
    await c.sendQuote(const QuoteDraft(100, 0, ''));
    expect(c.jobUpdateFailed, isTrue);
    expect(c.activeJob?.assignment.currentQuoteId, 'other-quote');
    expect(c.canSendQuote, isFalse);
    expect(s.calls.length, 1);
  });

  test('completion requires a quote and a current confirmation', () async {
    final s = FinanceFake();
    final c = await start(s);
    await c.completeJob(c.activeJob!.assignment);
    expect(s.calls, isEmpty);
    await c.sendQuote(const QuoteDraft(100, 0, ''));
    final confirmed = c.activeJob!.assignment;
    s.version++;
    s.total = 500;
    await c.refreshActiveJob();
    await c.completeJob(confirmed);
    expect(s.calls.length, 1);
    expect(c.completionSuccessSerial, 0);
  });

  test(
    'completion clears active PII and loads authoritative history',
    () async {
      final s = FinanceFake()
        ..quoteId = 'quote'
        ..total = 0;
      final c = await start(s);
      await c.completeJob(c.activeJob!.assignment);
      expect(s.calls.single.$2, {
        'p_assignment_id': 'assignment',
        'p_target_state': 'completed',
        'p_reason_code': null,
        'p_expected_version': 4,
      });
      expect(c.activeJob, isNull);
      expect(c.currentQuote, isNull);
      expect(c.claimedAssignment, isNull);
      expect(c.tab, 3);
      expect(c.historyItems.single.assignment.state, 'completed');
      expect(c.historyItems.single.assignment.totalVnd, 0);
      expect(c.completionSuccessSerial, 1);
    },
  );

  test('lost completion reply reconciles exact historical quote', () async {
    final s = FinanceFake()
      ..quoteId = 'quote'
      ..total = 100
      ..lostCompletion = true;
    final c = await start(s);
    await c.completeJob(c.activeJob!.assignment);
    expect(c.completionSuccessSerial, 1);
    expect(c.error, isNull);
    expect(s.calls.length, 1);
  });

  test(
    'missing active job due to cancellation is not successful completion',
    () async {
      final s = FinanceFake()
        ..quoteId = 'quote'
        ..total = 100
        ..lostCompletion = true
        ..cancelInstead = true;
      final c = await start(s);
      await c.completeJob(c.activeJob!.assignment);
      expect(c.completionSuccessSerial, 0);
      expect(c.error, isNotNull);
      expect(c.activeJob, isNull);
    },
  );

  test(
    'history RLS failure does not invent history or undo completed ACK',
    () async {
      final s = FinanceFake()
        ..quoteId = 'quote'
        ..total = 100
        ..historyFailure = const PostgrestException(
          message: 'permission denied',
          code: '42501',
        );
      final c = await start(s);
      await c.completeJob(c.activeJob!.assignment);
      expect(c.completionSuccessSerial, 1);
      expect(c.historyStatus, FeedStatus.error);
      expect(c.historyItems, isEmpty);
      expect(c.historyError, isNotNull);
      expect(c.jobUpdateFailed, isFalse);
    },
  );

  test(
    'completion RLS rejects mutation and retains authoritative active job',
    () async {
      final s = FinanceFake()
        ..quoteId = 'quote'
        ..total = 100
        ..failedMutation = 'rescuer_update_job_status'
        ..mutationFailure = const PostgrestException(
          message: 'permission denied',
          code: '42501',
        );
      final c = await start(s);
      await c.completeJob(c.activeJob!.assignment);
      expect(c.jobUpdateFailed, isTrue);
      expect(c.completionSuccessSerial, 0);
      expect(c.activeJob?.assignment.state, 'in_progress');
    },
  );

  test('concurrent quote taps perform only one mutation', () async {
    final s = FinanceFake()..gate = Completer<void>();
    final c = await start(s);
    final pending = c.sendQuote(const QuoteDraft(100, 0, ''));
    await Future<void>.delayed(Duration.zero);
    expect(c.sendingQuote, isTrue);
    expect(c.canSendQuote, isFalse);
    await c.sendQuote(const QuoteDraft(100, 0, ''));
    s.gate!.complete();
    await pending;
    expect(s.calls.length, 1);
  });

  test(
    'RPC quote operation UUID survives lost transport and history uses cursor',
    () async {
      final requests = <(String, Json)>[];
      var fail = true;
      final cursor = {
        'accepted_at': '2026-10-03T01:00:00Z',
        'assignment_id': 'assignment',
      };
      final mock = MockClient((request) async {
        final body = Json.from(jsonDecode(request.body) as Map);
        requests.add((request.url.path, body));
        if (request.url.path.endsWith('rescuer_create_quote') && fail) {
          fail = false;
          throw http.ClientException('lost');
        }
        return http.Response(
          jsonEncode(
            request.url.path.endsWith('rescuer_list_job_history')
                ? {'items': [], 'next_cursor': null}
                : {},
          ),
          200,
          request: request,
          headers: {'content-type': 'application/json'},
        );
      });
      final client = SupabaseClient(
        'https://example.supabase.co',
        'anon-key',
        httpClient: mock,
      );
      addTearDown(client.dispose);
      final service = RpcHarness(client);
      final params = {
        'p_assignment_id': 'assignment',
        'p_expected_version': 4,
        'p_note': null,
        'p_items': const QuoteDraft(100, 0, '').items('tire'),
      };
      await expectLater(
        service.mutate('rescuer_create_quote', params),
        throwsA(isA<http.ClientException>()),
      );
      await service.mutate('rescuer_create_quote', params);
      expect(
        requests[0].$2['p_operation_id'],
        requests[1].$2['p_operation_id'],
      );
      expect(requests[0].$2['p_operation_id'], isNotEmpty);
      await service.history(cursor: cursor);
      expect(requests.last.$1, '/rest/v1/rpc/rescuer_list_job_history');
      expect(requests.last.$2, {
        'p_limit': 20,
        'p_cursor': cursor,
        'p_state_filter': null,
      });
    },
  );

  testWidgets(
    'phone quote validates and sends, confirmation can cancel then complete',
    (tester) async {
      final s = FinanceFake();
      final c = RescuerController(s, FakeLocation());
      addTearDown(() async => s.changes.close());
      await mount(tester, c);
      // Mount starts controller and restores the active tab.
      expect(c.tab, 2);
      final openQuote = find.byKey(const ValueKey('open-quote'));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('active-job-header')),
          matching: openQuote,
        ),
        findsOneWidget,
      );
      expect(find.text('Chưa có báo giá'), findsOneWidget);
      await tester.tap(openQuote);
      await tester.pumpAndSettle();
      expect(s.calls, isEmpty);
      expect(
        tester
            .getRect(find.byType(ListView))
            .contains(
              tester.getCenter(find.byKey(const ValueKey('quote-main'))),
            ),
        isTrue,
      );
      Future<void> showKey(String key) async {
        await tester.pumpAndSettle();
        final finder = find.byKey(ValueKey(key));
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
      }

      await showKey('send-quote');
      await tester.tap(find.byKey(const ValueKey('send-quote')));
      await tester.pumpAndSettle();
      expect(find.text('Nhập phí dịch vụ chính.'), findsOneWidget);
      expect(s.calls, isEmpty);
      await tester.enterText(
        find.byKey(const ValueKey('quote-main')),
        '100000',
      );
      await tester.enterText(
        find.byKey(const ValueKey('quote-extra')),
        '20000',
      );
      await showKey('send-quote');
      await tester.tap(find.byKey(const ValueKey('send-quote')));
      await tester.pumpAndSettle();
      expect(find.text('Báo giá đã gửi'), findsOneWidget);
      expect(find.text('120.000 ₫'), findsOneWidget);
      expect(find.text('Tổng báo giá'), findsOneWidget);
      expect(find.byKey(const ValueKey('open-quote')), findsNothing);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('active-job-header')),
          matching: find.byKey(const ValueKey('complete-job')),
        ),
        findsOneWidget,
      );
      await showKey('complete-job');
      await tester.tap(find.byKey(const ValueKey('complete-job')));
      await tester.pumpAndSettle();
      expect(find.byType(CompleteJobDialog), findsOneWidget);
      expect(find.text('Chi phí: 120.000 ₫'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(
              find.descendant(
                of: find.byType(CompleteJobDialog),
                matching: find.byType(TextField),
              ),
            )
            .enabled,
        isFalse,
      );
      await tester.tap(find.text('Quay lại'));
      await tester.pumpAndSettle();
      expect(s.calls.length, 1);
      await tester.tap(find.byKey(const ValueKey('complete-job')));
      await tester.pumpAndSettle();
      s.gate = Completer<void>();
      await tester.tap(find.byKey(const ValueKey('confirm-completion')));
      await tester.pump();
      expect(c.completingJob, isTrue);
      await tester.tap(find.byKey(const ValueKey('confirm-completion')));
      await tester.pump();
      expect(s.calls.length, 2);
      s.gate!.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CompleteJobDialog), findsNothing);
      expect(c.tab, 3);
      expect(find.byKey(const ValueKey('history-assignment')), findsOneWidget);
      expect(find.text('0901234567'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
}
