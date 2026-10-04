import 'request_steps.dart';
import 'dart:async';

import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/app/user_session.dart';
import 'package:cuu_ho_247/screens/customer_vehicles_screen.dart';
import 'package:cuu_ho_247/screens/new_request_screen.dart';
import 'package:cuu_ho_247/services/customer_vehicle_service.dart';
import 'package:cuu_ho_247/widgets/saved_vehicle_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const truck = CustomerVehicle(
    id: 'truck',
    customerId: 'owner',
    kind: VehicleKind.truck,
    brandModel: 'Isuzu QKR',
    licensePlate: '51C-12345',
    color: 'Trắng',
    notes: 'Xe chở hàng');

class VehiclesFake implements CustomerVehicleRepository {
  List<CustomerVehicle> vehicles = [];
  bool failList = false;
  bool failSave = false;
  bool failDelete = false;
  int deletes = 0;
  Completer<List<CustomerVehicle>>? pending;
  @override
  Future<List<CustomerVehicle>> list() async {
    if (failList) throw Exception('offline');
    if (pending != null) return pending!.future;
    return List.of(vehicles);
  }

  @override
  Future<CustomerVehicle> save(
      {String? id,
      required VehicleKind kind,
      required String brandModel,
      required String licensePlate,
      required String color,
      required String notes}) async {
    if (failSave) throw Exception('offline');
    final vehicle = CustomerVehicle(
        id: id ?? 'new',
        customerId: 'owner',
        kind: kind,
        brandModel: brandModel,
        licensePlate: licensePlate,
        color: color,
        notes: notes);
    vehicles = [vehicle, ...vehicles.where((item) => item.id != vehicle.id)];
    return vehicle;
  }

  @override
  Future<void> delete(String id) async {
    deletes++;
    if (failDelete) throw Exception('offline');
    vehicles.removeWhere((vehicle) => vehicle.id == id);
  }
}

