import 'package:flutter_test/flutter_test.dart';
import 'package:rescuer/core/utils/display_code.dart';
import 'package:rescuer/models/backend_models.dart';

void main() {
  test('RPC projections carry codes separately from UUID operation identities', () {
    const id = '11111111-1111-4111-8111-111111111111';
    final available = AvailableRequest.fromJson({
      'request_id': id, 'request_code': 'CH-000123',
      'service_type': 'tire', 'vehicle_type': 'car',
      'approximate_location': {
        'precision': 'coarse', 'cell_size_degrees': 0.01,
        'latitude': 10.77, 'longitude': 106.69,
      },
      'estimated_distance_km': 2,
    });
    final assignment = JobAssignment.fromJson({
      'assignment_id': id, 'request_id': id, 'vehicle_id': id,
      'request_code': 'CH-000123', 'quote_code': 'BG-000456',
      'state': 'accepted', 'version': 1,
    });
    final quote = QuoteDetails.fromJson({
      'quote_id': id, 'quote_code': 'BG-000456', 'assignment_id': id,
      'total_vnd': 100000, 'status': 'issued',
    });
    expect(available.id, id);
    expect(available.requestCode, 'CH-000123');
    expect(assignment.requestId, id);
    expect(assignment.requestCode, available.requestCode);
    expect(assignment.quoteCode, quote.quoteCode);
    expect(quote.id, id);
    expect(const RescuerSnapshot(profile: {'rescuer_code': 'DT-000007'}).rescuerCode, 'DT-000007');
    expect(displayCode(null), 'Chưa có mã');
    expect(displayCode(' '), 'Chưa có mã');
    expect(displayCode(' DT-000007 '), 'DT-000007');
  });
}
