import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rescuer/models/backend_models.dart';
import 'package:rescuer/services/rescuer_service.dart';

class UploadHarness extends SupabaseRescuerService {
  UploadHarness(super.client);
  @override
  String? get userId => 'test-user';
  final List<String> rpcCalls = [];
  bool failCompletion = false;
  @override
  Future<Json> mutate(String name, Json params) async {
    rpcCalls.add(name);
    if (name == 'rescuer_reserve_document') {
      expect(params, {
        'p_document_type': 'identity',
        'p_vehicle_id': null,
        'p_content_type': 'application/pdf',
        'p_byte_size': 5,
      });
      return {'document_id': 'test-doc', 'storage_path': 'test-user/test-doc'};
    }
    expect(name, 'rescuer_complete_document');
    expect(params, {'p_document_id': 'test-doc'});
    if (failCompletion) {
      failCompletion = false;
      throw http.ClientException('lost response');
    }
    return {'uploaded_at': '2026-01-01'};
  }
}

void main() {
  test('document completion retry reuses reservation and never overwrites uploaded object', () async {
    var uploads = 0;
    final httpClient = MockClient((request) async {
      uploads++;
      expect(
        request.url.path,
        '/storage/v1/object/rescuer-documents/test-user/test-doc',
      );
      expect(request.headers['x-upsert'], 'false');
      expect(
        request.headers['Content-Type'] ?? request.headers['content-type'],
        startsWith('multipart/form-data'),
      );
      expect(request.body.toLowerCase(), contains('content-type: application/pdf'));
      return http.Response(
        '{"Key":"rescuer-documents/test-user/test-doc"}',
        200,
      );
    });
    final client = SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_example',
      httpClient: httpClient,
    );
    final service = UploadHarness(client)..failCompletion = true;
    final bytes = Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2d]);
    await expectLater(
      service.uploadDocument('identity', null, bytes, 'application/pdf'),
      throwsA(isA<http.ClientException>()),
    );
    await service.uploadDocument('identity', null, bytes, 'application/pdf');
    expect(uploads, 1);
    expect(service.rpcCalls, [
      'rescuer_reserve_document',
      'rescuer_complete_document',
      'rescuer_complete_document',
    ]);
    await client.dispose();
    httpClient.close();
  });
}
