import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/app/user_session.dart';
import 'package:cuu_ho_247/screens/customer_saved_addresses_screen.dart';
import 'package:cuu_ho_247/screens/new_request_screen.dart';
import 'package:cuu_ho_247/services/customer_saved_address_service.dart';
import 'package:cuu_ho_247/widgets/saved_address_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'request_location_test.dart' as location;

const saved = CustomerSavedAddress(
    id: 'home',
    customerId: 'owner',
    label: 'Nhà',
    address: '123 Nguyễn Huệ',
    latitude: 10.7,
    longitude: 106.7,
    isDefault: true);

class AddressesFake implements CustomerSavedAddressRepository {
  List<CustomerSavedAddress> addresses = [];
  int deletes = 0;
  @override
  Future<List<CustomerSavedAddress>> list() async => List.of(addresses);
  @override
  Future<void> delete(String id) async {
    deletes++;
    addresses.removeWhere((item) => item.id == id);
  }

  @override
  Future<CustomerSavedAddress> save(
      {String? id,
      required String label,
      required String address,
      double? latitude,
      double? longitude,
      String? notes,
      bool isDefault = false}) async {
    final result = CustomerSavedAddress(
        id: id ?? 'home',
        customerId: 'owner',
        label: label,
        address: address,
        latitude: latitude,
        longitude: longitude,
        notes: notes,
        isDefault: isDefault);
    addresses = [result, ...addresses.where((item) => item.id != result.id)];
    return result;
  }
}

void main() {
  setUp(() => UserSession.userId = 'owner');
  tearDown(UserSession.clear);
  testWidgets('empty state, add, edit, delete requires confirmation',
      (tester) async {
    tester.view.physicalSize = const Size(420, 1800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repo = AddressesFake();
    final controller = AppController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        home: CustomerSavedAddressesScreen(
            controller: controller, repository: repo)));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có địa chỉ đã lưu'), findsOneWidget);
    await tester.tap(find.text('Thêm địa chỉ').first);
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Địa chỉ'), saved.address);
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Lưu địa chỉ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu địa chỉ'));
    await tester.pumpAndSettle();
    expect(find.text(saved.address), findsOneWidget);
    await tester.tap(find.text('Sửa địa chỉ'));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.widgetWithText(TextFormField, 'Địa chỉ'), '456 Lê Lợi');
    tester.testTextInput.hide();
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Lưu địa chỉ'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lưu địa chỉ'));
    await tester.pumpAndSettle();
    expect(find.text('456 Lê Lợi'), findsOneWidget);
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    expect(repo.deletes, 0);
    await tester.tap(find.text('Giữ lại'));
    await tester.pumpAndSettle();
    expect(repo.deletes, 0);
    await tester.tap(find.text('Xóa'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Xóa địa chỉ'));
    await tester.pumpAndSettle();
    expect(repo.deletes, 1);
    expect(find.text('Chưa có địa chỉ đã lưu'), findsOneWidget);
  });
  for (final hasCoordinates in [true, false]) {
    testWidgets(
        'selected address submits ${hasCoordinates ? 'saved coordinates' : 'null coordinates'} and ignores late GPS',
        (tester) async {
      final controller = location.CapturingController();
      final gps = location.FakeLocationService();
      await location.mountForm(tester, controller, gps);
      final repo = AddressesFake()
        ..addresses = [
          hasCoordinates
              ? saved
              : const CustomerSavedAddress(
                  id: 'home',
                  customerId: 'owner',
                  label: 'Nhà',
                  address: '123 Nguyễn Huệ')
        ];
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: NewRequestScreen(
                  controller: controller,
                  locationService: gps,
                  addressRepository: repo))));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).at(2), 'An');
      await tester.enterText(find.byType(TextFormField).at(3), '0900000000');
      tester.testTextInput.hide();
      await tester.tap(find.text('Lấy vị trí hiện tại'));
      await tester.pump();
      await tester.tap(find.descendant(
          of: find.byType(SavedAddressPicker),
          matching: find.byType(DropdownButton<String>)));
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find
          .textContaining(hasCoordinates ? 'Nhà (Mặc định)' : 'Nhà —')
          .last);
      await tester.pump(const Duration(milliseconds: 400));
      gps.pending.complete(location.located);
      await tester.pumpAndSettle();
      expect(
          tester
              .widget<TextFormField>(find.byType(TextFormField).first)
              .controller!
              .text,
          saved.address);
      await tester.ensureVisible(find.text('Gửi yêu cầu cứu hộ'));
      await location.sendRequest(tester);
      expect(controller.submissions.single.address, saved.address);
      expect(
          controller.submissions.single.latitude, hasCoordinates ? 10.7 : null);
      expect(controller.submissions.single.longitude,
          hasCoordinates ? 106.7 : null);
      await tester.ensureVisible(find.byType(SavedAddressPicker));
      await tester.tap(find.descendant(
          of: find.byType(SavedAddressPicker),
          matching: find.byType(DropdownButton<String>)));
      await tester.pumpAndSettle();
      await tester.tap(find
          .textContaining(hasCoordinates ? 'Nhà (Mặc định)' : 'Nhà —')
          .last);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, '456 Lê Lợi');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      expect(
          tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
          isFalse);
      await tester.ensureVisible(find.text('Gửi yêu cầu cứu hộ'));
      await location.sendRequest(tester);
      expect(controller.submissions.last.address, '456 Lê Lợi');
      expect(controller.submissions.last.latitude, isNull);
      expect(controller.submissions.last.longitude, isNull);
    });
  }
}
