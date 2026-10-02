import 'dart:convert';
import 'package:cuu_ho_247/services/customer_saved_address_service.dart';
import 'package:cuu_ho_247/services/supabase_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'request_photo_repository_test.dart' as support;

Map<String, dynamic> row() => {
      'id': 'address-id',
      'customer_id': support.customer,
      'label': 'Nhà',
      'address': '123 Nguyễn Huệ',
      'latitude': null,
      'longitude': null,
      'notes': null,
      'is_default': true
    };
void main() {
  test('list uses customer JWT, owner filter and default-first ordering',
      () async {
    final client = await support.clientFor(MockClient((request) async {
      expect(request.headers['authorization'], 'Bearer test-customer-token');
      expect(
          request.url.queryParameters['customer_id'], 'eq.${support.customer}');
      expect(
          request.url.queryParameters['order'], startsWith('is_default.desc'));
      return support.jsonResponse(request, [row()]);
    }));
    final result =
        await SupabaseCustomerSavedAddressRepository(client: client).list();
    expect(result.single.latitude, isNull);
    expect(result.single.notes, isNull);
    expect(result.single.isDefault, isTrue);
  });
  for (final editing in [false, true]) {
    test(
        'save ${editing ? 'update' : 'insert'} scopes owner and preserves coordinates',
        () async {
      final client = await support.clientFor(MockClient((request) async {
        expect(request.method, editing ? 'PATCH' : 'POST');
        final body = jsonDecode(request.body) as Map;
        expect(body['address'], '123 Nguyễn Huệ');
        expect(body['latitude'], 10.7);
        expect(body['longitude'], 106.7);
        expect(body['notes'], isNull);
        expect(body['is_default'], isTrue);
        if (editing) {
          expect(request.url.queryParameters['customer_id'],
              'eq.${support.customer}');
          expect(request.url.queryParameters['id'], 'eq.address-id');
          expect(body.containsKey('customer_id'), isFalse);
        } else {
          expect(body['customer_id'], support.customer);
        }
        return support.jsonResponse(request, {...row(), ...body});
      }));
      await SupabaseCustomerSavedAddressRepository(client: client).save(
          id: editing ? 'address-id' : null,
          label: 'Nhà',
          address: ' 123 Nguyễn Huệ ',
          latitude: 10.7,
          longitude: 106.7,
          notes: ' ',
          isDefault: true);
    });
  }
  test('delete scopes owner and reports missing row', () async {
    final client = await support.clientFor(MockClient((request) async {
      expect(request.method, 'DELETE');
      expect(
          request.url.queryParameters['customer_id'], 'eq.${support.customer}');
      expect(request.url.queryParameters['id'], 'eq.address-id');
      return support.jsonResponse(request, []);
    }));
    await expectLater(
        SupabaseCustomerSavedAddressRepository(client: client)
            .delete('address-id'),
        throwsA(isA<AppFailure>()));
  });
  test(
      'reject blank address, incomplete pair and invalid coordinates before network',
      () async {
    final client = await support.clientFor(
        MockClient((request) async => throw StateError('No network')));
    final repo = SupabaseCustomerSavedAddressRepository(client: client);
    for (final coordinates in [
      (10.0, null),
      (91.0, 100.0),
      (double.nan, 100.0),
      (10.0, double.infinity)
    ]) {
      await expectLater(
          repo.save(
              label: 'Nhà',
              address: 'Địa chỉ',
              latitude: coordinates.$1,
              longitude: coordinates.$2),
          throwsA(isA<AppFailure>()));
    }
    await expectLater(
        repo.save(label: 'Nhà', address: ' '), throwsA(isA<AppFailure>()));
  });
}
