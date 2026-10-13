import 'dart:async';
import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/app/app_theme.dart';
import 'package:cuu_ho_247/app/user_session.dart';
import 'package:cuu_ho_247/screens/new_account_screen.dart';
import 'package:cuu_ho_247/screens/customer_vehicles_screen.dart';
import 'package:cuu_ho_247/screens/customer_saved_addresses_screen.dart';
import 'package:cuu_ho_247/services/customer_vehicle_service.dart';
import 'package:cuu_ho_247/services/customer_profile_service.dart';
import 'package:cuu_ho_247/services/supabase_service.dart';
import 'package:cuu_ho_247/widgets/account_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'customer_profile_card_test.dart' as profiles;
import 'customer_vehicles_test.dart' as cars;
import 'customer_saved_addresses_test.dart' as addresses;

class LogoutController extends AppController {
  int calls = 0;
  bool fail = false;
  @override
  Future<void> signOut() async {
    calls++;
    if (fail) throw const AppFailure('Không thể đăng xuất');
    UserSession.clear();
    notifyListeners();
  }
}

class CodedProfileFake extends profiles.ProfileFake {
  @override
  Future<CustomerProfile> load() async => const CustomerProfile(
      userId: 'owner',
      customerCode: 'KH-000042',
      fullName: 'Nguyễn An',
      phone: '0901234567',
      email: 'an@example.com');
}

