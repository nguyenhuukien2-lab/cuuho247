import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:rescuer/app/rescuer_controller.dart';
import 'package:rescuer/models/backend_models.dart';
import 'package:rescuer/screens/preparation/partner_registration_screen.dart';
import 'package:rescuer/services/rescuer_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'connected_app_test.dart'
    show FakeService, FakeLocation, approved, mount;
import 'claim_request_test.dart' show request;

class _MemoryPkceStorage extends GotrueAsyncStorage {
  final values = <String, String>{};
  @override
  Future<String?> getItem({required String key}) async => values[key];
  @override
  Future<void> setItem({required String key, required String value}) async {
    values[key] = value;
  }

  @override
  Future<void> removeItem({required String key}) async {
    values.remove(key);
  }
}

class PartnerAuthFake extends FakeService {
  bool confirmationRequired = false;
  Object? authFailure;
  Completer<void>? authGate;
  int signUps = 0;
  Json? metadata;
  @override
  Json? get registrationProfile => metadata;

  @override
  Future<PartnerSignUpResult> signUp({
    required String email,
    required String password,
    required String name,
    required String phone,
  }) async {
    signUps++;
    if (authGate != null) await authGate!.future;
    if (authFailure != null) throw authFailure!;
    metadata = {'full_name': name.trim(), 'contact_phone': phone.trim()};
    if (!confirmationRequired) {
      userId = 'rescuer';
      changes.add(userId);
    }
    return PartnerSignUpResult(
      'rescuer',
      needsEmailConfirmation: confirmationRequired,
    );
  }

  @override
  Future<Json> mutate(String name, Json params) async {
    final result = await super.mutate(name, params);
    if (name == 'rescuer_register_profile') {
      final profile = {
        'full_name': params['p_full_name'],
        'contact_phone': params['p_contact_phone'],
        'verification_status': 'draft',
        'version': 1,
      };
      snapshot = RescuerSnapshot(profile: profile);
      return profile;
    }
    return result;
  }
}

Future<void> openRegistration(WidgetTester tester) async {
  final link = find.byKey(const ValueKey('open-partner-registration'));
  await tester.ensureVisible(link);
  await tester.pumpAndSettle();
  await tester.tap(link);
  await tester.pumpAndSettle();
}

Future<void> fillRegistration(WidgetTester tester) async {
  for (final entry in const {
    'name': ' Đối tác mới ',
    'phone': '0901234567',
    'email': 'partner@example.invalid',
    'password': 'TestPassword9',
    'confirmation': 'TestPassword9',
  }.entries) {
    final field = find.byKey(ValueKey('register-${entry.key}'));
    if (field.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        field,
        150,
        scrollable: find
            .descendant(
              of: find.byType(PartnerRegistrationScreen),
              matching: find.byType(Scrollable),
            )
            .first,
      );
    }
    await tester.ensureVisible(field);
    await tester.enterText(field, entry.value);
  }
  final terms = find.byKey(const ValueKey('register-terms'));
  await tester.ensureVisible(terms);
  await tester.pumpAndSettle();
  await tester.tap(terms);
  await tester.pumpAndSettle();
}

