import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/services/request_debug_log.dart';
import 'package:cuu_ho_247/services/request_photo_service.dart';
import 'package:cuu_ho_247/services/supabase_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'request_photo_repository_test.dart' as support;

void main() {
  late List<String> lines;
  setUp(() {
    lines = [];
    final original = debugPrint;
    debugPrint = (String? text, {int? wrapWidth}) {
      if (text != null) lines.add(text);
    };
    addTearDown(() => debugPrint = original);
  });

  test('preserves database diagnostics and redacts nested credentials', () {
    logRequestFailure(
        'test.rpc',
        const PostgrestException(
            message: 'constraint failed',
            code: '23514',
            details: {
              'constraint': 'request_vehicle_check',
              'access_token': 'private-access-value',
              'nested': [
                {'password': 'private-password-value', 'apikey': 'private-key'}
              ],
            },
            hint: 'Check vehicle kind'),
        StackTrace.fromString('rpc frame'));
    final output = lines.join('\n');
    for (final expected in [
      'runtimeType: PostgrestException',
      'exception: PostgrestException: constraint failed',
      'message: constraint failed',
      'status: <not provided>',
      'code: 23514',
      'request_vehicle_check',
      'hint: Check vehicle kind',
      'stackTrace: rpc frame',
    ]) {
      expect(output, contains(expected));
    }
    for (final secret in [
      'private-access-value',
      'private-password-value',
      'private-key'
    ]) {
      expect(output, isNot(contains(secret)));
    }
  });

  test('redacts URLs, signed URLs, opaque credentials, JWT and known secrets',
      () {
    const text = '''URL https://example.supabase.co/rest/v1/rpc/create
signed https://example.supabase.co/object/sign/photo?token=signed-secret
Authorization: Bearer opaque-bearer-value
{"password":"password with spaces", "refresh_token":"opaque-refresh-value"}
apikey=opaque-api-value SUPABASE_ANON_KEY=opaque-anon-value
eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiJ1c2VyIn0.fakeSignature
sb_publishable_fakekey sb_secret_fakekey raw-known-value
code=23514''';
    final output =
        redactRequestDebugValue(text, secrets: const ['raw-known-value']);
    for (final secret in [
      'example.supabase.co',
      'signed-secret',
      'opaque-bearer-value',
      'password with spaces',
      'opaque-refresh-value',
      'opaque-api-value',
      'opaque-anon-value',
      'eyJhbGci',
      'fakeSignature',
      'sb_publishable_fakekey',
      'sb_secret_fakekey',
      'raw-known-value',
    ]) {
      expect(output, isNot(contains(secret)));
    }
    expect(output, contains('code=23514'));
  });

  test('storage status/error retained and FormatException source omitted', () {
    logRequestFailure(
        'test.storage',
        const StorageException('Access denied',
            statusCode: '403', error: 'Unauthorized'),
        StackTrace.current);
    expect(lines.join('\n'), contains('status: 403'));
    expect(lines.join('\n'), contains('code: Unauthorized'));
    lines.clear();
    logRequestFailure(
        'test.decode',
        const FormatException(
            'Invalid response', 'unlabelled-sensitive-response-source'),
        StackTrace.current);
    expect(lines.join('\n'), contains('message: Invalid response'));
    expect(lines.join('\n'),
        isNot(contains('unlabelled-sensitive-response-source')));
  });

  test('create RPC redacts form data echoed in backend diagnostics', () async {
    final client = await support
        .clientFor(MockClient((request) async => support.jsonResponse(
            request,
            {
              'code': '22023',
              'message': 'LOCATION_REQUIRED',
              'details':
                  'private address private description private name 0901234567',
            },
            400)));
    await expectLater(
        SupabaseService.createRescueRequest(
          client: client,
          clientRequestId: support.requestId,
          vehicle: VehicleKind.car,
          service: RescueService.tire,
          locationText: '  private address  ',
          description: 'private description',
          contactName: 'private name',
          contactPhone: '0901234567',
        ),
        throwsA(isA<AppFailure>()));
    final output = lines.join('\n');
    expect(output, contains('LOCATION_REQUIRED'));
    for (final value in [
      'private address',
      'private description',
      'private name',
      '0901234567'
    ]) {
      expect(output, isNot(contains(value)));
    }
  });

  test('create RPC logs original error while preserving mapped AppFailure',
      () async {
    final client = await support
        .clientFor(MockClient((request) async => support.jsonResponse(
            request,
            {
              'code': '23514',
              'message': 'constraint request_vehicle_check failed',
              'details':
                  'test-customer-token test-refresh-token test-publishable-key https://test.supabase.co',
              'hint': 'Check vehicle kind',
            },
            400)));
    await expectLater(
        SupabaseService.createRescueRequest(
          client: client,
          clientRequestId: support.requestId,
          vehicle: VehicleKind.car,
          service: RescueService.tire,
          locationText: 'test location',
          description: '',
          contactName: 'test name',
          contactPhone: '0900000000',
        ),
        throwsA(isA<AppFailure>().having(
            (error) => error.message,
            'unchanged message',
            startsWith('Máy chủ chưa thể xử lý yêu cầu.'))));
    final output = lines.join('\n');
    expect(output, contains('service.createRescueRequest.rpc FAILED'));
    expect(output, contains('code: 23514'));
    expect(output, contains('hint: Check vehicle kind'));
    for (final secret in [
      'test-customer-token',
      'test-refresh-token',
      'test-publishable-key',
      'test.supabase.co',
      'test location',
      'test name',
      '0900000000'
    ]) {
      expect(output, isNot(contains(secret)));
    }
  });

  test(
      'upload logs storage failure before finalize failure without changing retry',
      () async {
    final calls = <String>[];
    final client = await support.clientFor(MockClient((request) async {
      calls.add(request.url.path);
      if (request.url.path.endsWith('reserve_customer_request_photo')) {
        return support.jsonResponse(
            request, {'storage_path': support.path, 'uploaded_at': null});
      }
      if (request.url.path.contains('/storage/')) {
        return support.jsonResponse(
            request,
            {
              'statusCode': '403',
              'error': 'Unauthorized',
              'message': 'Upload denied'
            },
            403);
      }
      return support.jsonResponse(
          request,
          {
            'code': '22023',
            'message': 'PHOTO_OBJECT_NOT_READY',
            'hint': 'Retry upload'
          },
          400);
    }));
    await expectLater(
        SupabaseRequestPhotoRepository(client: client)
            .upload(support.requestId, support.selected()),
        throwsA(isA<AppFailure>().having((error) => error.message,
            'unchanged retry', contains('thử gửi ảnh lại'))));
    expect(calls, hasLength(3));
    final output = lines.join('\n');
    expect(output, contains('photos.storage.uploadBinary FAILED'));
    expect(output, contains('status: 403'));
    expect(output, contains('photos.complete_after_upload_error FAILED'));
    expect(output, contains('code: 22023'));
    expect(output, contains('hint: Retry upload'));
  });
}
