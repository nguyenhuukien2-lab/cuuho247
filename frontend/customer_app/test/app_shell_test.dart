import 'package:cuu_ho_247/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cuu_ho_247/widgets/customer_ui.dart';

void main() {
  testWidgets('keeps the five customer tabs when backend is not configured',
      (tester) async {
    await tester.pumpWidget(const RescueApp());
    await tester.pump();

    expect(find.text('Trang chủ'), findsOneWidget);
    expect(find.text('Cứu hộ'), findsOneWidget);
    expect(find.text('Đang xử lý'), findsOneWidget);
    expect(find.text('Lịch sử'), findsOneWidget);
    expect(find.text('Tài khoản'), findsOneWidget);

    await tester.tap(find.text('Cứu hộ'));
    await tester.pump();
    expect(find.text('Tạo yêu cầu cứu hộ'), findsOneWidget);
    expect(find.byType(ServiceGrid), findsOneWidget);
  });
}
