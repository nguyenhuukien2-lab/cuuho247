import 'package:cuu_ho_247/app/app_theme.dart';
import 'package:cuu_ho_247/app/mobile_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> mount(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: const TextScaler.linear(1.5)),
        child: child!,
      ),
      home: Scaffold(
        body: SingleChildScrollView(
          padding: RescueSpace.page,
          child: child,
        ),
      ),
    ));
    await tester.pump();
  }

  testWidgets(
      'all button styles wrap long labels and preserve disabled callbacks',
      (tester) async {
    var calls = 0;
    for (final kind in RescueButtonKind.values) {
      for (final state in ['enabled', 'disabled', 'loading']) {
        await mount(
            tester,
            RescueButton(
              label: 'Xác nhận hành động tiếp theo cho yêu cầu cứu hộ',
              icon: Icons.arrow_forward,
              kind: kind,
              loading: state == 'loading',
              onPressed: state == 'disabled' ? null : () => calls++,
            ));
        final button = find.byType(RescueButton);
        expect(tester.getSize(button).height, greaterThanOrEqualTo(48));
        final before = calls;
        await tester.tap(button);
        await tester.pump();
        expect(calls, before + (state == 'enabled' ? 1 : 0));
        expect(tester.takeException(), isNull);
      }
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('order and review badges fit narrow cards with large text',
      (tester) async {
    for (final status in [
      'searching',
      'accepted',
      'arriving',
      'in_progress',
      'completed',
      'cancelled',
      'approved',
      'pending',
      'suspended',
    ]) {
      await mount(
          tester,
          RescueCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Trạng thái hiện tại', style: RescueType.section),
                const SizedBox(height: RescueSpace.sm),
                Wrap(
                    spacing: RescueSpace.sm,
                    runSpacing: RescueSpace.sm,
                    children: [
                      RescueStatusBadge(status: status),
                      const Text('CH-20261005-123456', style: RescueType.code),
                    ]),
                const RescueStatusBadge(
                  status: 'accepted',
                  label: 'Đã nhận yêu cầu và đang chuẩn bị hỗ trợ khách hàng',
                ),
              ],
            ),
          ));
      expect(find.byType(RescueStatusBadge), findsNWidgets(2));
      expect(tester.takeException(), isNull);
    }
    await mount(tester, const RescueStatusBadge(status: 'unknown'));
    expect(find.text('Chưa xác định'), findsOneWidget);
    expect(find.text('Chưa nộp'), findsNothing);
  });

  testWidgets('feedback retains descriptions, progress and retry actions',
      (tester) async {
    var retries = 0;
    for (final kind in RescueFeedbackKind.values) {
      await mount(
          tester,
          RescueCard(
            padding: EdgeInsets.zero,
            child: RescueFeedback(
              kind: kind,
              title: 'Thông tin về yêu cầu cứu hộ của bạn',
              message:
                  'Kiểm tra thông tin hiện tại và thử tải lại khi cần thiết.',
              action: RescueButton(
                kind: RescueButtonKind.secondary,
                label: 'Tải lại thông tin',
                onPressed: () => retries++,
              ),
            ),
          ));
      expect(
          find.text(
              'Kiểm tra thông tin hiện tại và thử tải lại khi cần thiết.'),
          findsOneWidget);
      expect(find.byType(CircularProgressIndicator),
          kind == RescueFeedbackKind.loading ? findsOneWidget : findsNothing);
      await tester.ensureVisible(find.text('Tải lại thông tin'));
      final before = retries;
      await tester.tap(find.text('Tải lại thông tin'));
      await tester.pump();
      expect(retries, before + 1);
      expect(tester.takeException(), isNull);
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
