import 'package:cuu_ho_247/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cuu_ho_247/widgets/customer_ui.dart';

void main() {
  testWidgets('keeps the five customer tabs when backend is not configured',
      (tester) async {
    await tester.pumpWidget(const RescueApp());
    await tester.pump();

    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Đặt cứu hộ'), findsOneWidget);
    expect(find.text('Theo dõi'), findsOneWidget);
    expect(find.text('Lịch sử'), findsOneWidget);
    expect(find.text('Tài khoản'), findsOneWidget);

    await tester.tap(find.text('Đặt cứu hộ'));
    await tester.pump();
    expect(find.text('Chọn dịch vụ'), findsOneWidget);
    expect(find.byType(ServiceGrid), findsOneWidget);
  });
}
