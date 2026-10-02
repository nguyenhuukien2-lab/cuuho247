import 'package:cuu_ho_247/services/request_details_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'request_photo_repository_test.dart' as support;

void main() {
  test(
      'detail reads use customer JWT and owner filter with chronological events',
      () async {
    final calls = <String>[];
    final client = await support.clientFor(MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.headers['authorization'], 'Bearer test-customer-token');
      calls.add(request.url.path);
      if (request.url.path.endsWith('rescue_requests')) {
        expect(request.url.queryParameters['id'], 'eq.${support.requestId}');
        expect(request.url.queryParameters['customer_id'],
            'eq.${support.customer}');
        return support.jsonResponse(
            request, {'id': support.requestId, 'status': 'completed'});
      }
      expect(request.url.path.endsWith('request_status_events'), isTrue);
      expect(
          request.url.queryParameters['request_id'], 'eq.${support.requestId}');
      expect(request.url.queryParameters['order'],
          'occurred_at.asc.nullslast,id.asc.nullslast');
      return support.jsonResponse(request, [
        {'status': 'completed', 'occurred_at': '2026-10-01T01:00:00Z'}
      ]);
    }));
    final result = await SupabaseRequestDetailsRepository(client: client)
        .load(support.requestId);
    expect(result!.terminalTime, DateTime.utc(2026, 10, 1, 1));
    expect(calls.length, 2);
  });

  test('unavailable request does not query its status events', () async {
    var calls = 0;
    final client = await support.clientFor(MockClient((request) async {
      calls++;
      expect(request.url.path.endsWith('rescue_requests'), isTrue);
      return support.jsonResponse(request, <Object>[]);
    }));
    expect(
        await SupabaseRequestDetailsRepository(client: client)
            .load(support.requestId),
        isNull);
    expect(calls, 1);
  });
}
