import 'dart:convert';
import 'dart:typed_data';

import 'package:cuu_ho_247/services/request_photo_service.dart';
import 'package:cuu_ho_247/services/supabase_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

const customer = 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa';
const requestId = '11111111-1111-4111-8111-111111111111';
const photoId = '22222222-2222-4222-8222-222222222222';
const path = '$customer/$requestId/$photoId';

Future<SupabaseClient> clientFor(MockClient transport) async {
  final client = SupabaseClient(
      'https://test.supabase.co', 'test-publishable-key',
      httpClient: transport,
      authOptions: const AuthClientOptions(autoRefreshToken: false));
  await client.auth.setInitialSession(jsonEncode({
    'access_token': 'test-customer-token',
    'refresh_token': 'test-refresh-token',
    'token_type': 'bearer',
    'expires_in': 3600,
    'expires_at': 4102444800,
    'user': {
      'id': customer,
      'app_metadata': {},
      'user_metadata': {},
      'aud': 'authenticated',
      'created_at': '2026-10-01T00:00:00Z'
    },
  }));
  addTearDown(client.dispose);
  return client;
}

http.Response jsonResponse(http.Request request, Object value,
        [int status = 200]) =>
    http.Response(jsonEncode(value), status,
        headers: {'content-type': 'application/json'}, request: request);

SelectedRequestPhoto selected() => SelectedRequestPhoto(
    id: photoId,
    bytes: Uint8List.fromList([1, 2, 3]),
    contentType: 'image/png');

void main() {
  for (final duplicate in [false, true]) {
    test(
        'reserve → ${duplicate ? 'duplicate object retry' : 'upload'} → complete uses customer JWT',
        () async {
      final calls = <http.Request>[];
      final transport = MockClient((request) async {
        calls.add(request);
        if (request.url.path.endsWith('reserve_customer_request_photo')) {
          return jsonResponse(
              request, {'storage_path': path, 'uploaded_at': null});
        }
        if (request.url.path.contains('/storage/v1/object/')) {
          return duplicate
              ? jsonResponse(
                  request,
                  {
                    'statusCode': '409',
                    'error': 'Duplicate',
                    'message': 'Already exists'
                  },
                  409)
              : jsonResponse(request, {'Key': 'rescue-request-photos/$path'});
        }
        return jsonResponse(
            request, {'id': photoId, 'uploaded_at': '2026-10-01T01:00:00Z'});
      });
      final repository =
          SupabaseRequestPhotoRepository(client: await clientFor(transport));
      await repository.upload(requestId, selected());
      // Assert outside the transport: upload recovery intentionally catches
      // errors, which must never swallow an assertion from this test.
      expect(calls.map((request) => request.url.path), [
        '/rest/v1/rpc/reserve_customer_request_photo',
        '/storage/v1/object/rescue-request-photos/$path',
        '/rest/v1/rpc/complete_customer_request_photo',
      ]);
      for (final request in calls) {
        expect(request.method, 'POST');
        expect(request.headers['authorization'], 'Bearer test-customer-token');
      }
      expect(jsonDecode(calls.first.body), {
        'p_request_id': requestId,
        'p_photo_id': photoId,
        'p_content_type': 'image/png',
        'p_byte_size': 3,
      });
      final upload = calls[1];
      expect(upload.headers['x-upsert'], 'false');
      final contentType = upload.headers['content-type']!;
      expect(contentType, startsWith('multipart/form-data; boundary='));
      final boundary = contentType.split('boundary=').last;
      final filePart = latin1
          .decode(upload.bodyBytes)
          .split('--$boundary')
          .singleWhere((part) => part.contains('filename=""'));
      final split = filePart.indexOf('\r\n\r\n');
      expect(filePart.substring(0, split).toLowerCase(),
          contains('content-type: image/png'));
      expect(latin1.encode(filePart.substring(split + 4, filePart.length - 2)),
          [1, 2, 3]);
      expect(jsonDecode(calls.last.body), {'p_photo_id': photoId});
    });
  }

  test('completed reservation skips upload on retry', () async {
    var calls = 0;
    final repository = SupabaseRequestPhotoRepository(
        client: await clientFor(MockClient((request) async {
      calls++;
      expect(
          request.url.path.endsWith('reserve_customer_request_photo'), isTrue);
      return jsonResponse(request,
          {'storage_path': path, 'uploaded_at': '2026-10-01T01:00:00Z'});
    })));
    await repository.upload(requestId, selected());
    expect(calls, 1);
  });

  test('upload failure with missing object remains a clear retriable error',
      () async {
    final repository = SupabaseRequestPhotoRepository(
        client: await clientFor(MockClient((request) async {
      if (request.url.path.endsWith('reserve_customer_request_photo')) {
        return jsonResponse(
            request, {'storage_path': path, 'uploaded_at': null});
      }
      if (request.url.path.contains('/storage/'))
        throw http.ClientException('offline');
      return jsonResponse(
          request, {'code': '22023', 'message': 'PHOTO_OBJECT_NOT_READY'}, 400);
    })));
    await expectLater(
        repository.upload(requestId, selected()),
        throwsA(isA<AppFailure>().having((failure) => failure.message,
            'message', contains('thử gửi ảnh lại'))));
  });

  test(
      'listing fetches only completed attachments and creates private signed URLs',
      () async {
    final repository = SupabaseRequestPhotoRepository(
        client: await clientFor(MockClient((request) async {
      if (request.url.path.endsWith('rescue_request_photos')) {
        expect(request.url.queryParameters['request_id'], 'eq.$requestId');
        expect(request.url.queryParameters['uploaded_at'], 'not.is.null');
        return jsonResponse(request, [
          {'id': photoId, 'storage_path': path}
        ]);
      }
      expect(request.url.path,
          '/storage/v1/object/sign/rescue-request-photos/$path');
      expect(jsonDecode(request.body)['expiresIn'], 600);
      return jsonResponse(request,
          {'signedURL': '/object/sign/rescue-request-photos/$path?token=test'});
    })));
    final items = await repository.list(requestId);
    expect(items.single.id, photoId);
    expect(items.single.url, contains('/object/sign/'));
    expect(items.single.url, isNot(contains('/object/public/')));
  });
}
