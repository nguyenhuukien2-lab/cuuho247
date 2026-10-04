import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cuu_ho_247/screens/new_request_screen.dart';

Future<void> requestStep(WidgetTester tester, int step) async {
  final chip = find.byKey(ValueKey('request-step-$step'));
  if (chip.evaluate().isEmpty) return;
  await tester.ensureVisible(chip);
  await tester.pump();
  if (!tester.widget<ChoiceChip>(chip).selected) {
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
  await tester.tap(target);
}

Future<void> enterRequest(
    WidgetTester tester, Finder target, String value) async {
  await revealRequest(tester, target);
  await tester.enterText(target, value);
}