Future<void> submitRegistration(WidgetTester tester) async {
  final button = find.byKey(const ValueKey('register-submit'));
  await tester.ensureVisible(button);
  await tester.pumpAndSettle();
  // Remove the test keyboard so this is a real visible tap.
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
  await tester.tap(button);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'login links to partner registration and explains separate accounts',
    (tester) async {
      final s = PartnerAuthFake();
      final c = RescuerController(s, FakeLocation());
      addTearDown(() => s.changes.close());
      await mount(tester, c);
      expect(find.text('Đăng nhập đối tác'), findsOneWidget);
      expect(find.text('Đăng ký đối tác'), findsOneWidget);
      expect(find.text(partnerSeparateAccountMessage), findsOneWidget);
      await openRegistration(tester);
      expect(find.byType(PartnerRegistrationScreen), findsOneWidget);
      expect(find.text(partnerApprovalMessage), findsOneWidget);
      expect(s.signUps, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'registration validates contact, email, password, confirmation and terms before auth',
    (tester) async {
      final s = PartnerAuthFake();
      final c = RescuerController(s, FakeLocation());
      addTearDown(() => s.changes.close());
      await mount(tester, c);
      await openRegistration(tester);
      await submitRegistration(tester);
      expect(find.text('Nhập họ tên từ 1–150 ký tự'), findsOneWidget);
      expect(
        find.text('Nhập 8–15 chữ số, có thể bắt đầu bằng +'),
        findsOneWidget,
      );
      expect(find.text('Nhập email hợp lệ'), findsOneWidget);
      expect(find.text('Mật khẩu cần ít nhất 8 ký tự'), findsOneWidget);
      expect(find.text('Mật khẩu xác nhận không khớp'), findsOneWidget);
      expect(find.text('Bạn cần đồng ý điều khoản cơ bản'), findsOneWidget);
      for (final entry in const {
        'name': 'Đối tác',
        'phone': '090abc',
        'email': 'wrong@',
        'password': 'short',
        'confirmation': 'other',
      }.entries) {
        await tester.enterText(
          find.byKey(ValueKey('register-${entry.key}')),
          entry.value,
        );
      }
      await submitRegistration(tester);
      expect(find.text('Nhập email hợp lệ'), findsOneWidget);
      expect(find.text('Mật khẩu cần ít nhất 8 ký tự'), findsOneWidget);
      expect(
        find.text('Nhập 8–15 chữ số, có thể bắt đầu bằng +'),
        findsOneWidget,
      );
      expect(s.signUps, 0);
      expect(s.calls, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'account with a session creates only a draft profile through the existing RPC',
    (tester) async {
      final s = PartnerAuthFake();
      final c = RescuerController(s, FakeLocation());
      addTearDown(() => s.changes.close());
      await mount(tester, c);
      await openRegistration(tester);
      await fillRegistration(tester);
      await submitRegistration(tester);
      expect(find.byType(PartnerRegistrationScreen), findsNothing);
      expect(c.signedIn, isTrue);
      expect(c.snapshot.profile!['verification_status'], 'draft');
      expect(c.snapshot.vehicles, isEmpty);
      expect(c.snapshot.capabilities, isEmpty);
      expect(c.snapshot.approved, isFalse);
      expect(c.canOnline, isFalse);
      expect(c.canClaim, isFalse);
      expect(find.text('Hồ sơ nháp'), findsOneWidget);
      expect(find.textContaining('quản trị viên duyệt'), findsWidgets);
      expect(s.signUps, 1);
      expect(s.calls, hasLength(1));
      expect(s.calls.single.$1, 'rescuer_register_profile');
      expect(s.calls.single.$2, {
        'p_full_name': 'Đối tác mới',
        'p_contact_phone': '0901234567',
      });
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('email confirmation defers profile RPC until partner signs in', (
    tester,
  ) async {
    final s = PartnerAuthFake()..confirmationRequired = true;
    final c = RescuerController(s, FakeLocation());
    addTearDown(() => s.changes.close());
    await mount(tester, c);
    await openRegistration(tester);
    await fillRegistration(tester);
    await submitRegistration(tester);
    expect(find.text('Xác nhận email để tiếp tục'), findsOneWidget);
    expect(find.text(partnerApprovalMessage), findsOneWidget);
    expect(c.signedIn, isFalse);
    expect(c.canOnline, isFalse);
    expect(s.calls, isEmpty);
    await tester.ensureVisible(find.text('Quay lại đăng nhập'));
    await tester.tap(find.text('Quay lại đăng nhập'));
    await tester.pumpAndSettle();
    await c.signIn('partner@example.invalid', 'TestPassword9');
    await tester.pumpAndSettle();
    expect(c.snapshot.profile!['verification_status'], 'draft');
    expect(s.calls.single.$1, 'rescuer_register_profile');
    expect(c.canClaim, isFalse);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'registration auth error stays recoverable and never creates a profile',
    (tester) async {
      final s = PartnerAuthFake()
        ..authFailure = const AuthException('Signup unavailable');
      final c = RescuerController(s, FakeLocation());
      addTearDown(() => s.changes.close());
      await mount(tester, c);
      await openRegistration(tester);
      await fillRegistration(tester);
      await submitRegistration(tester);
      expect(find.text('Chưa thể đăng ký'), findsOneWidget);
      expect(c.signedIn, isFalse);
      expect(c.authenticating, isFalse);
      expect(s.calls, isEmpty);
      final button = find.descendant(
        of: find.byKey(const ValueKey('register-submit')),
        matching: find.byType(FilledButton),
      );
      expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'RPC denial after account creation offers profile completion without another signup',
    (tester) async {
      final s = PartnerAuthFake()
        ..failedMutation = 'rescuer_register_profile'
        ..mutationFailure = const PostgrestException(
          message: 'permission denied',
          code: '42501',
        );
      final c = RescuerController(s, FakeLocation());
      addTearDown(() => s.changes.close());
      await mount(tester, c);
      await openRegistration(tester);
      await fillRegistration(tester);
      await submitRegistration(tester);
      expect(c.signedIn, isTrue);
      expect(c.snapshot.profile, isNull);
      expect(c.canOnline, isFalse);
      expect(find.textContaining('RLS/quyền RPC'), findsWidgets);
      expect(find.byKey(const ValueKey('register-submit')), findsNothing);
      await tester.ensureVisible(find.text('Hoàn thiện hồ sơ đối tác').last);
      await tester.tap(find.text('Hoàn thiện hồ sơ đối tác').last);
      await tester.pumpAndSettle();
      expect(find.text('Hoàn thiện hồ sơ đối tác'), findsOneWidget);
      expect(find.text('Tạo hồ sơ'), findsOneWidget);
      expect(s.signUps, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'a normal existing account without profile opens completion and is never approved',
    (tester) async {
      final s = PartnerAuthFake();
      final c = RescuerController(s, FakeLocation());
      addTearDown(() => s.changes.close());
      await mount(tester, c);
      await c.signIn('customer@example.invalid', 'existing-password');
      await tester.pumpAndSettle();
      expect(find.text('Hoàn thiện hồ sơ đối tác'), findsOneWidget);
      expect(find.widgetWithText(TextFormField, 'Họ và tên'), findsOneWidget);
      expect(
        find.widgetWithText(TextFormField, 'Số điện thoại liên hệ'),
        findsOneWidget,
      );
      expect(c.snapshot.approved, isFalse);
      expect(c.canOnline, isFalse);
      expect(s.calls, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'missing profile and malformed metadata do not crash or grant permissions',
    (tester) async {
      final s = PartnerAuthFake()
        ..metadata = {
          'full_name': 42,
          'contact_phone': false,
          'verification_status': 'approved',
        };
      final c = RescuerController(s, FakeLocation());
      addTearDown(() => s.changes.close());
      await mount(tester, c);
      await c.signIn('partner@example.invalid', 'password');
      await tester.pumpAndSettle();
      expect(c.snapshot.profile, isNull);
      expect(c.canClaim, isFalse);
      expect(s.calls, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  for (final status in ['pending', 'submitted', 'rejected', 'suspended']) {
    testWidgets(
      '$status cannot enable online or claim, even with eligible vehicle/service',
      (tester) async {
        final ready = approved();
        final s = PartnerAuthFake()
          ..userId = 'rescuer'
          ..snapshot = RescuerSnapshot(
            profile: {...ready.profile!, 'verification_status': status},
            vehicles: ready.vehicles,
            capabilities: ready.capabilities,
          );
        final c = RescuerController(s, FakeLocation());
        addTearDown(() => s.changes.close());
        await mount(tester, c);
        if (['pending', 'submitted'].contains(status)) {
          expect(find.text('Chờ duyệt hồ sơ'), findsOneWidget);
          expect(find.text('Đang chờ duyệt'), findsOneWidget);
        } else {
          expect(
            find.textContaining(
              status == 'rejected' ? 'gửi duyệt lại' : 'tạm ngưng',
            ),
            findsWidgets,
          );
        }
        expect(find.text(partnerApprovalMessage), findsOneWidget);
        final toggle = find.descendant(
          of: find.byKey(const ValueKey('toggle-online')),
          matching: find.byType(FilledButton),
        );
        await tester.scrollUntilVisible(toggle, 200);
        expect(tester.widget<FilledButton>(toggle).onPressed, isNull);
        expect(find.byType(SwitchListTile), findsNothing);
        await c.setOnline(true);
        c.requests = [request];
        await c.claimRequest(request);
        expect(c.canOnline, isFalse);
        expect(c.canClaim, isFalse);
        expect(s.calls, isEmpty);
        c.selectTab(1);
        await tester.pumpAndSettle();
        expect(find.text('Nhận đơn'), findsNothing);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      },
    );
  }

  testWidgets('approved login keeps dashboard and existing online flow', (
    tester,
  ) async {
    final s = PartnerAuthFake()..snapshot = approved();
    final c = RescuerController(s, FakeLocation());
    addTearDown(() => s.changes.close());
    await mount(tester, c);
    await c.signIn('approved@example.invalid', 'existing-password');
    await tester.pumpAndSettle();
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Trạng thái làm việc'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.descendant(
              of: find.byKey(const ValueKey('toggle-online')),
              matching: find.byType(FilledButton),
            ),
          )
          .onPressed,
      isNotNull,
    );
    final nav = find.byType(NavigationBar);
    await tester.tap(
      find.descendant(of: nav, matching: find.text('Tài khoản')),
    );
    await tester.pumpAndSettle();
    expect(find.text('Đã được duyệt'), findsOneWidget);
    await tester.tap(
      find.descendant(of: nav, matching: find.text('Trang chủ')),
    );
    await tester.pumpAndSettle();
    expect(c.canOnline, isTrue);
    expect(s.calls, isEmpty);
    await c.setOnline(true);
    await tester.pumpAndSettle();
    expect(c.online, isTrue);
    expect(c.canClaim, isTrue);
    expect(
      s.calls.map((r) => r.$1),
      containsAllInOrder([
        'rescuer_set_online',
        'rescuer_update_location',
        'rescuer_list_available_requests',
      ]),
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('duplicate submit is disabled while auth is running', (
    tester,
  ) async {
    final s = PartnerAuthFake()
      ..confirmationRequired = true
      ..authGate = Completer<void>();
    final c = RescuerController(s, FakeLocation());
    addTearDown(() => s.changes.close());
    await mount(tester, c);
    await openRegistration(tester);
    await fillRegistration(tester);
    final submit = find.byKey(const ValueKey('register-submit'));
    await tester.ensureVisible(submit);
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.tap(submit);
    await tester.pump();
    expect(s.signUps, 1);
    final button = find.descendant(
      of: submit,
      matching: find.byType(FilledButton),
    );
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    final duplicate = await c.signUp(
      email: 'other@example.invalid',
      password: 'Password9',
      name: 'Other',
      phone: '0901234567',
    );
    expect(duplicate, isNull);
    expect(s.signUps, 1);
    s.authGate!.complete();
    await tester.pumpAndSettle();
    expect(find.text('Xác nhận email để tiếp tục'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  test('Supabase signup uses client auth and contact metadata only, no profile insert or approval', () async {
    final calls = <http.Request>[];
    final transport = MockClient((r) async {
      calls.add(r);
      expect(r.url.path, '/auth/v1/signup');
      final body = jsonDecode(r.body) as Map;
      expect(body['email'], 'partner@example.invalid');
      expect(body['password'], 'Password9');
      expect(body['data'], {
        'partner_registration': true,
        'full_name': 'Partner',
        'contact_phone': '0901234567',
      });
      expect(body.containsKey('role'), isFalse);
      return http.Response(
        jsonEncode({
          'id': '11111111-1111-4111-8111-111111111111',
          'aud': 'authenticated',
          'role': 'authenticated',
          'email': 'partner@example.invalid',
          'app_metadata': {},
          'user_metadata': body['data'],
          'created_at': '2026-10-05T00:00:00Z',
        }),
        200,
        headers: {'content-type': 'application/json'},
        request: r,
      );
    });
    final client = SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_example',
      httpClient: transport,
      authOptions: AuthClientOptions(pkceAsyncStorage: _MemoryPkceStorage()),
    );
    addTearDown(() async {
      await client.dispose();
      transport.close();
    });
    final s = SupabaseRescuerService(client);
    final result = await s.signUp(
      email: ' partner@example.invalid ',
      password: 'Password9',
      name: ' Partner ',
      phone: '0901234567',
    );
    expect(result.needsEmailConfirmation, isTrue);
    expect(s.userId, isNull);
    expect(s.registrationProfile, isNull);
    expect(calls, hasLength(1));
  });

  test('signup with an authenticated session restores contact details but ignores forged approval metadata', () async {
    final transport = MockClient((r) async {
      expect(r.url.path, '/auth/v1/signup');
      final body = jsonDecode(r.body) as Map;
      expect(body['code_challenge'], isNotEmpty);
      expect(body['code_challenge_method'], 's256');
      return http.Response(
        jsonEncode({
          'access_token': 'fixture-access-token',
          'token_type': 'bearer',
          'refresh_token': 'fixture-refresh',
          'expires_in': 3600,
          'user': {
            'id': '11111111-1111-4111-8111-111111111111',
            'aud': 'authenticated',
            'role': 'authenticated',
            'email': 'partner@example.invalid',
            'app_metadata': {},
            'user_metadata': {
              ...(body['data'] as Map),
              'verification_status': 'approved',
              'role': 'admin',
            },
            'created_at': '2026-10-05T00:00:00Z',
          },
        }),
        200,
        headers: {'content-type': 'application/json'},
        request: r,
      );
    });
    final client = SupabaseClient(
      'https://example.supabase.co',
      'sb_publishable_example',
      httpClient: transport,
      authOptions: AuthClientOptions(
        pkceAsyncStorage: _MemoryPkceStorage(),
        autoRefreshToken: false,
      ),
    );
    addTearDown(() async {
      await client.dispose();
      transport.close();
    });
    final s = SupabaseRescuerService(client);
    final result = await s.signUp(
      email: 'partner@example.invalid',
      password: 'Password9',
      name: 'Partner',
      phone: '0901234567',
    );
    expect(result.needsEmailConfirmation, isFalse);
    expect(s.userId, result.userId);
    expect(s.registrationProfile, {
      'full_name': 'Partner',
      'contact_phone': '0901234567',
    });
  });

  testWidgets(
    'registration fields and actions fit a 320px phone with larger text',
    (tester) async {
      final s = PartnerAuthFake();
      final c = RescuerController(s, FakeLocation())..loading = false;
      addTearDown(c.dispose);
      addTearDown(() => s.changes.close());
      tester.view.physicalSize = const Size(320, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 740),
              textScaler: TextScaler.linear(1.5),
            ),
            child: PartnerRegistrationScreen(c: c),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await fillRegistration(tester);
      await tester.ensureVisible(find.byKey(const ValueKey('register-submit')));
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      expect(find.text('Tạo tài khoản đối tác'), findsOneWidget);
      expect(tester.takeException(), isNull);
      expect(s.signUps, 0);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
