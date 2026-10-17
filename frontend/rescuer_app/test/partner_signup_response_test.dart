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
import 'package:rescuer/screens/auth/partner_email_confirmation_screen.dart';
import 'package:rescuer/screens/preparation/partner_registration_screen.dart';
import 'package:rescuer/services/partner_auth_validation.dart';
import 'package:rescuer/services/rescuer_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'connected_app_test.dart' show FakeLocation;
import 'partner_auth_test.dart'
    show fillRegistration, openRegistration, submitRegistration;

const _userId = '11111111-1111-4111-8111-111111111111';
const _email = 'partner@example.invalid';

Map<String, dynamic> _identity([Map<String, dynamic> overrides = const {}]) => {
  'id': _userId,
  'identity_id': '22222222-2222-4222-8222-222222222222',
  'user_id': _userId,
  'provider': 'email',
  'identity_data': {'email': _email, 'sub': _userId},
  ...overrides,
};

Map<String, dynamic> _user([Map<String, dynamic> overrides = const {}]) => {
  'id': _userId,
  'aud': 'authenticated',
  'email': _email,
  'created_at': '2026-10-17T00:00:00Z',
  'email_confirmed_at': null,
  'identities': [_identity()],
  ...overrides,
};

http.Response _response(Object body, [int status = 200]) => http.Response(
  jsonEncode(body),
  status,
  headers: {
    'content-type': 'application/json',
    'x-supabase-api-version': '2024-01-01',
  },
);

class _MemoryPkceStorage extends GotrueAsyncStorage {
  final _values = <String, String>{};

  @override
  Future<String?> getItem({required String key}) async => _values[key];

