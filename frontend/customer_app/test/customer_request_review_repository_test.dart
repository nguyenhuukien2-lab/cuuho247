import 'dart:convert';
import 'package:cuu_ho_247/services/customer_request_review_service.dart';
import 'package:cuu_ho_247/services/supabase_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'request_photo_repository_test.dart' as support;

Map<String, dynamic> reviewRow() => {
      'id': support.photoId,
      'request_id': support.requestId,
      'customer_id': support.customer,
      'rating': 4,
      'comment': null,
      'created_at': '2026-10-01T00:00:00Z',
      'updated_at': '2026-10-01T00:00:00Z'
    };
void main() {
  for (final exists in [false, true]) {
    test('load owner scoped review, exists=$exists', () async {
      final client = await support.clientFor(MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer test-customer-token');
        expect(request.url.path, endsWith('customer_request_reviews'));
        expect(request.url.queryParameters['request_id'],
            'eq.${support.requestId}');
        expect(request.url.queryParameters['customer_id'],
            'eq.${support.customer}');
        return support.jsonResponse(request, exists ? [reviewRow()] : []);
      }));
      final review =
          await SupabaseCustomerRequestReviewRepository(client: client)
              .load(support.requestId);
      expect(review?.rating, exists ? 4 : null);
      expect(review?.comment, isNull);
    });
  }
  test('submit uses session JWT and RPC without caller-supplied customer',
      () async {
    final client = await support.clientFor(MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer test-customer-token');
      expect(request.url.path, endsWith('submit_customer_request_review'));
      expect(request.method, 'POST');
      expect(jsonDecode(request.body), {
        'p_request_id': support.requestId,
        'p_rating': 4,
        'p_comment': 'Rất tốt'
      });
      return support
          .jsonResponse(request, {...reviewRow(), 'comment': 'Rất tốt'});
    }));
    final result = await SupabaseCustomerRequestReviewRepository(client: client)
        .submit(support.requestId, rating: 4, comment: ' Rất tốt ');
    expect(result.rating, 4);
    expect(result.comment, 'Rất tốt');
  });
  test('blank comment maps to null', () async {
    final client = await support.clientFor(MockClient((request) async {
      expect((jsonDecode(request.body) as Map)['p_comment'], isNull);
      return support.jsonResponse(request, reviewRow());
    }));
    await SupabaseCustomerRequestReviewRepository(client: client)
        .submit(support.requestId, rating: 4, comment: ' ');
  });
  test('invalid input is rejected before network', () async {
    final client = await support.clientFor(
        MockClient((request) async => throw StateError('No network')));
    final repo = SupabaseCustomerRequestReviewRepository(client: client);
    for (final rating in [0, 6]) {
      await expectLater(repo.submit(support.requestId, rating: rating),
          throwsA(isA<AppFailure>()));
    }
    await expectLater(
        repo.submit(support.requestId, rating: 4, comment: 'x' * 2001),
        throwsA(isA<AppFailure>()));
  });
  test('backend denial becomes retryable failure', () async {
    final client = await support.clientFor(MockClient((request) async =>
        support.jsonResponse(
            request,
            {
              'code': '42501',
              'message': 'REVIEW_REQUIRES_OWN_COMPLETED_REQUEST'
            },
            403)));
    await expectLater(
        SupabaseCustomerRequestReviewRepository(client: client)
            .submit(support.requestId, rating: 4),
        throwsA(isA<AppFailure>()));
  });
}
