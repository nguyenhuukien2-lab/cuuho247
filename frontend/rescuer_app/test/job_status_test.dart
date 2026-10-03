import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rescuer/app/rescuer_controller.dart';
import 'package:rescuer/models/backend_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'connected_app_test.dart'
    show FakeService, FakeLocation, approved, mount;
import 'claim_request_test.dart' show RpcHarness;

class JobFake extends FakeService {
  JobFake() {
    userId = 'rescuer';
    snapshot = approved();
  }
  String state = 'accepted';
  int version = 1;
  bool missingJob = false, loseResponse = false, denyReadAfterUpdate = false;
  Object? jobFailure;
  Completer<Json>? pendingUpdate;
  Json get data => {
    'assignment_id': 'assignment',
    'request_id': 'request',
    'vehicle_id': 'vehicle',
    'state': state,
    'version': version,
    'accepted_at': '2026-10-03T01:00:00Z',
    if (version >= 2) 'en_route_at': '2026-10-03T01:10:00Z',
    if (version >= 3) 'arrived_at': '2026-10-03T01:20:00Z',
    if (version >= 4) 'in_progress_at': '2026-10-03T01:30:00Z',
    'contact_name': 'Khách chuyến đã nhận',
    'contact_phone': '0901234567',
  };
  @override
  Future<ActiveJob?> getActiveJob() async {
    if (jobFailure != null) throw jobFailure!;
    return missingJob ? null : ActiveJob.fromJson(data);
  }

  @override
  Future<Json> mutate(String name, Json params) async {
    final result = await super.mutate(name, params);
    if (name != 'rescuer_update_job_status') return result;
    if (pendingUpdate != null) return pendingUpdate!.future;
    state = params['p_target_state'] as String;
    version++;
    if (denyReadAfterUpdate) {
      jobFailure = const PostgrestException(
        message: 'permission denied',
        code: '42501',
      );
    }
    if (loseResponse) throw http.ClientException('lost response');
    return data;
  }
}

Future<RescuerController> start(JobFake service) async {
  final c = RescuerController(service, FakeLocation())..start();
  addTearDown(() async {
    c.dispose();
    await service.changes.close();
  });
  await Future<void>.delayed(Duration.zero);
  return c;
}

Future<void> showAction(WidgetTester tester) async {
  await tester.pumpAndSettle();
  final action = find.byKey(const ValueKey('advance-job'));
  final viewport = tester.getRect(find.byType(ListView));
  final center = tester.getCenter(action);
  if (!viewport.contains(center)) {
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable).first)
        .position;
    position.jumpTo(
      (position.pixels + center.dy - viewport.center.dy).clamp(
        0.0,
        position.maxScrollExtent,
      ),
    );
    await tester.pumpAndSettle();
  }
  expect(
    viewport.contains(tester.getCenter(action)),
    isTrue,
    reason: 'viewport=$viewport center=${tester.getCenter(action)}',
  );
}

