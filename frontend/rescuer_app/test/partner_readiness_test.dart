import 'package:flutter_test/flutter_test.dart';
import 'package:rescuer/models/backend_models.dart';
import 'package:rescuer/app/rescuer_controller.dart';
import 'connected_app_test.dart' show FakeService, FakeLocation, approved;

void main() {
  test('profile approval alone cannot grant Online without backend readiness', () {
    final base = approved();
    final snapshot = RescuerSnapshot(
      profile: base.profile, vehicles: base.vehicles, capabilities: base.capabilities,
    );
    expect(snapshot.approved, isTrue);
    expect(snapshot.eligibleVehicles, isEmpty);
    expect(snapshot.documentsApproved, isFalse);
  });
  test('refresh switches pending to ready and revokes readiness after rejection', () async {
    final base = approved();
    RescuerSnapshot pending() => RescuerSnapshot(
      profile: base.profile, vehicles: base.vehicles, capabilities: base.capabilities,
      readiness: const {'can_online': false, 'eligible_vehicle_ids': [], 'identity_approved': false, 'license_approved': true},
    );
    final service = FakeService()..userId = 'rescuer'..snapshot = pending();
    final controller = RescuerController(service, FakeLocation())..start();
    await Future<void>.delayed(Duration.zero);
    expect(controller.canOnline, isFalse);
    service.snapshot = base;
    await controller.refreshProfile();
    expect(controller.canOnline, isTrue);
    expect(controller.checklist.firstWhere((i) => i.title == 'Giấy tờ/xác minh').complete, isTrue);
    service.snapshot = pending();
    await controller.refreshProfile();
    expect(controller.canOnline, isFalse);
    controller.dispose();
    await service.changes.close();
  });
}
