import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rescuer/app/rescuer_controller.dart';
import 'package:rescuer/models/backend_models.dart';
import 'package:rescuer/services/rescuer_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'connected_app_test.dart'
    show FakeService, FakeLocation, approved, mount;

const request = AvailableRequest(
  id: 'request',
  service: 'tire',
  vehicle: 'car',
  latitude: 10.775,
  longitude: 106.695,
  distanceKm: 2,
);

Json assignmentJson() => {
  'assignment_id': 'assignment',
  'request_id': request.id,
  'vehicle_id': 'vehicle',
  'state': 'accepted',
  'version': 1,
  'accepted_at': '2026-10-03T01:00:00Z',
};
ActiveJob job() => ActiveJob.fromJson({
  ...assignmentJson(),
  'service_type': 'tire',
  'vehicle_type': 'car',
  'contact_name': 'Khách sau nhận',
  'contact_phone': '0901234567',
  'location_text': 'Điểm cứu hộ chính xác',
  'latitude': 10.771234,
  'longitude': 106.691234,
  'description': 'Lốp xe bị thủng',
});

class ClaimFake extends FakeService {
  ClaimFake() {
    userId = 'rescuer';
    snapshot = approved();
    page = const RequestPage([request], null);
  }
  ActiveJob? currentJob;
  Object? jobFailure;
  Completer<ActiveJob?>? pendingJob;
  Completer<Json>? pendingClaim;
  bool loseClaimResponse = false;
  int jobReads = 0;

  @override
  Future<ActiveJob?> getActiveJob() async {
    jobReads++;
    if (jobFailure != null) throw jobFailure!;
    if (pendingJob != null) return pendingJob!.future;
    return currentJob;
  }

  @override
  Future<Json> mutate(String name, Json params) async {
    final result = await super.mutate(name, params);
    if (name != 'rescuer_claim_request') return result;
    if (pendingClaim != null) return pendingClaim!.future;
    currentJob = job();
    page = const RequestPage([], null);
    feedFailure = const PostgrestException(
      message: 'RESCUER_BUSY',
      code: 'P0001',
    );
    if (loseClaimResponse) throw http.ClientException('response lost');
    return assignmentJson();
  }
}

Future<RescuerController> start(ClaimFake service) async {
  final c = RescuerController(service, FakeLocation())..start();
  addTearDown(() async {
    c.dispose();
    await service.changes.close();
  });
  await Future<void>.delayed(Duration.zero);
  return c;
}

class RpcHarness extends SupabaseRescuerService {
  RpcHarness(super.client);
  @override
  String? get userId => 'rescuer';
}

