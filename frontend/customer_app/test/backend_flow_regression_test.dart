import 'dart:async';
import 'dart:convert';

import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/app/user_session.dart';
import 'package:cuu_ho_247/services/customer_vehicle_service.dart';
import 'package:cuu_ho_247/services/supabase_service.dart';
import 'package:cuu_ho_247/widgets/tracking_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'request_photo_repository_test.dart' as support;

Map<String, dynamic> row({String? id, String status = 'searching'}) => {
      'id': id ?? support.requestId,
      'customer_id': support.customer,
      'service_code': 'tire',
      'vehicle_kind': 'car',
      'location_text': 'Địa chỉ kiểm thử',
      'created_at': '2026-10-01T00:00:00+00:00',
      'updated_at': '2026-10-01T00:01:00+00:00',
      'status': status,
      'quoted_price': null,
    };

bool isHistory(http.Request request) =>
    request.url.queryParameters['status'] == 'in.("completed","cancelled")';

void main() {
  setUp(() => UserSession.userId = support.customer);
  tearDown(UserSession.clear);

  test('untrusted Auth metadata cannot crash restore or replace Auth email',
      () {
    final user = User.fromJson({
      'id': support.customer,
      'email': 'auth@example.test',
      'app_metadata': <String, dynamic>{},
      'user_metadata': {
        'full_name': {'unexpected': true},
        'phone': 123,
        'email': 'metadata@example.test',
      },
      'aud': 'authenticated',
      'created_at': '2026-10-01T00:00:00Z',
    });
    UserSession.restore(user);
    expect(UserSession.fullName, isNull);
    expect(UserSession.phoneNumber, isNull);
    expect(UserSession.email, 'auth@example.test');
    UserSession.restore(user,
        profile: {'full_name': 'Saved name', 'phone': null});
    expect(UserSession.fullName, 'Saved name');
    expect(UserSession.phoneNumber, isNull);
  });

  for (final invalid in <Map<String, dynamic>>[
    {'status': 'unknown'},
    {'status': 'assisting'},
    {'service_code': 'not-supported'},
    {'vehicle_kind': null},
    {'created_at': 'not-a-date'},
    {'quoted_price': '100'},
  ]) {
    test(
        'invalid request $invalid becomes a visible failure, never a status fallback',
        () {
      expect(() => RescueRequestData.fromJson({...row(), ...invalid}),
          throwsA(isA<AppFailure>()));
    });
  }

  for (final count in [0, 100, 101, 205]) {
    test(
        'history traverses $count rows with tied timestamps and bounded code batches',
        () async {
      final source = List.generate(
          count,
          (index) => row(
              id: '00000000-0000-4000-8000-${(count - index).toString().padLeft(12, '0')}',
              status: index.isEven ? 'completed' : 'cancelled'));
      var page = 0;
      final batches = <int>[];
      final database = await support.clientFor(MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer test-customer-token');
        if (request.url.path.endsWith('customer_request_display_codes')) {
          final ids =
              (jsonDecode(request.body) as Map)['p_request_ids'] as List;
          batches.add(ids.length);
          expect(ids.length, lessThanOrEqualTo(100));
          return support.jsonResponse(request, [
            for (final id in ids) {'request_id': id, 'quote_code': 'BG-000001'}
          ]);
        }
        final parameters = request.url.queryParameters;
        expect(parameters['customer_id'], 'eq.${support.customer}');
        expect(parameters['status'], 'in.("completed","cancelled")');
        expect(parameters['limit'], '100');
        expect(
            parameters['order'], 'created_at.desc.nullslast,id.desc.nullslast');
        if (page == 0) {
          expect(parameters['or'], isNull);
        } else {
          final cursor = source[page * 100 - 1];
          expect(parameters['or'],
              '(created_at.lt.${cursor['created_at']},and(created_at.eq.${cursor['created_at']},id.lt.${cursor['id']}))');
        }
        return support.jsonResponse(
            request, source.skip(page++ * 100).take(100).toList());
      }));
      final result = await SupabaseService.fetchHistory(client: database);
      expect(result.map((r) => r.id), source.map((r) => r['id']));
      expect(result.map((r) => r.id).toSet(), hasLength(count));
      expect(result.every((r) => r.quoteCode == 'BG-000001'), isTrue);
      expect(page, count ~/ 100 + 1);
      expect(batches.fold<int>(0, (total, size) => total + size), count);
    });
  }

  for (final status in ['cancelled', 'completed', 'arriving', 'in_progress']) {
    test(
        'cancel retry reconciles $status without changing the cancellation rule',
        () async {
      final calls = <String>[];
      final database = await support.clientFor(MockClient((request) async {
        calls.add(request.method);
        if (request.method == 'POST') {
          expect(request.url.path, endsWith('cancel_own_rescue_request'));
          expect(jsonDecode(request.body), {'request_id': support.requestId});
          return support.jsonResponse(request,
              {'code': 'P0001', 'message': 'REQUEST_NOT_CANCELLABLE'}, 400);
        }
        expect(request.url.queryParameters['id'], 'eq.${support.requestId}');
        expect(request.url.queryParameters['customer_id'],
            'eq.${support.customer}');
        return support.jsonResponse(request, row(status: status));
      }));
      final result =
          SupabaseService.cancelRequest(support.requestId, client: database);
      if (status == 'cancelled') {
        expect((await result).stage, RequestStage.cancelled);
      } else {
        await expectLater(result, throwsA(isA<AppFailure>()));
      }
      expect(calls, ['POST', 'GET']);
    });
  }

  test('cancel permission failure is not swallowed or retried as success',
      () async {
    var calls = 0;
    final database = await support.clientFor(MockClient((request) async {
      calls++;
      return support.jsonResponse(
          request, {'code': '42501', 'message': 'denied'}, 403);
    }));
    await expectLater(
        SupabaseService.cancelRequest(support.requestId, client: database),
        throwsA(isA<AppFailure>()));
    expect(calls, 1);
  });

  test(
      'profile failure does not block requests; repeated initialize does not leak listeners',
      () async {
    var profiles = 0, active = 0, history = 0, payments = 0;
    final database = await support.clientFor(MockClient((request) async {
      if (request.url.path.endsWith('customer_get_payment')) {
        payments++;
        return http.Response('null', 200,
            headers: {'content-type': 'application/json'}, request: request);
      }
      if (request.url.path.endsWith('customer_profiles')) {
        profiles++;
        return support.jsonResponse(
            request, {'code': 'XX000', 'message': 'profile unavailable'}, 500);
      }
      if (request.url.path.endsWith('customer_request_display_codes')) {
        return support.jsonResponse(request, <Object>[]);
      }
      if (isHistory(request)) {
        history++;
        return support.jsonResponse(
            request, [row(status: 'completed', id: 'history-id')]);
      }
      active++;
      return support.jsonResponse(request, row());
    }));
    final controller = AppController(client: database);
    addTearDown(controller.dispose);
    await controller.initialize();
    await controller.initialize();
    await Future<void>.delayed(Duration.zero);
    expect(controller.activeRequest?.id, support.requestId);
    expect(controller.history.single.id, 'history-id');
    expect(controller.loadingRequests, isFalse);
    expect([profiles, active, history], [1, 1, 1]);
    expect(payments, 1);
  });

  test(
      'expired JWT removes cached request, history, selected vehicle and identity',
      () async {
    final database = await support.clientFor(MockClient((request) async {
      if (isHistory(request)) return support.jsonResponse(request, <Object>[]);
      return support.jsonResponse(
          request, {'code': 'PGRST301', 'message': 'JWT expired'}, 401);
    }));
    final controller = AppController(client: database)
      ..activeRequest = RescueRequestData.fromJson(row())
      ..history = [RescueRequestData.fromJson(row(status: 'completed'))]
      ..selectedSavedVehicle = const CustomerVehicle(
          id: 'vehicle',
          customerId: support.customer,
          kind: VehicleKind.car,
          brandModel: 'Test');
    addTearDown(controller.dispose);
    await controller.refreshRequests();
    expect(controller.isLoggedIn, isFalse, reason: controller.loadError);
    expect(controller.activeRequest, isNull);
    expect(controller.history, isEmpty);
    expect(controller.selectedSavedVehicle, isNull);
    expect(controller.loadingRequests, isFalse);
    expect(controller.loadError, isNotNull);
  });

  test('unsupported request status is reported through loadError', () async {
    final database = await support.clientFor(MockClient((request) async {
      if (isHistory(request) || request.method == 'POST') {
        return support.jsonResponse(request, <Object>[]);
      }
      return support.jsonResponse(request, row(status: 'unknown'));
    }));
    final controller = AppController(client: database);
    addTearDown(controller.dispose);
    await controller.refreshRequests();
    expect(controller.loadError, contains('chưa được hỗ trợ'));
    expect(controller.loadingRequests, isFalse);
    expect(controller.activeRequest, isNull);
  });

  test('unexpected history JSON shape is a failure, not an uncaught type error',
      () async {
    final database = await support.clientFor(MockClient((request) async =>
        support.jsonResponse(request, {'unexpected': true})));
    await expectLater(SupabaseService.fetchHistory(client: database),
        throwsA(isA<AppFailure>()));
  });

  test('optional display-code failure can degrade, but JWT expiry cannot',
      () async {
    var expired = false;
    final database = await support.clientFor(MockClient((request) async {
      return support.jsonResponse(
          request,
          {
            'code': expired ? 'PGRST301' : 'PGRST202',
            'message': expired ? 'JWT expired' : 'RPC unavailable',
          },
          expired ? 401 : 404);
    }));
    expect(await SupabaseService.withDisplayCodes([row()], client: database),
        [row()]);
    expired = true;
    await expectLater(
        SupabaseService.withDisplayCodes([row()], client: database),
        throwsA(isA<AppFailure>()
            .having((e) => e.sessionExpired, 'sessionExpired', isTrue)));
  });

  test('profile JWT expiry clears session and does not start request reads',
      () async {
    var calls = 0;
    final database = await support.clientFor(MockClient((request) async {
      calls++;
      expect(request.url.path, endsWith('customer_profiles'));
      return support.jsonResponse(
          request, {'code': 'PGRST301', 'message': 'JWT expired'}, 401);
    }));
    final controller = AppController(client: database)
      ..activeRequest = RescueRequestData.fromJson(row());
    addTearDown(controller.dispose);
    await controller.initialize();
    expect(calls, 1);
    expect(controller.isLoggedIn, isFalse);
    expect(controller.activeRequest, isNull);
    expect(controller.loadError, isNotNull);
  });

  test('logout prevents a pending refresh from restoring private data',
      () async {
    final response = Completer<http.Response>();
    http.Request? pendingRequest;
    final database = await support.clientFor(MockClient((request) async {
      if (request.url.path.contains('/auth/v1/logout') || isHistory(request)) {
        return support.jsonResponse(request, <Object>[]);
      }
      pendingRequest = request;
      return response.future;
    }));
    final controller = AppController(client: database)
      ..activeRequest = RescueRequestData.fromJson(row());
    addTearDown(controller.dispose);
    final refresh = controller.refreshRequests();
    await Future<void>.delayed(Duration.zero);
    await controller.signOut();
    response.complete(support.jsonResponse(pendingRequest!, row()));
    await refresh;
    expect(controller.isLoggedIn, isFalse);
    expect(controller.activeRequest, isNull);
    expect(controller.history, isEmpty);
    expect(controller.loadingRequests, isFalse);
  });

  test('cancel retry cannot turn an invisible request into success', () async {
    final database = await support.clientFor(MockClient((request) async {
      if (request.method == 'POST') {
        return support.jsonResponse(request,
            {'code': 'P0001', 'message': 'REQUEST_NOT_CANCELLABLE'}, 400);
      }
      expect(
          request.url.queryParameters['customer_id'], 'eq.${support.customer}');
      return support.jsonResponse(request, <Object>[]);
    }));
    await expectLater(
        SupabaseService.cancelRequest(support.requestId, client: database),
        throwsA(isA<AppFailure>()));
  });

  test(
      'old refresh completion cannot clear the loading flag of a newer refresh',
      () async {
    final responses = <Completer<http.Response>>[];
    final requests = <http.Request>[];
    final database = await support.clientFor(MockClient((request) async {
      if (isHistory(request) || request.method == 'POST') {
        return support.jsonResponse(request, <Object>[]);
      }
      requests.add(request);
      final response = Completer<http.Response>();
      responses.add(response);
      return response.future;
    }));
    final controller = AppController(client: database);
    addTearDown(controller.dispose);
    final first = controller.refreshRequests();
    await Future<void>.delayed(Duration.zero);
    final second = controller.refreshRequests();
    await Future<void>.delayed(Duration.zero);
    expect(responses, hasLength(2));
    responses[0].complete(support.jsonResponse(requests[0], row()));
    await first;
    expect(controller.loadingRequests, isTrue);
    expect(controller.activeRequest, isNull);
    responses[1]
        .complete(support.jsonResponse(requests[1], row(status: 'arriving')));
    await second;
    expect(controller.activeRequest?.stage, RequestStage.arriving);
    expect(controller.loadingRequests, isFalse);
  });

  test(
      'terminal realtime update invalidates pending snapshot and finishes loading',
      () async {
    final pending = Completer<http.Response>();
    http.Request? snapshotRequest;
    final database = await support.clientFor(MockClient((request) async {
      if (isHistory(request) || request.method == 'POST') {
        return support.jsonResponse(request, <Object>[]);
      }
      snapshotRequest = request;
      return pending.future;
    }));
    final controller = AppController(client: database)
      ..activeRequest = RescueRequestData.fromJson(row())
      ..tabIndex = 2;
    addTearDown(controller.dispose);
    final refresh = controller.refreshRequests();
    await Future<void>.delayed(Duration.zero);
    controller.applyTrackingUpdate(RescueRequestData.fromJson(
        {...row(status: 'completed'), 'updated_at': '2026-10-01T00:02:00Z'}));
    expect(controller.loadingRequests, isFalse);
    pending.complete(support.jsonResponse(snapshotRequest!, row()));
    await refresh;
    expect(controller.activeRequest, isNull);
    expect(controller.history.single.stage, RequestStage.completed);
    expect(controller.tabIndex, 3);
  });

  testWidgets('quote row update does not invent a status transition timestamp',
      (tester) async {
    for (final status in [
      'accepted',
      'in_progress',
      'completed',
      'cancelled'
    ]) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: SingleChildScrollView(
                  child: TrackingTimeline(
                      request: RescueRequestData.fromJson({
        ...row(status: status),
        'quoted_price': 150000,
        'updated_at': '2026-10-01T03:45:00Z',
      }))))));
      final steps =
          tester.widgetList<TimelineStep>(find.byType(TimelineStep)).toList();
      expect(steps.first.time, isNotNull);
      expect(steps.skip(1).every((step) => step.time == null), isTrue);
      expect(steps.where((step) => step.current), hasLength(1));
      expect(tester.takeException(), isNull);
    }
  });
}