  @override
  Future<void> setItem({required String key, required String value}) async {
    _values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async => _values.remove(key);
}

void main() {
  // Exercise the real SDK, service, controller and registration navigation.
  // Only HTTP is mocked; a fake service returning success would miss this bug.
  final cases =
      <
        ({
          String name,
          http.Response Function() reply,
          bool opensOtp,
          String? error,
        })
      >[
        (
          name: 'new signup with a real email identity opens OTP',
          reply: () => _response(_user()),
          opensOtp: true,
          error: null,
        ),
        (
          name: 'email comparison ignores case and surrounding whitespace',
          reply: () => _response(
            _user({
              'email': ' PARTNER@example.invalid ',
              'identities': [
                _identity({
                  'identity_data': {'email': 'PARTNER@example.invalid'},
                }),
              ],
            }),
          ),
          opensOtp: true,
          error: null,
        ),
        for (final code in ['user_already_exists', 'email_exists'])
          (
            name: 'existing email ($code) does not open OTP',
            reply: () =>
                _response({'code': code, 'msg': 'Email already exists'}, 422),
            opensOtp: false,
            error: partnerEmailAlreadyUsed,
          ),
        (
          name: 'legacy already registered exception does not open OTP',
          reply: () => _response({'msg': 'User already registered'}, 400),
          opensOtp: false,
          error: partnerEmailAlreadyUsed,
        ),
        for (final identities in [null, <Object>[]])
          (
            name:
                'obfuscated user with identities $identities does not open OTP',
            reply: () => _response(_user({'identities': identities})),
            opensOtp: false,
            error: partnerEmailAlreadyUsed,
          ),
        (
          name: 'Supabase exception does not open OTP',
          reply: () => _response({
            'code': 'signup_disabled',
            'msg': 'Signup disabled',
          }, 422),
          opensOtp: false,
          error: 'Chưa thể tạo tài khoản. Kiểm tra email, mật khẩu hoặc thử lại sau.',
        ),
        (
          name: 'network failure does not open OTP',
          reply: () => throw const SocketException('offline'),
          opensOtp: false,
          error: 'Không thể kết nối để đăng ký. Kiểm tra mạng rồi thử lại.',
        ),
        (
          name: 'null user does not open OTP',
          reply: () => _response({}),
          opensOtp: false,
          error: null,
        ),
        for (final value in [null, 'other@example.invalid'])
          (
            name: 'user email $value does not open OTP',
            reply: () => _response(_user({'email': value})),
            opensOtp: false,
            error: null,
          ),
        (
          name: 'blank user ID does not open OTP',
          reply: () => _response(_user({'id': ''})),
          opensOtp: false,
          error: null,
        ),
        (
          name: 'anonymous user does not open OTP',
          reply: () => _response(_user({'is_anonymous': true})),
          opensOtp: false,
          error: null,
        ),
        for (final entry in <String, Map<String, dynamic>>{
          'non-email provider': {'provider': 'google'},
          'wrong user': {'user_id': 'another-user'},
          'blank identity ID': {'id': ''},
          'missing identity data': {'identity_data': null},
          'wrong identity email': {
            'identity_data': {'email': 'other@example.invalid'},
          },
        }.entries)
          (
            name: '${entry.key} does not open OTP',
            reply: () => _response(
              _user({
                'identities': [_identity(entry.value)],
              }),
            ),
            opensOtp: false,
            error: null,
          ),
        (
          name: 'confirmed user without a session does not open OTP',
          reply: () =>
              _response(_user({'email_confirmed_at': '2026-10-16T00:00:00Z'})),
          opensOtp: false,
          error: partnerEmailAlreadyUsed,
        ),
      ];

  for (final scenario in cases) {
    testWidgets(scenario.name, (tester) async {
      final requests = <http.Request>[];
      final pending = Completer<http.Response>();
      final transport = MockClient((request) async {
        requests.add(request);
        expect(request.url.path, '/auth/v1/signup');
        expect(request.url.queryParameters.containsKey('redirect_to'), isFalse);
        final body = jsonDecode(request.body) as Map;
        expect(body['email'], _email);
        expect(body['data'], {
          'partner_registration': true,
          'full_name': 'Đối tác mới',
          'account_type': 'rescuer_partner',
          'registered_at': '07:00 - 17/10/2026',
        });
        return pending.future;
      });
      // Supabase owns a JSON isolate; initialize and dispose outside fake time.
      final client = (await tester.runAsync(
        () async => SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_example',
          httpClient: transport,
          authOptions: AuthClientOptions(
            pkceAsyncStorage: _MemoryPkceStorage(),
            autoRefreshToken: false,
          ),
        ),
      ))!;
      addTearDown(() async {
        await tester.runAsync(client.dispose);
        transport.close();
      });
      final service = SupabaseRescuerService(
        client,
        now: () => DateTime.utc(2026, 10, 17),
      );
      final controller = RescuerController(service, FakeLocation());
      await tester.pumpWidget(ConnectedRescuerApp(controller: controller));
      await tester.pumpAndSettle();
      await openRegistration(tester);
      await fillRegistration(tester);

      // Leave HTTP pending: neither navigation nor countdown may start early.
      final submit = find.byKey(const ValueKey('register-submit'));
      await tester.ensureVisible(submit);
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      await tester.tap(submit);
      await tester.pump();
      expect(requests, hasLength(1));
      expect(controller.emailConfirmation!.active, isFalse);
      expect(controller.emailConfirmation!.resendSecondsRemaining, 0);
      expect(find.byType(PartnerEmailConfirmationScreen), findsNothing);
      // This also catches accidental duplicate signup requests while busy.
      await tester.tap(submit);
      await tester.pump();
      try {
        pending.complete(scenario.reply());
      } catch (error, stack) {
        pending.completeError(error, stack);
      }
      await tester.pumpAndSettle();

      final confirmation = controller.emailConfirmation!;
      expect(controller.working, isFalse);
      expect(controller.authenticating, isFalse);
      expect(controller.signedIn, isFalse);
      if (scenario.opensOtp) {
        expect(controller.error, isNull);
        expect(find.byType(PartnerEmailConfirmationScreen), findsOneWidget);
        expect(find.byType(PartnerRegistrationScreen), findsNothing);
        expect(confirmation.stage, EmailConfirmationStage.waiting);
        expect(confirmation.resendSecondsRemaining, greaterThan(0));
        for (var digit = 0; digit < 6; digit++) {
          expect(find.byKey(ValueKey('email-otp-$digit')), findsOneWidget);
        }
      } else {
        expect(controller.error, isNotEmpty);
        if (scenario.error != null) {
          expect(controller.error, scenario.error);
        }
        expect(find.text(controller.error!), findsOneWidget);
        expect(find.byType(PartnerRegistrationScreen), findsOneWidget);
        expect(find.byType(PartnerEmailConfirmationScreen), findsNothing);
        expect(confirmation.stage, EmailConfirmationStage.idle);
        expect(confirmation.email, isNull);
        expect(confirmation.resendSecondsRemaining, 0);
        expect(find.byKey(const ValueKey('email-otp-countdown')), findsNothing);
        await tester.pump(const Duration(seconds: 61));
        expect(confirmation.resendSecondsRemaining, 0);
        // Failure stays recoverable; retry still uses signup, never resend.
        await submitRegistration(tester);
        expect(requests, hasLength(2));
      }
      expect(requests.every((r) => r.url.path == '/auth/v1/signup'), isTrue);
      expect(requests, hasLength(scenario.opensOtp ? 1 : 2));
      await tester.pumpWidget(const SizedBox());
    });
  }
}
