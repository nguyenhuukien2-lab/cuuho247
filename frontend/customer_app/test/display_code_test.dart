import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/core/utils/display_code.dart';
import 'package:cuu_ho_247/widgets/tracking_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('missing codes remain missing and response codes keep the UUID identity', () {
    expect(displayCode(null), 'Chưa có mã');
    expect(displayCode('   '), 'Chưa có mã');
    expect(displayCode(' CH-000123 '), 'CH-000123');
    final request = RescueRequestData.fromJson({
      'id': '11111111-1111-4111-8111-111111111111',
      'request_code': 'CH-000123',
      'quote_code': 'BG-000456',
      'service_code': 'tire',
      'vehicle_kind': 'car',
      'location_text': 'Điểm cứu hộ',
      'created_at': '2026-10-05T00:00:00Z',
      'status': 'searching',
    });
    expect(request.id, '11111111-1111-4111-8111-111111111111');
    expect(request.requestCode, 'CH-000123');
    expect(request.quoteCode, 'BG-000456');
  });

  testWidgets('quote shows the persisted code or missing-code fallback', (tester) async {
    for (final code in <String?>['BG-000456', null, ' ']) {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: QuoteStatusCard(price: 100000, quoteCode: code)),
      ));
      expect(find.text('Mã báo giá: ${displayCode(code)}'), findsOneWidget);
    }
  });
}
