import 'dart:convert';

import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/services/customer_vehicle_service.dart';
import 'package:cuu_ho_247/services/supabase_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';

import 'request_photo_repository_test.dart' as support;

Map<String, dynamic> row([String kind = 'truck']) => {
      'id': 'vehicle-id',
      'customer_id': support.customer,
      'kind': kind,
      'display_name': 'Isuzu QKR',
      'license_plate': null,
      'color': null,
      'notes': null,
    };

void main() {
  test(
      'list reads own vehicles using customer JWT and optional fields tolerate null',
      () async {
    final client = await support.clientFor(MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.headers['authorization'], 'Bearer test-customer-token');
      expect(
          request.url.queryParameters['customer_id'], 'eq.${support.customer}');
      return support.jsonResponse(request, [row()]);
    }));
    final vehicles =
        await SupabaseCustomerVehicleRepository(client: client).list();
    expect(vehicles.single.kind, VehicleKind.truck);
    expect(vehicles.single.color, isEmpty);
    expect(vehicles.single.notes, isEmpty);
  });

  for (final editing in [false, true]) {
    test(
        '${editing ? 'update' : 'insert'} uses owner scope and editable columns',
        () async {
      final client = await support.clientFor(MockClient((request) async {
        expect(request.headers['authorization'], 'Bearer test-customer-token');
        expect(request.method, editing ? 'PATCH' : 'POST');
        final body = jsonDecode(request.body) as Map;
        expect(body['kind'], 'other');
        expect(body['display_name'], 'Xe chuyên dụng');
        expect(body['license_plate'], isNull);
        expect(body['color'], 'Trắng');
        expect(body['notes'], 'Gầm thấp');
        if (editing) {
          expect(request.url.queryParameters['customer_id'],
              'eq.${support.customer}');
          expect(request.url.queryParameters['id'], 'eq.vehicle-id');
          expect(body.containsKey('customer_id'), isFalse);
        } else {
          expect(body['customer_id'], support.customer);
        }
        return support.jsonResponse(request, {...row(), ...body});
      }));
      final vehicle = await SupabaseCustomerVehicleRepository(client: client)
          .save(
              id: editing ? 'vehicle-id' : null,
              kind: VehicleKind.other,
              brandModel: '  Xe chuyên dụng  ',
              licensePlate: '',
              color: ' Trắng ',
              notes: 'Gầm thấp');
      expect(vehicle.kind, VehicleKind.other);
    });
  }

  test('delete filters owner and reports missing/denied row', () async {
    final client = await support.clientFor(MockClient((request) async {
      expect(request.method, 'DELETE');
      expect(
          request.url.queryParameters['customer_id'], 'eq.${support.customer}');
      expect(request.url.queryParameters['id'], 'eq.vehicle-id');
      return support.jsonResponse(request, <Object>[]);
    }));
    await expectLater(
        SupabaseCustomerVehicleRepository(client: client).delete('vehicle-id'),
        throwsA(isA<AppFailure>()));
  });

  test('invalid brand is rejected before making a mutation', () async {
    final client = await support.clientFor(MockClient(
        (request) async => throw StateError('Must not call network')));
    await expectLater(
        SupabaseCustomerVehicleRepository(client: client).save(
            kind: VehicleKind.car,
            brandModel: ' ',
            licensePlate: '',
            color: '',
            notes: ''),
        throwsA(isA<AppFailure>()));
  });

  for (final kind in VehicleKind.values) {
    for (final saved in [false, true]) {
      test(
          'request RPC sends ${kind.name}, ${saved ? 'saved vehicle id' : 'manual null id'}',
          () async {
        final client = await support.clientFor(MockClient((request) async {
          expect(request.url.path, endsWith('create_customer_rescue_request'));
          expect(
              request.headers['authorization'], 'Bearer test-customer-token');
          final body = jsonDecode(request.body) as Map;
          expect(body['p_vehicle_kind'], kind.name);
          expect(body['p_vehicle_id'], saved ? support.photoId : null);
          return support.jsonResponse(request, {
            'id': support.requestId,
            'vehicle_kind': kind.name,
            'vehicle_id': body['p_vehicle_id'],
            'service_code': 'tire',
            'location_text': 'Địa chỉ',
            'created_at': '2026-10-01T00:00:00Z',
            'status': 'searching',
          });
        }));
        final request = await SupabaseService.createRescueRequest(
            client: client,
            clientRequestId: support.requestId,
            vehicle: kind,
            vehicleId: saved ? support.photoId : null,
            service: RescueService.tire,
            locationText: 'Địa chỉ',
            description: '',
            contactName: 'An',
            contactPhone: '0901234567');
        expect(request.vehicle, kind);
        expect(request.vehicleId, saved ? support.photoId : null);
      });
    }
  }
}