class RequestCapture extends AppController {
  CustomerVehicle? submitted;
  VehicleKind? submittedKind;
  @override
  bool get isLoggedIn => true;
  @override
  Future<RescueRequestData> createRequest(
      {required String clientRequestId,
      required String address,
      required String description,
      required String contactName,
      required String contactPhone,
      double? latitude,
      double? longitude,
      bool openTracking = true}) async {
    submitted = selectedSavedVehicle;
    submittedKind = vehicle;
    return RescueRequestData(
        id: 'request',
        service: RescueService.tire,
        vehicle: vehicle,
        address: address,
        createdAt: DateTime(2026),
        stage: RequestStage.searching);
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
  Future<void> mount(WidgetTester tester, VehiclesFake repo) async {
    await tester.pumpWidget(MaterialApp(
        home:
            CustomerVehiclesScreen(controller: controller, repository: repo)));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'empty, add validation, failed save keeps input, edit and confirmed delete',
      (tester) async {
    final repo = VehiclesFake();
    await mount(tester, repo);
    expect(find.text('Chưa có xe đã lưu'), findsOneWidget);
    await tapRequest(tester, find.text('Thêm xe'));
    await tester.pumpAndSettle();
    await revealRequest(tester, find.text('Lưu xe'));
    await tapRequest(tester, find.text('Lưu xe'));
    await tester.pumpAndSettle();
    expect(find.text('Vui lòng nhập hãng/hiệu xe.'), findsOneWidget);
    await enterRequest(tester, find.byType(TextFormField).at(0), 'Toyota Vios');
    repo.failSave = true;
    await revealRequest(tester, find.text('Lưu xe'));
    await tapRequest(tester, find.text('Lưu xe'));
    await tester.pumpAndSettle();
    expect(find.text('Toyota Vios'), findsOneWidget);
    expect(find.text('Không lưu được xe. Thông tin đã nhập vẫn được giữ.'),
        findsOneWidget);
    repo.failSave = false;
    await revealRequest(tester, find.text('Lưu xe'));
    await tapRequest(tester, find.text('Lưu xe'));
    await tester.pumpAndSettle();
    expect(find.text('Toyota Vios'), findsOneWidget);
    await tapRequest(tester, find.text('Sửa xe'));
    await tester.pumpAndSettle();
    await enterRequest(
        tester, find.byType(TextFormField).at(0), 'Toyota Yaris');
    await revealRequest(tester, find.text('Lưu xe'));
    await tapRequest(tester, find.text('Lưu xe'));
    await tester.pumpAndSettle();
    expect(find.text('Toyota Yaris'), findsOneWidget);
    await tapRequest(tester, find.text('Xóa'));
    await tester.pumpAndSettle();
    await tapRequest(tester, find.text('Giữ lại'));
    await tester.pumpAndSettle();
    expect(repo.deletes, 0);
    await tapRequest(tester, find.text('Xóa'));
    await tester.pumpAndSettle();
    await tapRequest(tester, find.text('Xóa xe'));
    await tester.pumpAndSettle();
    expect(repo.deletes, 1);
    expect(find.text('Chưa có xe đã lưu'), findsOneWidget);
  });

  testWidgets('load retry, all vehicle details, delete failure keeps vehicle',
      (tester) async {
    final repo = VehiclesFake()
      ..vehicles = [truck]
      ..failList = true;
    await mount(tester, repo);
    expect(find.text('Không tải được danh sách xe. Vui lòng thử lại.'),
        findsOneWidget);
    repo.failList = false;
    await tapRequest(tester, find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(find.text('Xe tải'), findsOneWidget);
    expect(find.text('Biển số: 51C-12345'), findsOneWidget);
    expect(find.text('Màu xe: Trắng'), findsOneWidget);
    repo.failDelete = true;
    await tapRequest(tester, find.text('Xóa'));
    await tester.pumpAndSettle();
    await tapRequest(tester, find.text('Xóa xe'));
    await tester.pumpAndSettle();
    expect(find.text('Isuzu QKR'), findsOneWidget);
    expect(find.text('Không xóa được xe. Vui lòng thử lại.'), findsOneWidget);
  });

  testWidgets('loading result from old session is discarded', (tester) async {
    final repo = VehiclesFake()..pending = Completer<List<CustomerVehicle>>();
    await tester.pumpWidget(MaterialApp(
        home:
            CustomerVehiclesScreen(controller: controller, repository: repo)));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    UserSession.clear();
    controller.selectTab(4);
    repo.pending!.complete([truck]);
    await tester.pumpAndSettle();
    expect(find.text('Isuzu QKR'), findsNothing);
    expect(find.text('Vui lòng đăng nhập để quản lý xe.'), findsOneWidget);
  });

  testWidgets(
      'picker selects saved kind, manual choice clears id, deleted vehicle invalidates selection',
      (tester) async {
    final repo = VehiclesFake()..vehicles = [truck];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SavedVehiclePicker(
                controller: controller, locked: false, repository: repo))));
    await tester.pumpAndSettle();
    await tapRequest(tester, find.text('Phương tiện thủ công'));
    await tester.pumpAndSettle();
    await tapRequest(tester, find.text(truck.label).last);
    await tester.pumpAndSettle();
    expect(controller.selectedSavedVehicle?.id, 'truck');
    expect(controller.vehicle, VehicleKind.truck);
    controller.selectVehicle(VehicleKind.car);
    await tester.pumpAndSettle();
    expect(controller.selectedSavedVehicle, isNull);
    controller.selectSavedVehicle(truck);
    repo.vehicles = [];
    await tapRequest(tester, find.text('Tải lại xe đã lưu'));
    await tester.pumpAndSettle();
    expect(controller.selectedSavedVehicle, isNull);
    expect(find.textContaining('Xe đã chọn không còn'), findsOneWidget);
  });

  test('controller refuses another owner and tracks edits/deletion', () {
    controller.selectSavedVehicle(const CustomerVehicle(
        id: 'foreign',
        customerId: 'other',
        kind: VehicleKind.car,
        brandModel: 'Other'));
    expect(controller.selectedSavedVehicle, isNull);
    controller.selectSavedVehicle(truck);
    controller.vehicleChanged(truck.id);
    expect(controller.selectedSavedVehicle, isNull);
  });

  testWidgets(
      'request form submits selected saved truck; switching to manual sends no saved vehicle',
      (tester) async {
    tester.view.physicalSize = const Size(420, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final capture = RequestCapture()..selectedService = RescueService.tire;
    addTearDown(capture.dispose);
    final repo = VehiclesFake()..vehicles = [truck];
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: NewRequestScreen(
                controller: capture, vehicleRepository: repo))));
    await tester.pumpAndSettle();
    await tapRequest(tester, find.text('Phương tiện thủ công'));
    await tester.pumpAndSettle();
    await tapRequest(tester, find.text('Isuzu QKR').last);
    await tester.pumpAndSettle();
    final fields = find.byType(TextFormField, skipOffstage: false);
    await enterRequest(tester, fields.at(0), '123 Nguyễn Huệ');
    await enterRequest(tester, fields.at(2), 'An');
    await enterRequest(tester, fields.at(3), '0901234567');
    await tapRequest(tester, find.byType(CheckboxListTile));
    await tester.scrollUntilVisible(find.text('XÁC NHẬN ĐẶT CỨU HỘ'), 250,
        scrollable: find.byType(Scrollable).first, continuous: true);
    await tapRequest(tester, find.text('XÁC NHẬN ĐẶT CỨU HỘ'));
    await tester.pumpAndSettle();
    expect(capture.submitted?.id, truck.id);
    expect(capture.submittedKind, VehicleKind.truck);
    // The fake stays on the form after success; dismiss feedback before
    // submitting again so the floating snackbar cannot cover the CTA.
    ScaffoldMessenger.of(tester.element(find.byType(NewRequestScreen)))
        .removeCurrentSnackBar();
    await tester.pumpAndSettle();
    await revealRequest(
        tester, find.byType(DropdownButtonFormField<VehicleKind>));
    await tapRequest(tester, find.byType(DropdownButton<VehicleKind>));
    await tester.pumpAndSettle();
    await tapRequest(tester, find.text('Ô tô').last);
    await tester.pumpAndSettle();
    await tapRequest(tester, find.byType(CheckboxListTile));
    await tester.scrollUntilVisible(find.text('XÁC NHẬN ĐẶT CỨU HỘ'), 250,
        scrollable: find.byType(Scrollable).first, continuous: true);
    await tapRequest(tester, find.text('XÁC NHẬN ĐẶT CỨU HỘ'));
    await tester.pumpAndSettle();
    expect(capture.submitted, isNull);
    expect(capture.submittedKind, VehicleKind.car);
  });
}
