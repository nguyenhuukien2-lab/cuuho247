import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rescuer/app/connected_app.dart';
import 'package:rescuer/app/partner_email_confirmation.dart';
import 'package:rescuer/app/rescuer_controller.dart';
import 'package:rescuer/services/partner_email_auth.dart';
import 'package:rescuer/services/rescuer_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'connected_app_test.dart' show FakeService, FakeLocation;
import 'partner_auth_test.dart' show openRegistration, fillRegistration;

class EmailAuthFake extends FakeService implements PartnerEmailAuth {
  @override
  String? accountEmail = 'partner@example.invalid';
  @override
  bool emailVerified = false;
  int verifications = 0, checks = 0, sends = 0, signUps = 0;
  bool serverVerified = true;
  Object? verifyFailure, checkFailure, sendFailure;
  Completer<void>? verifyGate, checkGate, sendGate;
  @override
  Future<PartnerSignUpResult> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    signUps++;
    return const PartnerSignUpResult('rescuer', needsEmailConfirmation: true);
  }

  @override
  Future<void> verifyEmailOtp(String email, String code) async {
    verifications++;
    if (verifyGate != null) await verifyGate!.future;
    if (verifyFailure != null) throw verifyFailure!;
    userId = 'rescuer';
    changes.add(userId);
  }

  @override
  Future<bool> refreshEmailVerification() async {
    checks++;
    if (checkGate != null) await checkGate!.future;
    if (checkFailure != null) throw checkFailure!;
    emailVerified = serverVerified;
    return serverVerified;
  }

  @override
  Future<void> resendEmailConfirmation(String email) async {
    sends++;
    if (sendGate != null) await sendGate!.future;
    if (sendFailure != null) throw sendFailure!;
  }
}

