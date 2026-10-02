import 'dart:async';

import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/app/user_session.dart';
import 'package:cuu_ho_247/services/customer_profile_service.dart';
import 'package:cuu_ho_247/widgets/customer_profile_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const original = CustomerProfile(
    userId: 'owner',
    fullName: 'Nguyễn An',
    phone: '0901234567',
    email: 'an@example.com');

class ProfileFake implements CustomerProfileRepository {
  bool failLoad = false;
  bool failSave = false;
  int saves = 0;
  Completer<CustomerProfile>? pending;
  Completer<CustomerProfile>? pendingSave;
  @override
  Future<CustomerProfile> load() async {
    if (failLoad) throw Exception('offline');
    if (pending != null) return pending!.future;
    return original;
  }

  @override
  Future<CustomerProfile> save(
      {required String fullName, required String phone}) async {
    saves++;
    if (failSave) throw Exception('offline');
    if (pendingSave != null) return pendingSave!.future;
    return CustomerProfile(
        userId: 'owner',
        fullName: fullName.trim(),
        phone: phone,
        email: original.email);
  }
}

void main() {
  late AppController controller;
  setUp(() {
    UserSession.userId = 'owner';
    controller = AppController();
  });
  tearDown(() {
    controller.dispose();
    UserSession.clear();
  });

  Future<void> mount(WidgetTester tester, ProfileFake repo) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: CustomerProfileCard(
                    controller: controller, repository: repo)))));
    await tester.pump();
  }

  testWidgets(
      'loading, read only email, edit validation, save success and session sync',
      (tester) async {
    final repo = ProfileFake()..pending = Completer<CustomerProfile>();
    await mount(tester, repo);
    expect(find.text('Đang tải hồ sơ…'), findsOneWidget);
    repo.pending!.complete(original);
    await tester.pumpAndSettle();
    expect(find.text('an@example.com'), findsOneWidget);
    await tester.tap(find.text('Chỉnh sửa thông tin'));
    await tester.pumpAndSettle();
    expect(find.byType(TextFormField), findsNWidgets(2));
    await tester.enterText(find.byType(TextFormField).first, '');
    await tester.ensureVisible(find.text('Lưu thay đổi'));
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();
    expect(repo.saves, 0);
    expect(find.text('Vui lòng nhập họ tên.'), findsOneWidget);
    await tester.enterText(find.byType(TextFormField).first, 'Nguyễn Bình');
    await tester.ensureVisible(find.text('Lưu thay đổi'));
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();
    expect(find.text('Đã lưu thông tin cá nhân.'), findsOneWidget);
    expect(UserSession.fullName, 'Nguyễn Bình');
  });

  testWidgets(
      'load retry and failed save preserve draft; cancel restores saved profile',
      (tester) async {
    final repo = ProfileFake()..failLoad = true;
    await mount(tester, repo);
    await tester.pumpAndSettle();
    repo.failLoad = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chỉnh sửa thông tin'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Bản nháp');
    repo.failSave = true;
    await tester.ensureVisible(find.text('Lưu thay đổi'));
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pumpAndSettle();
    expect(find.text('Bản nháp'), findsOneWidget);
    expect(find.text('Không lưu được hồ sơ. Thông tin đã nhập vẫn được giữ.'),
        findsOneWidget);
    await tester.ensureVisible(find.text('Hủy chỉnh sửa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Hủy chỉnh sửa'));
    await tester.pumpAndSettle();
    expect(find.text('Nguyễn An'), findsOneWidget);
  });

  testWidgets('session change hides profile and discards late load',
      (tester) async {
    final repo = ProfileFake()..pending = Completer<CustomerProfile>();
    await mount(tester, repo);
    UserSession.clear();
    controller.selectTab(4);
    await tester.pump();
    repo.pending!.complete(original);
    await tester.pumpAndSettle();
    expect(find.text('Nguyễn An'), findsNothing);
    expect(find.text('Đăng nhập / Đăng ký'), findsOneWidget);
    expect(UserSession.fullName, isNull);
  });

  testWidgets(
      'pending save disables duplicate submits and ignores result after logout',
      (tester) async {
    final repo = ProfileFake()..pendingSave = Completer<CustomerProfile>();
    await mount(tester, repo);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Chỉnh sửa thông tin'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Lưu thay đổi'));
    await tester.tap(find.text('Lưu thay đổi'));
    await tester.pump();
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(repo.saves, 1);
    UserSession.clear();
    controller.selectTab(4);
    repo.pendingSave!.complete(original);
    await tester.pumpAndSettle();
    expect(find.text('Đã lưu thông tin cá nhân.'), findsNothing);
    expect(UserSession.fullName, isNull);
  });
}
