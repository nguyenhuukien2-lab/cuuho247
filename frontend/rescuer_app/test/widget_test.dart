import 'package:flutter_test/flutter_test.dart';
import 'package:rescuer/main.dart';

void main() {
  testWidgets('shows the initial preparation message', (tester) async {
    await tester.pumpWidget(const MainApp());

    expect(find.text('Cứu Hộ 24/7 Đối tác — đang chuẩn bị'), findsOneWidget);
  });
}