void main() {
  test('registration time and masked email preserve the existing safe metadata contract', () {
    expect(
      partnerRegistrationTime(DateTime.parse('2026-10-16T14:19:00Z')),
      '21:19 - 16/10/2026',
    );
    expect(
      partnerRegistrationTime(DateTime.parse('2026-12-31T20:07:00Z')),
      '03:07 - 01/01/2027',
    );
    expect(maskPartnerEmail('partner@example.invalid'), 'p***@example.invalid');
    expect(maskPartnerEmail('a@example.invalid'), 'a***@example.invalid');
    expect(maskPartnerEmail(null), '');
  });

  for (final code in ['', '12345', '1234567', 'abcdef', '123 45']) {
    test(
      'malformed OTP is rejected locally without an Auth request: length ${code.length}',
      () async {
        final auth = EmailAuthFake();
        addTearDown(() => auth.changes.close());
        final c = PartnerEmailConfirmation(auth, onVerified: () async {});
        addTearDown(c.dispose);
        c.waitFor('partner@example.invalid');
        await c.verify(code);
        expect(c.message, incorrectEmailOtp);
        expect(auth.verifications, 0);
      },
    );
  }

  test('wrong code inside the configured lifetime is friendly even for ambiguous otp_expired', () async {
    final auth = EmailAuthFake()
      ..verifyFailure = const AuthException(
        'Token has expired or is invalid',
        code: 'otp_expired',
      );
    addTearDown(() => auth.changes.close());
    final c = PartnerEmailConfirmation(auth, onVerified: () async {});
    addTearDown(c.dispose);
    c.waitFor('partner@example.invalid', codeSent: true);
    await c.verify('123456');
    expect(c.stage, EmailConfirmationStage.invalid);
    expect(c.message, incorrectEmailOtp);
    expect(c.message, isNot(contains('otp_expired')));
  });

  test(
    'expired window uses expiry message only after server rejects the code',
    () async {
      final auth = EmailAuthFake()
        ..verifyFailure = const AuthException(
          'Token has expired or is invalid',
          code: 'otp_expired',
        );
      addTearDown(() => auth.changes.close());
      var now = DateTime.utc(2026, 10, 16);
      final c = PartnerEmailConfirmation(
        auth,
        now: () => now,
        onVerified: () async {},
      );
      addTearDown(c.dispose);
      c.waitFor('partner@example.invalid', codeSent: true);
      now = now.add(partnerEmailOtpLifetime);
      await c.verify('123456');
      expect(auth.verifications, 1);
      expect(c.stage, EmailConfirmationStage.expired);
      expect(c.message, expiredEmailOtp);
    },
  );

  test('local clock never rejects a code that Supabase accepts', () async {
    final auth = EmailAuthFake();
    addTearDown(() => auth.changes.close());
    var now = DateTime.utc(2026, 10, 16);
    final c = PartnerEmailConfirmation(
      auth,
      now: () => now,
      onVerified: () async {},
    );
    addTearDown(c.dispose);
    c.waitFor('partner@example.invalid', codeSent: true);
    now = now.add(partnerEmailOtpLifetime * 2);
    await c.verify('123456');
    expect(c.stage, EmailConfirmationStage.verified);
  });

  test(
    'server verification gates continuation and duplicate submit is ignored',
    () async {
      final auth = EmailAuthFake()..checkGate = Completer<void>();
      addTearDown(() => auth.changes.close());
      var resumed = 0;
      final c = PartnerEmailConfirmation(
        auth,
        onVerified: () async {
          resumed++;
        },
      );
      addTearDown(c.dispose);
      c.waitFor('partner@example.invalid');
      final pending = c.verify('123456');
      await Future<void>.delayed(Duration.zero);
      await c.verify('123456');
      expect(resumed, 0);
      expect(auth.verifications, 1);
      expect(c.busy, isTrue);
      auth.checkGate!.complete();
      await pending;
      expect(c.stage, EmailConfirmationStage.verified);
      expect(resumed, 1);
    },
  );

  test('an unverified user cannot enter profile completion', () async {
    final auth = EmailAuthFake()..serverVerified = false;
    addTearDown(() => auth.changes.close());
    var resumed = false;
    final c = PartnerEmailConfirmation(
      auth,
      onVerified: () async {
        resumed = true;
      },
    );
    addTearDown(c.dispose);
    c.waitFor('partner@example.invalid');
    await c.verify('123456');
    expect(resumed, isFalse);
    expect(c.stage, EmailConfirmationStage.invalid);
  });

  test('a different verified account cannot satisfy verification for the entered email', () async {
    final auth = EmailAuthFake()..accountEmail = 'different@example.invalid';
    addTearDown(() => auth.changes.close());
    var resumed = false;
    final c = PartnerEmailConfirmation(
      auth,
      onVerified: () async {
        resumed = true;
      },
    );
    addTearDown(c.dispose);
    c.waitFor('partner@example.invalid');
    await c.verify('123456');
    expect(resumed, isFalse);
  });

  test('offline verify never reports success and may be retried by entering the code again', () async {
    final auth = EmailAuthFake()..verifyFailure = AuthRetryableFetchException();
    addTearDown(() => auth.changes.close());
    final c = PartnerEmailConfirmation(auth, onVerified: () async {});
    addTearDown(c.dispose);
    c.waitFor('partner@example.invalid');
    await c.verify('123456');
    expect(c.stage, EmailConfirmationStage.networkError);
    expect(c.canRetryVerification, isFalse);
    auth.verifyFailure = null;
    await c.verify('123456');
    expect(c.stage, EmailConfirmationStage.verified);
  });

  test(
    'offline getUser retries only the server check, not a consumed OTP',
    () async {
      final auth = EmailAuthFake()
        ..checkFailure = AuthRetryableFetchException();
      addTearDown(() => auth.changes.close());
      final c = PartnerEmailConfirmation(auth, onVerified: () async {});
      addTearDown(c.dispose);
      c.waitFor('partner@example.invalid');
      await c.verify('123456');
      expect(c.canRetryVerification, isTrue);
      auth.checkFailure = null;
      await c.retryVerification();
      expect(c.stage, EmailConfirmationStage.verified);
      expect(auth.verifications, 1);
      expect(auth.checks, 2);
    },
  );

  test('countdown starts at signup and resend; no duplicate send or raw provider error', () async {
    final auth = EmailAuthFake();
    addTearDown(() => auth.changes.close());
    var now = DateTime.utc(2026, 10, 16);
    final c = PartnerEmailConfirmation(
      auth,
      now: () => now,
      onVerified: () async {},
    );
    addTearDown(c.dispose);
    c.waitFor('partner@example.invalid', codeSent: true);
    expect(c.resendSecondsRemaining, 60);
    await c.resend();
    expect(auth.sends, 0);
    now = now.add(const Duration(seconds: 60));
    await c.resend();
    expect(c.message, newConfirmationCodeSent);
    expect(c.resendSecondsRemaining, 60);
    now = now.add(const Duration(seconds: 60));
    auth.sendFailure = const AuthException(
      'provider internal detail',
      statusCode: '429',
    );
    await c.resend();
    expect(c.message, contains('chờ một phút'));
    expect(c.message, isNot(contains('provider internal')));
  });

  test(
    'resend failure is recoverable and cannot overlap a second request',
    () async {
      final auth = EmailAuthFake()
        ..sendGate = Completer<void>()
        ..sendFailure = AuthRetryableFetchException();
      addTearDown(() => auth.changes.close());
      final c = PartnerEmailConfirmation(auth, onVerified: () async {});
      addTearDown(c.dispose);
      c.waitFor('partner@example.invalid');
      final pending = c.resend();
      await c.resend();
      expect(auth.sends, 1);
      auth.sendGate!.complete();
      await pending;
      expect(c.sending, isFalse);
      expect(c.message, contains('Kiểm tra kết nối'));
      expect(c.resendSecondsRemaining, 0);
    },
  );

  test('dispose ignores a late in-flight verification response', () async {
    final auth = EmailAuthFake()..checkGate = Completer<void>();
    addTearDown(() => auth.changes.close());
    var resumed = false;
    final c = PartnerEmailConfirmation(
      auth,
      onVerified: () async {
        resumed = true;
      },
    );
    c.waitFor('partner@example.invalid');
    final pending = c.verify('123456');
    await Future<void>.delayed(Duration.zero);
    c.dispose();
    auth.checkGate!.complete();
    await pending;
    expect(resumed, isFalse);
  });

  test('Supabase verifyOTP uses the official email token API and verifies user from Auth', () async {
    final calls = <String>[];
    final user = {
      'id': '11111111-1111-4111-8111-111111111111',
      'aud': 'authenticated',
      'role': 'authenticated',
      'email': 'partner@example.invalid',
      'email_confirmed_at': '2026-10-16T14:20:00Z',
      'app_metadata': {},
      'user_metadata': {},
      'created_at': '2026-10-16T14:19:00Z',
    };
    final transport = MockClient((request) async {
      calls.add(request.url.path);
      if (request.url.path == '/auth/v1/verify') {
        final body = jsonDecode(request.body) as Map;
        expect(body['email'], 'partner@example.invalid');
        expect(body['type'], 'email');
        expect(body['token'], '123456');
        expect(body['redirect_to'], isNull);
        expect(body.containsKey('token_hash'), isFalse);
        return http.Response(
          jsonEncode({
            'access_token': 'fixture-access-token',
            'refresh_token': 'fixture-refresh-token',
            'token_type': 'bearer',
            'expires_in': 3600,
            'user': user,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      }
      expect(request.url.path, '/auth/v1/user');
      return http.Response(
        jsonEncode(user),
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_example',
      httpClient: transport,
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
        autoRefreshToken: false,
      ),
    );
    addTearDown(client.dispose);
    final service = SupabaseRescuerService(client);
    await service.verifyEmailOtp(' partner@example.invalid ', '123456');
    expect(await service.refreshEmailVerification(), isTrue);
    expect(calls, ['/auth/v1/verify', '/auth/v1/user']);
  });

  test('Supabase resend sends signup email without a redirect', () async {
    final transport = MockClient((request) async {
      expect(request.url.path, '/auth/v1/resend');
      expect(request.url.queryParameters.containsKey('redirect_to'), isFalse);
      final data = jsonDecode(request.body) as Map;
      expect(data['email'], 'partner@example.invalid');
      expect(data['type'], 'signup');
      return http.Response(
        '{}',
        200,
        headers: {'content-type': 'application/json'},
      );
    });
    final client = SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_example',
      httpClient: transport,
      authOptions: const AuthClientOptions(
        authFlowType: AuthFlowType.implicit,
        autoRefreshToken: false,
      ),
    );
    addTearDown(client.dispose);
    await SupabaseRescuerService(client)
        .resendEmailConfirmation(' partner@example.invalid ');
  });

  test('shared signup template isolates partner OTP from the customer confirmation link', () {
    final html = File('docs/email/confirm_signup_vi.html').readAsStringSync();
    expect(html, contains('{{ .Token }}'));
    final mechanism = RegExp(
      r'\{\{ if \$partner \}\}\s*<p style="margin:24px 0 18px;[\s\S]*?\{\{ end \}\}',
    ).firstMatch(html)!.group(0)!;
    final branches = mechanism.split('{{ else }}');
    expect(branches, hasLength(2));
    expect(branches.first, contains('{{ .Token }}'));
    expect(branches.first, isNot(contains('.ConfirmationURL')));
    expect(branches.first, isNot(contains('href=')));
    expect(branches.last, contains('href="{{ .ConfirmationURL }}"'));
    expect(branches.last, isNot(contains('.Token')));
    expect(branches.last, isNot(contains('nhập mã')));
    final subject = File('docs/email/confirm_signup_subject.txt')
        .readAsStringSync();
    expect(
      subject,
      contains('{{ else }}Cứu Hộ 24/7 | Xác nhận địa chỉ email{{ end }}'),
    );
    for (final marker in [
      'CỨU HỘ',
      '.Data.full_name',
      '.Email',
      '.Data.registered_at',
      'Chưa xác nhận email',
      'Hoàn thiện hồ sơ đối tác',
      'Quản trị viên Cứu Hộ 24/7',
      'Vui lòng không trả lời email này.',
      '© Cứu Hộ 24/7',
    ]) {
      expect(html, contains(marker));
    }
  });

  testWidgets(
    'successful partner registration opens the six-digit OTP screen',
    (tester) async {
      final auth = EmailAuthFake();
      addTearDown(() => auth.changes.close());
      final c = RescuerController(auth, FakeLocation());
      await tester.pumpWidget(ConnectedRescuerApp(controller: c));
      await tester.pumpAndSettle();
      await openRegistration(tester);
      await fillRegistration(tester);
      final submit = find.byKey(const ValueKey('register-submit'));
      await tester.ensureVisible(submit);
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(auth.signUps, 1);
      expect(find.text('Xác nhận email'), findsOneWidget);
      expect(find.text('p***@example.invalid'), findsOneWidget);
      expect(c.emailConfirmation!.resendSecondsRemaining, greaterThan(0));
      expect(c.signedIn, isFalse);
      expect(auth.calls, isEmpty);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'six OTP boxes accept paste, mask email, verify and continue to the profile',
    (tester) async {
      final auth = EmailAuthFake();
      addTearDown(() => auth.changes.close());
      final c = RescuerController(auth, FakeLocation());
      c.emailConfirmation!.waitFor('partner@example.invalid', codeSent: true);
      await tester.pumpWidget(ConnectedRescuerApp(controller: c));
      await tester.pumpAndSettle();
      expect(find.text('Xác nhận email'), findsOneWidget);
      expect(find.text('p***@example.invalid'), findsOneWidget);
      expect(find.text('partner@example.invalid'), findsNothing);
      for (var i = 0; i < 6; i++) {
        expect(find.byKey(ValueKey('email-otp-$i')), findsOneWidget);
      }
      final first = find.byKey(const ValueKey('email-otp-0'));
      await tester.enterText(first, '123456');
      await tester.pumpAndSettle();
      for (var i = 0; i < 6; i++) {
        expect(
          tester
              .widget<TextField>(find.byKey(ValueKey('email-otp-$i')))
              .controller!
              .text,
          '123456'[i],
        );
      }
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('verify-email-otp')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('verify-email-otp')));
      await tester.pumpAndSettle();
      expect(find.text('Xác nhận email thành công'), findsOneWidget);
      expect(c.canOnline, isFalse);
      expect(auth.calls, isEmpty);
      await tester.tap(find.text('Tiếp tục hoàn thiện hồ sơ đối tác'));
      await tester.pumpAndSettle();
      expect(c.tab, 4);
      expect(find.text('Họ và tên'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'resend countdown disables the button, reaches zero and resets after sending',
    (tester) async {
      final auth = EmailAuthFake();
      addTearDown(() => auth.changes.close());
      var now = DateTime.utc(2026, 10, 16);
      final c = RescuerController(auth, FakeLocation(), now: () => now);
      c.emailConfirmation!.waitFor('partner@example.invalid', codeSent: true);
      await tester.pumpWidget(ConnectedRescuerApp(controller: c));
      await tester.pumpAndSettle();
      final resend = find.byKey(const ValueKey('resend-email-otp'));
      expect(tester.widget<TextButton>(resend).onPressed, isNull);
      expect(find.text('Có thể gửi lại mã sau 60s'), findsOneWidget);
      now = now.add(const Duration(seconds: 60));
      await tester.pump(const Duration(seconds: 1));
      await tester.ensureVisible(resend);
      await tester.pumpAndSettle();
      expect(tester.widget<TextButton>(resend).onPressed, isNotNull);
      await tester.tap(resend);
      await tester.pumpAndSettle();
      expect(auth.sends, 1);
      expect(find.text(newConfirmationCodeSent), findsOneWidget);
      expect(tester.widget<TextButton>(resend).onPressed, isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'wrong code clears boxes and shows the requested text without technical errors',
    (tester) async {
      final auth = EmailAuthFake()
        ..verifyFailure = const AuthException(
          'Token has expired or is invalid',
          code: 'otp_expired',
        );
      addTearDown(() => auth.changes.close());
      final c = RescuerController(auth, FakeLocation());
      c.emailConfirmation!.waitFor('partner@example.invalid', codeSent: true);
      await tester.pumpWidget(ConnectedRescuerApp(controller: c));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.byKey(const ValueKey('email-otp-0')),
        '123456',
      );
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('verify-email-otp')),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('verify-email-otp')));
      await tester.pumpAndSettle();
      expect(find.text(incorrectEmailOtp), findsOneWidget);
      expect(find.textContaining('otp_expired'), findsNothing);
      for (var i = 0; i < 6; i++) {
        expect(
          tester
              .widget<TextField>(find.byKey(ValueKey('email-otp-$i')))
              .controller!
              .text,
          '',
        );
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('OTP screen fits 320px with large text', (tester) async {
    final auth = EmailAuthFake();
    addTearDown(() => auth.changes.close());
    final c = RescuerController(auth, FakeLocation());
    c.emailConfirmation!.waitFor('partner@example.invalid');
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.5;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(ConnectedRescuerApp(controller: c));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
