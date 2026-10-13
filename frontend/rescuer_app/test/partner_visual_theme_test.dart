import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuer/app/mobile_ui.dart';
import 'package:rescuer/widgets/app_components.dart';

void main() {
  test('partner palette, typography and controls use the requested tokens', () {
    expect(RescueColors.navy, const Color(0xFF0B2E4F));
    expect(RescueColors.navySoft, const Color(0xFF001932));
    expect(RescueColors.background, const Color(0xFFF9F9FF));
    expect(RescueColors.surface, Colors.white);
    expect(RescueColors.border, const Color(0xFFE5E7EB));
    expect(RescueType.page.fontSize, 24);
    expect(RescueType.section.fontSize, 18);
    expect(RescueType.title.fontSize, 16);
    expect(RescueType.title.fontWeight, FontWeight.w700);
    expect(RescueType.code.fontSize, 13);
    expect(RescueType.code.fontWeight, FontWeight.w700);
    expect(RescueType.body.fontSize, 14);
    expect(RescueType.caption.fontSize, 12);
    expect(RescueType.status.fontWeight, FontWeight.w600);
    expect(RescueType.page.fontFamily, 'PlusJakartaSans');
    expect(RescueType.body.fontFamily, 'Inter');
    expect(RescueType.button.fontSize, 16);
    expect(RescueRadius.card, 12);
    expect(RescueRadius.control, 16);
    expect(RescueRadius.pill, 999);
    expect(RescueSpace.bottomSafe, 96);
    final primary = RescueButtons.style(RescueButtonKind.primary);
    expect(primary.backgroundColor!.resolve({}), const Color(0xFFFD761A));
    expect(
      primary.backgroundColor!.resolve({WidgetState.pressed}),
      const Color(0xFFC2410C),
    );
    expect(
      primary.foregroundColor!.resolve({WidgetState.disabled}),
      const Color(0xFF9CA3AF),
    );
    expect(
      RescueButtons.style(RescueButtonKind.outline).backgroundColor!
          .resolve({}),
      Colors.transparent,
    );
    expect(
      RescueSurfaces.decoration(RescueCardKind.order).border,
      Border.all(color: const Color(0xFFFED7AA).withValues(alpha: .35)),
    );
  });

  test('order and profile state colors stay distinct', () {
    for (final (state, foreground, background) in [
      ('searching', 0xFF1D4ED8, 0xFFDBEAFE),
      ('accepted', 0xFF1D4ED8, 0xFFDBEAFE),
      ('arriving', 0xFF1D4ED8, 0xFFDBEAFE),
      ('in_progress', 0xFFC2410C, 0xFFFFF1E8),
      ('completed', 0xFF15803D, 0xFFDCFCE7),
      ('cancelled', 0xFFB91C1C, 0xFFFEE2E2),
      ('approved', 0xFF15803D, 0xFFDCFCE7),
      ('pending', 0xFFB45309, 0xFFFEF3C7),
      ('submitted', 0xFFB45309, 0xFFFEF3C7),
      ('rejected', 0xFFB91C1C, 0xFFFEE2E2),
      ('suspended', 0xFFB91C1C, 0xFFFEE2E2),
    ]) {
      final appearance = RescueStatus.appearance(state);
      expect(appearance.$2, Color(foreground), reason: state);
      expect(appearance.$3, Color(background), reason: state);
    }
  });

  testWidgets('badges render the right colors at 320px with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    for (final (label, tone, foreground, background) in [
      ('Online', BadgeTone.green, 0xFF15803D, 0xFFDCFCE7),
      ('Offline', BadgeTone.neutral, 0xFF4B5563, 0xFFF3F4F6),
      ('GPS chưa sẵn sàng', BadgeTone.amber, 0xFFB45309, 0xFFFEF3C7),
      ('Yêu cầu mới', BadgeTone.orange, 0xFFC2410C, 0xFFFFF1E8),
      ('Vị trí nhập tay', BadgeTone.manualLocation, 0xFF92400E, 0xFFFEF3C7),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: RescueTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: Align(
                alignment: Alignment.topLeft,
                child: StatusBadge(label: label, tone: tone),
              ),
            ),
          ),
        ),
      );
      expect(
        tester.widget<Text>(find.text(label)).style!.color,
        Color(foreground),
      );
      final container = find.descendant(
        of: find.byType(StatusBadge),
        matching: find.byType(Container),
      );
      final decoration =
          tester.widget<Container>(container).decoration as BoxDecoration;
      expect(decoration.color, Color(background));
      expect(find.textContaining('V? tr?'), findsNothing);
      expect(find.textContaining('�'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}
