import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:rescuer/services/public_system_config.dart';
import 'package:rescuer/app/mobile_ui.dart';
import 'package:rescuer/screens/payment/rescuer_cash_screen.dart';
import 'package:rescuer/services/payment_service.dart';

import 'cash_payment_test.dart' as fixtures;

void main() {
  testWidgets('cash UI disables confirmation when central policy disables it', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final source = fixtures.CashSource();
    final controller = fixtures.controller(source);
    await tester.pumpWidget(
      MaterialApp(
        theme: RescueTheme.light,
        home: PublicSystemConfigScope(
          app: 'rescuer',
          loader: (app) async => {
            'version': '1',
            'values': {'payment.cash_confirmation_enabled': false},
          },
          child: RescuerCashScreen(
            controller: controller,
            requestCode: 'CH-000001',
          ),
        ),
      ),
    );
    await tester.pump();
    source.emit(PaymentSignalKind.connected);
    await tester.pumpAndSettle();
    expect(controller.canConfirm, isTrue);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('collect-cash')),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      tester
          .widget<RescueButton>(find.byKey(const ValueKey('collect-cash')))
          .onPressed,
      isNull,
    );
    expect(source.calls, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    await tester.runAsync(source.close);
  });
  test('default hints preserve current behavior; unknown private keys are discarded', () {
    const defaults = PublicSystemConfig();
    expect(defaults.maxPhotos, 3);
    expect(defaults.requestsEnabled, isTrue);
    expect(defaults.bankEnabled, isTrue);
    final config = PublicSystemConfig.fromJson({
      'version': '2',
      'values': {
        'customer.max_photos': 1,
        'customer.requests_enabled': false,
        'security.role_permissions': {
          'security': ['super_admin'],
        },
        'sepay_secret': 'must not persist',
      },
    });
    expect(config.maxPhotos, 1);
    expect(config.requestsEnabled, isFalse);
    expect(config.values.containsKey('sepay_secret'), isFalse);
    expect(config.values.containsKey('security.role_permissions'), isFalse);
    expect(() => config.values['x'] = true, throwsUnsupportedError);
  });
  test('kill switches, banner flag and invalid payloads', () {
    final config = PublicSystemConfig.fromJson({
      'version': '9007199254740993',
      'values': {
        'customer.max_photos': 9,
        'security.kill_new_requests': true,
        'security.kill_new_bank_intents': true,
        'customer.banner': 'Hello',
        'customer.banner_enabled': true,
      },
    });
    expect(config.maxPhotos, 3);
    expect(config.requestsEnabled, isFalse);
    expect(config.bankEnabled, isFalse);
    expect(config.banner, 'Hello');
    expect(
      () => PublicSystemConfig.fromJson({'version': 'bad', 'values': {}}),
      throwsFormatException,
    );
    expect(
      () => PublicSystemConfig.fromJson({'version': '1', 'values': []}),
      throwsFormatException,
    );
  });
  testWidgets(
    'scope refreshes, retains last config on failure and discards stale versions',
    (tester) async {
      var calls = 0;
      final next = Completer<Object?>();
      await tester.pumpWidget(
        MaterialApp(
          home: PublicSystemConfigScope(
            app: 'customer',
            loader: (app) async {
              expect(app, 'customer');
              calls++;
              if (calls == 1) {
                return {
                  'version': '3',
                  'values': {
                    'customer.banner_enabled': true,
                    'customer.banner': 'Server banner',
                  },
                };
              }
              if (calls == 2) throw StateError('offline');
              if (calls == 3) {
                return {
                  'version': '2',
                  'values': {
                    'customer.banner_enabled': true,
                    'customer.banner': 'Stale',
                  },
                };
              }
              return next.future;
            },
            child: Builder(
              builder: (context) => Scaffold(
                body: Text('v${PublicSystemConfig.of(context).version}'),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(find.text('Server banner'), findsOneWidget);
      expect(find.text('v3'), findsOneWidget);
      await tester.pump(const Duration(seconds: 60));
      await tester.pump();
      expect(find.text('Server banner'), findsOneWidget);
      await tester.pump(const Duration(seconds: 60));
      await tester.pump();
      expect(find.text('Stale'), findsNothing);
      await tester.pump(const Duration(seconds: 60));
      await tester.pumpWidget(const SizedBox());
      next.complete({'version': '4', 'values': {}});
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );
}