void main() {
  test(
    'advances exactly three steps with server versions and no completion',
    () async {
      final service = JobFake();
      final c = await start(service);
      expect(
        c.online,
        isFalse,
      ); // Active-job RPC does not require discovery online.
      for (final (target, version) in [
        ('en_route', 1),
        ('arrived', 2),
        ('in_progress', 3),
      ]) {
        await c.advanceJob();
        expect(service.calls.last.$1, 'rescuer_update_job_status');
        expect(service.calls.last.$2, {
          'p_assignment_id': 'assignment',
          'p_target_state': target,
          'p_reason_code': null,
          'p_expected_version': version,
        });
        expect(c.activeJob?.assignment.state, target);
        expect(c.activeJob?.assignment.version, version + 1);
        expect(c.error, isNull);
      }
      expect(c.jobUpdateSerial, 3);
      expect(
        c.activeJob?.assignment.inProgressAt,
        DateTime.parse('2026-10-03T01:30:00Z'),
      );
      expect(c.canAdvanceJob, isFalse);
      await c.advanceJob();
      expect(service.calls.length, 3);
      expect(
        service.calls.every((x) => x.$1 == 'rescuer_update_job_status'),
        isTrue,
      );
    },
  );

  test(
    'version conflict reloads latest job without auto skipping another step',
    () async {
      final service = JobFake();
      final c = await start(service);
      service.state = 'en_route';
      service.version = 2;
      service.failedMutation = 'rescuer_update_job_status';
      service.mutationFailure = const PostgrestException(
        message: 'VERSION_CONFLICT',
        code: 'P0001',
      );
      await c.advanceJob();
      expect(service.calls.length, 1);
      expect(service.calls.single.$2['p_expected_version'], 1);
      expect(c.activeJob?.assignment.state, 'en_route');
      expect(c.activeJob?.assignment.nextState, 'arrived');
      expect(c.error, contains('phiên khác'));
      expect(c.jobUpdateFailed, isTrue);
      service.failedMutation = null;
      await c.advanceJob();
      expect(service.calls.last.$2['p_expected_version'], 2);
      expect(c.activeJob?.assignment.state, 'arrived');
    },
  );

  test(
    'invalid transition remains a readable error with refreshed job',
    () async {
      final service = JobFake();
      final c = await start(service);
      service.failedMutation = 'rescuer_update_job_status';
      service.mutationFailure = const PostgrestException(
        message: 'INVALID_STATUS_TRANSITION',
        code: '22023',
      );
      await c.advanceJob();
      expect(c.activeJob?.assignment.state, 'accepted');
      expect(c.error, contains('Không thể chuyển'));
      expect(c.jobUpdateFailed, isTrue);
      expect(service.calls.length, 1);
    },
  );

  test(
    'lost response reconciles committed progress using authoritative version',
    () async {
      final service = JobFake()..loseResponse = true;
      final c = await start(service);
      await c.advanceJob();
      expect(c.activeJob?.assignment.state, 'en_route');
      expect(c.activeJob?.assignment.version, 2);
      expect(c.error, isNull);
      expect(c.jobUpdateFailed, isFalse);
      expect(service.calls.length, 1);
    },
  );

  test(
    'acknowledged progress remains safe when subsequent detail read fails',
    () async {
      final service = JobFake()..denyReadAfterUpdate = true;
      final c = await start(service);
      await c.advanceJob();
      expect(c.claimedAssignment?.state, 'en_route');
      expect(c.claimedAssignment?.version, 2);
      expect(c.activeJob, isNull);
      expect(c.jobStatus, JobStatus.error);
      expect(c.jobError, contains('RLS'));
      expect(c.canAdvanceJob, isFalse);
      expect(c.jobUpdateFailed, isFalse);
    },
  );

  test(
    'unavailable assignment clears details and never mutates another job',
    () async {
      final service = JobFake();
      final c = await start(service);
      service.missingJob = true;
      service.failedMutation = 'rescuer_update_job_status';
      service.mutationFailure = const PostgrestException(
        message: 'REQUEST_UNAVAILABLE',
        code: 'P0001',
      );
      await c.advanceJob();
      expect(c.activeJob, isNull);
      expect(c.claimedAssignment, isNull);
      expect(c.error, contains('không còn đang xử lý'));
      expect(c.canAdvanceJob, isFalse);
    },
  );

  test(
    'late update cannot restore job data or notifications after logout',
    () async {
      final service = JobFake()..pendingUpdate = Completer<Json>();
      final c = await start(service);
      final update = c.advanceJob();
      await Future<void>.delayed(Duration.zero);
      await service.signOut();
      service.state = 'en_route';
      service.version = 2;
      service.pendingUpdate!.complete(service.data);
      await update;
      expect(c.activeJob, isNull);
      expect(c.claimedAssignment, isNull);
      expect(c.updatingJobState, isNull);
      expect(c.jobUpdateMessage, isNull);
      expect(c.jobUpdateSerial, 0);
    },
  );

  testWidgets(
    'timeline action loads, blocks duplicates then ends at supporting state',
    (tester) async {
      final service = JobFake();
      final c = RescuerController(service, FakeLocation());
      addTearDown(() => service.changes.close());
      await mount(tester, c);
      expect(find.byKey(const ValueKey('job-step-accepted')), findsOneWidget);
      expect(
        find.text('Cập nhật trạng thái để khách hàng theo dõi tiến độ'),
        findsOneWidget,
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('advance-job')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await showAction(tester);
      service.pendingUpdate = Completer<Json>();
      await tester.tap(find.byKey(const ValueKey('advance-job')));
      await tester.pump();
      expect(find.text('Đang cập nhật…'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const ValueKey('advance-job')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
      await c.advanceJob();
      expect(service.calls.length, 1);
      service.state = 'en_route';
      service.version = 2;
      service.pendingUpdate!.complete(service.data);
      service.pendingUpdate = null;
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text('Đã cập nhật: Đang đến điểm cứu hộ.'),
        ),
        findsOneWidget,
      );
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      await showAction(tester);
      await tester.tap(find.byKey(const ValueKey('advance-job')));
      await tester.pumpAndSettle();
      expect(c.activeJob?.assignment.state, 'arrived');
      await showAction(tester);
      await tester.tap(find.byKey(const ValueKey('advance-job')));
      await tester.pumpAndSettle();
      expect(c.activeJob?.assignment.state, 'in_progress');
      expect(find.byKey(const ValueKey('advance-job')), findsNothing);
      expect(find.byIcon(Icons.check_rounded), findsNWidgets(3));
      expect(find.text('Đang hỗ trợ khách'), findsWidgets);
      expect(find.text('Hoàn tất chuyến'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'RLS update error shows snackbar, clears PII and disables stale action',
    (tester) async {
      final service = JobFake();
      final c = RescuerController(service, FakeLocation());
      addTearDown(() => service.changes.close());
      await mount(tester, c);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('advance-job')),
        250,
        scrollable: find.byType(Scrollable).first,
      );
      await showAction(tester);
      service.failedMutation = 'rescuer_update_job_status';
      service.mutationFailure = const PostgrestException(
        message: 'permission denied',
        code: '42501',
      );
      service.jobFailure = service.mutationFailure;
      await tester.tap(find.byKey(const ValueKey('advance-job')));
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text(c.jobUpdateMessage!),
        ),
        findsOneWidget,
      );
      expect(c.jobUpdateMessage, contains('RLS'));
      expect(c.activeJob, isNull);
      expect(find.text('0901234567'), findsNothing);
      expect(c.canAdvanceJob, isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  test(
    'status RPC retry preserves UUID and sends exact version/nullable reason',
    () async {
      final payloads = <Json>[];
      final httpClient = MockClient((request) async {
        expect(request.url.path, '/rest/v1/rpc/rescuer_update_job_status');
        payloads.add(Json.from(jsonDecode(request.body) as Map));
        if (payloads.length == 1) throw http.ClientException('lost response');
        return http.Response(
          jsonEncode({
            'assignment_id': 'assignment',
            'request_id': 'request',
            'vehicle_id': 'vehicle',
            'state': 'en_route',
            'version': 2,
          }),
          200,
          headers: {'content-type': 'application/json'},
          request: request,
        );
      });
      final client = SupabaseClient(
        'https://example.supabase.co',
        'sb_publishable_example',
        httpClient: httpClient,
      );
      final service = RpcHarness(client);
      final params = {
        'p_assignment_id': 'assignment',
        'p_target_state': 'en_route',
        'p_reason_code': null,
        'p_expected_version': 1,
      };
      await expectLater(
        service.mutate('rescuer_update_job_status', params),
        throwsA(isA<http.ClientException>()),
      );
      await service.mutate('rescuer_update_job_status', params);
      expect(payloads[0], payloads[1]);
      expect(payloads[0].keys.toSet(), {...params.keys, 'p_operation_id'});
      expect(payloads[0]['p_operation_id'], isNotEmpty);
      for (final target in ['completed', 'cancelled', 'accepted', 'arriving']) {
        await expectLater(
          service.mutate('rescuer_update_job_status', {
            ...params,
            'p_target_state': target,
          }),
          throwsA(isA<RescuerFailure>()),
        );
      }
      expect(payloads.length, 2);
      await client.dispose();
      httpClient.close();
    },
  );
}
