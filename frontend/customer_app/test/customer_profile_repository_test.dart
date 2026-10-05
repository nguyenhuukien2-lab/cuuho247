import 'dart:convert';

import 'package:cuu_ho_247/app/user_session.dart';
import 'package:cuu_ho_247/services/customer_profile_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'request_photo_repository_test.dart' as support;

void main() {
  test('cleared profile phone remains empty despite old signup metadata', () {
    addTearDown(UserSession.clear);
    final user = User.fromJson({
      'id': support.customer,
      'app_metadata': <String, dynamic>{},
      'user_metadata': {'phone': '0901234567'},
      'aud': 'authenticated',
      'created_at': '2026-10-01T00:00:00Z',
    });
    UserSession.restore(user,
        profile: {'full_name': 'Nguyễn An', 'phone': null});
    expect(UserSession.phoneNumber, isNull);
  });
  test('reads own profile using customer JWT and Auth email/creation date',
      () async {
    final client = await support.clientFor(MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.headers['authorization'], 'Bearer test-customer-token');
      expect(request.url.queryParameters['user_id'], 'eq.${support.customer}');
      return support.jsonResponse(request, {
        'full_name': 'Nguyễn An',
        'customer_code': 'KH-000037',
        'phone': '0901234567',
        'created_at': '2026-10-02T00:00:00Z'
      });
    }));
    final profile =
        await SupabaseCustomerProfileRepository(client: client).load();
    expect(profile.fullName, 'Nguyễn An');
    expect(profile.customerCode, 'KH-000037');
    expect(profile.accountCreatedAt!.toUtc(), DateTime.utc(2026, 10, 1));
  });

  test('recovers absent profile without overwriting a concurrent profile',
      () async {
    var calls = 0;
    final client = await support.clientFor(MockClient((request) async {
      calls++;
      if (calls == 1) return support.jsonResponse(request, <Object>[]);
      if (calls == 2) {
        expect(request.method, 'POST');
        expect(request.headers['prefer'],
            contains('resolution=ignore-duplicates'));
        final body = jsonDecode(request.body) as Map;
        expect(body['user_id'], support.customer);
        expect(body.containsKey('email'), isFalse);
        return support.jsonResponse(request, <Object>[]);
      }
      expect(request.url.queryParameters['user_id'], 'eq.${support.customer}');
      return support.jsonResponse(
          request, {'full_name': 'Hồ sơ tab khác', 'phone': null});
    }));
    final profile =
        await SupabaseCustomerProfileRepository(client: client).load();
    expect(profile.fullName, 'Hồ sơ tab khác');
    expect(calls, 3);
  });

  test('saves only editable fields for current owner and normalizes phone',
      () async {
    final client = await support.clientFor(MockClient((request) async {
      expect(request.method, 'POST');
      expect(request.url.path, endsWith('customer_profiles'));
      expect(request.headers['authorization'], 'Bearer test-customer-token');
      final body = jsonDecode(request.body) as Map;
      expect(body['user_id'], support.customer);
      expect(body['full_name'], 'Nguyễn An');
      expect(body['phone'], '+84901234567');
      expect(
          body.keys.toSet(), {'user_id', 'full_name', 'phone', 'updated_at'});
      return support.jsonResponse(request, body);
    }));
    final profile = await SupabaseCustomerProfileRepository(client: client)
        .save(fullName: '  Nguyễn An  ', phone: '+84 901-234-567');
    expect(profile.phone, '+84901234567');
  });

  test('validation rejects empty name and invalid phone, allows no phone', () {
    expect(validateCustomerName('   '), isNotNull);
    expect(validateCustomerPhone('abc123'), isNotNull);
    expect(validateCustomerPhone('123'), isNotNull);
    expect(validateCustomerPhone(''), isNull);
    expect(validateCustomerPhone('090 123 4567'), isNull);
  });
}
