import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/services/supabase_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('maps a rescue request returned by Supabase', () {
    final request = RescueRequestData.fromJson({
      'id': '00000000-0000-4000-8000-000000000001',
      'service_code': 'tire',
      'vehicle_kind': 'car',
      'location_text': 'Km 12, Quốc lộ 1A',
      'created_at': '2026-09-30T10:00:00Z',
      'status': 'searching',
      'description': 'Nổ lốp trước',
      'quoted_price': null,
    });

    expect(request.service, RescueService.tire);
    expect(request.vehicle, VehicleKind.car);
    expect(request.stage, RequestStage.searching);
    expect(request.address, 'Km 12, Quốc lộ 1A');
  });

  test('generates valid and distinct UUID v4 idempotency keys', () {
    final first = SupabaseService.newClientRequestId();
    final second = SupabaseService.newClientRequestId();
    final uuidV4 = RegExp(
        r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$');
    expect(first, matches(uuidV4));
    expect(second, matches(uuidV4));
    expect(second, isNot(first));
  });

  test('reports an unconfigured backend without touching Supabase', () async {
    if (BackendConfiguration.isConfigured) return;
    final controller = AppController();
    await controller.initialize();
    expect(controller.backendConfigured, isFalse);
    expect(controller.restoringSession, isFalse);
    expect(controller.loadError, isNotNull);
    controller.dispose();
  });
}