void main() {
  test(
    'successful claim retains safe assignment when details RPC denies access',
    () async {
      final service = ClaimFake();
      final c = await start(service);
      await c.setOnline(true);
      service.jobFailure = const PostgrestException(
        message: 'permission denied',
        code: '42501',
      );
      await c.claimRequest(request);
      expect(c.claimSuccessSerial, 1);
      expect(c.claimedAssignment?.id, 'assignment');
      expect(c.activeJob, isNull);
      expect(c.jobStatus, JobStatus.error);
      expect(c.jobError, contains('RLS'));
      expect(c.requests, isEmpty);
      expect(c.canClaim, isFalse);
    },
  );

  test('busy error recovers the job claimed in another session', () async {
    final service = ClaimFake();
    final c = await start(service);
    await c.setOnline(true);
    service.currentJob = ActiveJob.fromJson({
      ...assignmentJson(),
      'request_id': 'other-request',
    });
    service.failedMutation = 'rescuer_claim_request';
    service.mutationFailure = const PostgrestException(
      message: 'RESCUER_BUSY',
      code: 'P0001',
    );
    await c.claimRequest(request);
    expect(c.activeJob?.assignment.requestId, 'other-request');
    expect(c.tab, 2);
    expect(c.error, contains('chuyến đang xử lý'));
    expect(c.requests, isEmpty);
    expect(c.claimSuccessSerial, 0);
  });

  test('claim uses selected vehicle, opens assigned job, refreshes feed and suppresses busy', () async {
    final service = ClaimFake();
    final c = await start(service);
    await c.setOnline(true);
    final beforeFeed = service.calls
        .where((x) => x.$1 == 'rescuer_list_available_requests')
        .length;
    await c.claimRequest(request);
    expect(
      service.calls.where((x) => x.$1 == 'rescuer_claim_request').single.$2,
      {'p_request_id': 'request', 'p_vehicle_id': 'vehicle'},
    );
    expect(c.tab, 2);
    expect(c.activeJob?.contactPhone, '0901234567');
    expect(c.requests, isEmpty);
    expect(c.error, isNull);
    expect(c.claimSuccessSerial, 1);
    expect(
      service.calls
          .where((x) => x.$1 == 'rescuer_list_available_requests')
          .length,
      beforeFeed + 1,
    );
    final claims = service.calls
        .where((x) => x.$1 == 'rescuer_claim_request')
        .length;
    await c.claimRequest(request);
    expect(
      service.calls.where((x) => x.$1 == 'rescuer_claim_request').length,
      claims,
    );
  });

  test(
    'competing claim gives readable error and refreshes unavailable card away',
    () async {
      final service = ClaimFake();
      final c = await start(service);
      await c.setOnline(true);
      service.failedMutation = 'rescuer_claim_request';
      service.mutationFailure = const PostgrestException(
        message: 'REQUEST_UNAVAILABLE',
        code: 'P0001',
      );
      service.page = const RequestPage([], null);
      await c.claimRequest(request);
      expect(c.error, contains('Đơn đã có người nhận'));
      expect(c.hasActiveJob, isFalse);
      expect(c.requests, isEmpty);
      expect(c.claimSuccessSerial, 0);
    },
  );

  test(
    'lost response reconciles authoritative job without repeating claim',
    () async {
      final service = ClaimFake()..loseClaimResponse = true;
      final c = await start(service);
      await c.setOnline(true);
      await c.claimRequest(request);
      expect(c.error, isNull);
      expect(c.hasActiveJob, isTrue);
      expect(c.tab, 2);
      expect(c.claimSuccessSerial, 1);
      expect(
        service.calls.where((x) => x.$1 == 'rescuer_claim_request').length,
        1,
      );
    },
  );

  test(
    'job restores while offline; revoked and failed reads clear cached PII',
    () async {
      final service = ClaimFake()..currentJob = job();
      final c = await start(service);
      expect(c.online, isFalse);
      expect(c.tab, 2);
      expect(c.activeJob?.contactName, 'Khách sau nhận');
      service.jobFailure = const PostgrestException(
        message: 'permission denied',
        code: '42501',
      );
      await c.refreshActiveJob();
      expect(c.activeJob, isNull);
      expect(c.jobStatus, JobStatus.error);
      expect(c.jobError, contains('RLS'));
      expect(c.canClaim, isFalse);
      service.jobFailure = null;
      service.currentJob = null;
      await c.refreshActiveJob();
      expect(c.hasActiveJob, isFalse);
      expect(c.jobStatus, JobStatus.empty);
    },
  );

  test('profile read failure also removes cached customer details', () async {
    final service = ClaimFake()..currentJob = job();
    final c = await start(service);
    service.readFailure = const PostgrestException(
      message: 'permission denied',
      code: '42501',
    );
    await c.refreshProfile();
    expect(c.activeJob, isNull);
    expect(c.jobStatus, JobStatus.error);
  });

  test('late active-job response cannot restore PII after logout', () async {
    final service = ClaimFake();
    final c = await start(service);
    service.pendingJob = Completer<ActiveJob?>();
    final refresh = c.refreshActiveJob();
    await Future<void>.delayed(Duration.zero);
    await service.signOut();
    service.pendingJob!.complete(job());
    await refresh;
    expect(c.signedIn, isFalse);
    expect(c.activeJob, isNull);
    expect(c.claimedAssignment, isNull);
  });

  testWidgets(
    'claim button loads, disables duplicate tap and shows postclaim details/snackbar',
    (tester) async {
      final service = ClaimFake();
      final c = RescuerController(service, FakeLocation());
      addTearDown(() => service.changes.close());
      await mount(tester, c);
      await c.setOnline(true);
      c.selectTab(1);
      await tester.pumpAndSettle();
      expect(find.text('Khách sau nhận'), findsNothing);
      expect(find.text('0901234567'), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('claim-request')),
        250,
      );
      service.pendingClaim = Completer<Json>();
      await tester.tap(find.byKey(const ValueKey('claim-request')));
      await tester.pump();
      expect(find.text('Đang nhận đơn…'), findsOneWidget);
      final claimButton = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const ValueKey('claim-request')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(claimButton.onPressed, isNull);
      await c.claimRequest(request);
      expect(
        service.calls.where((x) => x.$1 == 'rescuer_claim_request').length,
        1,
      );
      service.currentJob = job();
      service.feedFailure = const PostgrestException(
        message: 'RESCUER_BUSY',
        code: 'P0001',
      );
      service.pendingClaim!.complete(assignmentJson());
      await tester.pumpAndSettle();
      expect(find.text('Đã nhận đơn thành công.'), findsWidgets);
      expect(find.text('Chuyến đang xử lý'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('0901234567'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Khách sau nhận'), findsOneWidget);
      expect(find.text('0901234567'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('claim RPC transport retry keeps operation UUID and does not write request table', () async {
    final payloads = <Json>[];
    final httpClient = MockClient((request) async {
      expect(request.url.path, '/rest/v1/rpc/rescuer_claim_request');
      payloads.add(Json.from(jsonDecode(request.body) as Map));
      if (payloads.length == 1) throw http.ClientException('response lost');
      return http.Response(
        jsonEncode(assignmentJson()),
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
    final params = {'p_request_id': 'request', 'p_vehicle_id': 'vehicle'};
    await expectLater(
      service.mutate('rescuer_claim_request', params),
      throwsA(isA<http.ClientException>()),
    );
    await service.mutate('rescuer_claim_request', params);
    expect(payloads[0], payloads[1]);
    expect(payloads[0].keys.toSet(), {
      'p_request_id',
      'p_vehicle_id',
      'p_operation_id',
    });
    expect(payloads[0]['p_operation_id'], isNotEmpty);
    await client.dispose();
    httpClient.close();
  });

  test(
    'active RPC returns null safely and excludes terminal job PII',
    () async {
      var calls = 0;
      final httpClient = MockClient((request) async {
        expect(request.url.path, '/rest/v1/rpc/rescuer_get_active_job');
        calls++;
        final value = calls == 1
            ? null
            : {
                ...assignmentJson(),
                'state': 'completed',
                'contact_phone': 'PRIVATE',
              };
        return http.Response(
          jsonEncode(value),
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
      expect(await service.getActiveJob(), isNull);
      expect(await service.getActiveJob(), isNull);
      await client.dispose();
      httpClient.close();
    },
  );
}
