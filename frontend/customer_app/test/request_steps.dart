import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cuu_ho_247/screens/new_request_screen.dart';
import 'package:cuu_ho_247/widgets/booking_ui.dart';

Future<void> requestStep(WidgetTester tester, int step) async {
  final chip = find.byKey(ValueKey('request-step-$step'));
  if (chip.evaluate().isEmpty) return;
  await tester.ensureVisible(chip);
  await tester.pump();
  final indicator = find.byType(CustomerStepIndicator);
  final needsNavigation = indicator.evaluate().isNotEmpty
      ? tester.widget<CustomerStepIndicator>(indicator).step != step
      : !tester.widget<ChoiceChip>(chip).selected;
  if (needsNavigation) {
    await tester.tap(chip);
    await tester.pump(const Duration(milliseconds: 300));
  }
}

/// Reveal a retained field or an action through the same step controls as a user.
Future<void> revealRequest(WidgetTester tester, Finder target) async {
  if (find.byType(NewRequestScreen).evaluate().isNotEmpty) {
    int? section;
    for (final element in target.evaluate()) {
      element.visitAncestorElements((ancestor) {
        final key = ancestor.widget.key;
        if (key is ValueKey<String> &&
            key.value.startsWith('request-section-')) {
          section = int.parse(key.value.split('-').last);
          return false;
        }
        return true;
      });
      if (section != null) break;
    }
    if (section != null) {
      await requestStep(tester, const [0, 1, 2, 3, 3, 4][section!]);
    } else if (target.evaluate().isEmpty) {
      for (var step = 0; step < 5; step++) {
        await requestStep(tester, step);
        if (target.evaluate().isNotEmpty) break;
      }
    }
  }
  await tester.ensureVisible(target);
  await tester.pump();
}

Future<void> tapRequest(WidgetTester tester, Finder target) async {
  await revealRequest(tester, target);
  final isSubmit = target.evaluate().any((element) =>
          element.widget is Text &&
          (element.widget as Text).data == 'XÁC NHẬN ĐẶT CỨU HỘ') ||
      find
          .descendant(of: target, matching: find.text('XÁC NHẬN ĐẶT CỨU HỘ'))
          .evaluate()
          .isNotEmpty;
  // Complete the new footer's UI prerequisite; keep all submit assertions.
  if (find.byType(NewRequestScreen).evaluate().isNotEmpty && isSubmit) {
    final confirmation = find.byType(CheckboxListTile);
    if (confirmation.evaluate().isEmpty) {
      final scroll = tester
          .widget<CustomScrollView>(find.byType(CustomScrollView))
          .controller!;
      for (var attempt = 0;
          attempt < 8 && confirmation.evaluate().isEmpty;
          attempt++) {
        scroll.jumpTo(scroll.position.maxScrollExtent);
        await tester.pump();
      }
    }
    if (confirmation.evaluate().isNotEmpty &&
        !tester.widget<CheckboxListTile>(confirmation).value!) {
      await tester.ensureVisible(confirmation);
      await tester.tap(confirmation);
      await tester.pump();
      await tester.ensureVisible(target);
    }
  }
  await tester.tap(target);
}

Future<void> enterRequest(
    WidgetTester tester, Finder target, String value) async {
  await revealRequest(tester, target);
  await tester.enterText(target, value);
}