void main() {
  testWidgets(
      'hero code chip, two compact statistics and profile actions fit 320px',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var edits = 0, reloads = 0;
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!),
      home: Scaffold(
          body: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: CustomerAccountHeaderCard(
                  name: 'Nguyễn An',
                  customerCode: 'KH-000042',
                  phone: '0901234567',
                  email: 'an@example.com',
                  vehicleCount: 2,
                  completedCount: 3,
                  onEdit: () => edits++,
                  onReload: () => reloads++))),
    ));
    await tester.pumpAndSettle();
    final chip = find.byKey(const ValueKey('account-customer-code-chip'));
    expect(find.descendant(of: chip, matching: find.text('Mã KH: KH-000042')),
        findsOneWidget);
    expect(find.byType(AccountMetricTile), findsNWidgets(2));
    final metrics = find.byType(AccountMetricTile);
    expect(tester.getSize(metrics.at(0)).width,
        tester.getSize(metrics.at(1)).width);
    await tester.ensureVisible(find.byTooltip('Chỉnh sửa thông tin'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Chỉnh sửa thông tin'));
    await tester.tap(find.byTooltip('Tải lại hồ sơ'));
    expect(edits, 1);
    expect(reloads, 1);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'styled empty vehicle and address cards fit 320px with large text',
      (tester) async {
    UserSession.userId = 'owner';
    final controller = AppController();
    addTearDown(controller.dispose);
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!),
      home: Scaffold(
          body: NewAccountScreen(
              controller: controller,
              profileRepository: CodedProfileFake(),
              vehicleRepository: cars.VehiclesFake(),
              addressRepository: addresses.AddressesFake())),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Mã KH: KH-000042'), findsOneWidget);
    expect(find.byTooltip('Chỉnh sửa thông tin'), findsOneWidget);
    for (final text in [
      'Chưa có xe đã lưu',
      'Thêm phương tiện để đặt cứu hộ nhanh hơn',
      'Chưa có địa chỉ đã lưu',
      'Lưu địa chỉ thường dùng để đặt cứu hộ nhanh hơn',
      'Đăng xuất tài khoản',
      'Hệ thống cứu hộ 24/7'
    ]) {
      await tester.scrollUntilVisible(find.text(text), 120,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.text(text).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    expect(find.byType(AccountVehicleCard), findsNothing);
    expect(find.textContaining('1900'), findsNothing);
    expect(find.textContaining('Điểm thưởng'), findsNothing);
    expect(
        find.textContaining(RegExp(
            r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
            caseSensitive: false)),
        findsNothing);
  });
  testWidgets('hero shows real KH code and hides unsupported statistics',
      (tester) async {
    UserSession.userId = 'owner';
    final controller = AppController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: NewAccountScreen(
      controller: controller,
      profileRepository: CodedProfileFake(),
      vehicleRepository: cars.VehiclesFake()..vehicles = [cars.truck],
      addressRepository: addresses.AddressesFake()
        ..addresses = [addresses.saved],
    ))));
    await tester.pumpAndSettle();
    expect(find.text('Mã KH: KH-000042'), findsOneWidget);
    expect(find.text('Nguyễn An'), findsOneWidget);
    expect(find.text('0901234567'), findsOneWidget);
    expect(find.text('Xe đã lưu'), findsOneWidget);
    expect(
        tester
            .widget<CustomerAccountHeaderCard>(
                find.byType(CustomerAccountHeaderCard))
            .completedCount,
        isNull);
    expect(
        find.textContaining(RegExp(
            r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
            caseSensitive: false)),
        findsNothing);
    expect(find.textContaining('Điểm thưởng'), findsNothing);
    expect(find.textContaining('1900'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  setUp(() => UserSession.userId = 'owner');
  tearDown(UserSession.clear);
  Future<void> mount(WidgetTester tester, AppController controller,
      cars.VehiclesFake vehicles, addresses.AddressesFake saved) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        routes: {'/login': (_) => const Scaffold(body: Text('Login route'))},
        home: Scaffold(
            body: NewAccountScreen(
                controller: controller,
                profileRepository: profiles.ProfileFake(),
                vehicleRepository: vehicles,
                addressRepository: saved))));
    await tester.pumpAndSettle();
  }

  Future<void> tap(WidgetTester tester, Finder target) async {
    for (var i = 0; i < 20 && target.evaluate().isEmpty; i++) {
      await tester.drag(find.byType(ListView).first, const Offset(0, -250));
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(target);
    await tester.pumpAndSettle();
    await tester.tap(target);
    await tester.pumpAndSettle();
  }

  testWidgets(
      'real vehicles and addresses render and management refreshes preview',
      (tester) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    final vehicles = cars.VehiclesFake()..vehicles = [cars.truck];
    final saved = addresses.AddressesFake()..addresses = [addresses.saved];
    await mount(tester, controller, vehicles, saved);
    final header = tester.widget<CustomerAccountHeaderCard>(
        find.byType(CustomerAccountHeaderCard));
    expect(header.vehicleCount, 1);
    expect(header.name, profiles.original.fullName);
    expect(find.text(cars.truck.brandModel), findsOneWidget);
    expect(find.text(cars.truck.licensePlate), findsOneWidget);
    await tap(tester, find.text('Thêm phương tiện mới'));
    expect(find.byType(CustomerVehiclesScreen), findsOneWidget);
    vehicles.vehicles = [];
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.byType(AccountVehicleCard), findsNothing);
    await tester.scrollUntilVisible(
        find.byType(CustomerAccountHeaderCard), -180,
        scrollable: find.byType(Scrollable).first);
    expect(
        tester
            .widget<CustomerAccountHeaderCard>(
                find.byType(CustomerAccountHeaderCard))
            .vehicleCount,
        0);
    await tap(tester, find.text('Quản lý địa chỉ'));
    expect(find.byType(CustomerSavedAddressesScreen), findsOneWidget);
    saved.addresses = [];
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có địa chỉ đã lưu'), findsOneWidget);
  });
  testWidgets('late vehicle response cannot reappear after logout',
      (tester) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    final vehicles = cars.VehiclesFake()
      ..pending = Completer<List<CustomerVehicle>>();
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
            body: NewAccountScreen(
                controller: controller,
                profileRepository: profiles.ProfileFake(),
                vehicleRepository: vehicles,
                addressRepository: addresses.AddressesFake()))));
    await tester.pump();
    UserSession.clear();
    controller.selectTab(4);
    await tester.pump();
    vehicles.pending!.complete([cars.truck]);
    await tester.pumpAndSettle();
    expect(find.byType(AccountVehicleCard), findsNothing);
    expect(find.byType(CustomerAccountHeaderCard), findsNothing);
    expect(find.textContaining(cars.truck.licensePlate), findsNothing);
  });
  testWidgets(
      'logout cancel, error and success call existing controller and login route',
      (tester) async {
    final controller = LogoutController();
    addTearDown(controller.dispose);
    await mount(
        tester, controller, cars.VehiclesFake(), addresses.AddressesFake());
    await tap(tester, find.text('Đăng xuất tài khoản'));
    await tester.tap(find.text('Ở lại'));
    await tester.pumpAndSettle();
    expect(controller.calls, 0);
    controller.fail = true;
    await tap(tester, find.text('Đăng xuất tài khoản'));
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(controller.calls, 1);
    expect(UserSession.userId, 'owner');
    expect(find.text('Không thể đăng xuất'), findsOneWidget);
    controller.fail = false;
    await tap(tester, find.text('Đăng xuất tài khoản'));
    await tester.tap(find.text('Đăng xuất'));
    await tester.pumpAndSettle();
    expect(controller.calls, 2);
    expect(find.text('Login route'), findsOneWidget);
  });
  testWidgets(
      'failed vehicle load hides count and unsupported payment and policy claims',
      (tester) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await mount(tester, controller, cars.VehiclesFake()..failList = true,
        addresses.AddressesFake());
    expect(
        tester
            .widget<CustomerAccountHeaderCard>(
                find.byType(CustomerAccountHeaderCard))
            .vehicleCount,
        isNull);
    for (final text in [
      'Visa',
      'MoMo',
      'VAT',
      'Điểm thưởng',
      'Miễn phí',
      'v2.5.0',
      'Sẵn sàng cứu hộ'
    ]) {
      expect(find.textContaining(text), findsNothing);
    }
  });
}
