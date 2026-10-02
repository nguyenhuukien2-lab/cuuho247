import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/app/app_theme.dart';
import 'package:cuu_ho_247/screens/new_request_screen.dart';
import 'package:cuu_ho_247/services/request_photo_service.dart';
import 'package:cuu_ho_247/services/supabase_service.dart';
import 'package:cuu_ho_247/widgets/request_photos_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';

Uint8List png() => base64Decode(
    'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGP4z8DwHwAFAAH/iZk9HQAAAABJRU5ErkJggg==');
SelectedRequestPhoto photo(String id) =>
    SelectedRequestPhoto(id: id, bytes: png(), contentType: 'image/png');

class FakePicker implements RequestPhotoPicker {
  int count = 0;
  bool cancel = false;
  bool fail = false;
  final cameras = <bool>[];
  @override
  Future<SelectedRequestPhoto?> pick({required bool camera}) async {
    cameras.add(camera);
    if (fail) throw const AppFailure('Không mở được camera.');
    return cancel ? null : photo('photo-${++count}');
  }

  @override
  Future<List<SelectedRequestPhoto>> recoverLostPhotos() async => [];
}

class FakePhotos implements RequestPhotoRepository {
  final uploaded = <String>[];
  final requestIds = <String>[];
  String? failId;
  bool listFails = false;
  List<RequestPhoto> items = [];
  Completer<List<RequestPhoto>>? pendingList;
  @override
  Future<void> upload(String requestId, SelectedRequestPhoto photo) async {
    requestIds.add(requestId);
    if (photo.id == failId) throw const AppFailure('Mất kết nối.');
    uploaded.add(photo.id);
  }

  @override
  Future<List<RequestPhoto>> list(String requestId) async {
    if (listFails) throw const AppFailure('Mất kết nối.');
    if (pendingList != null) return pendingList!.future;
    return items;
  }
}

class PhotoController extends AppController {
  int creates = 0;
  bool fail = false;
  bool returnOtherRequest = false;
  final keys = <String>[];
  @override
  bool get isLoggedIn => true;
  @override
  bool get backendConfigured => true;
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
    creates++;
    keys.add(clientRequestId);
    if (fail) throw const AppFailure('Tạo đơn thất bại.');
    expect(openTracking, isFalse);
    return RescueRequestData(
        id: 'request-1',
        service: RescueService.tire,
        vehicle: VehicleKind.car,
        address: address,
        createdAt: DateTime.utc(2026),
        stage: RequestStage.searching,
        clientRequestId: returnOtherRequest ? 'other-key' : clientRequestId);
  }
}

Future<void> mount(WidgetTester tester, PhotoController controller,
    FakePicker picker, FakePhotos repository) async {
  tester.view.physicalSize = const Size(430, 3100);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(controller.dispose);
  controller.selectedService = RescueService.tire;
  controller.tabIndex = 1;
  await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light,
      home: Scaffold(
          body: NewRequestScreen(
              controller: controller,
              photoPicker: picker,
              photoRepository: repository))));
  final fields = find.byType(TextFormField);
  await tester.enterText(fields.at(0), 'Địa chỉ được giữ lại');
  await tester.enterText(fields.at(1), 'Xe nổ lốp');
  await tester.enterText(fields.at(2), 'Khách hàng');
  await tester.enterText(fields.at(3), '0900000000');
  tester.testTextInput.hide();
  await tester.tap(find.byType(CheckboxListTile));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
      'photo validation uses actual bytes; rejects oversized/invalid images',
      (tester) async {
    await tester.runAsync(() async {
      final valid = await SelectedRequestPhoto.fromFile(
          XFile.fromData(png(), name: 'wrong.txt'));
      expect(valid.contentType, 'image/png');
      await expectLater(
          SelectedRequestPhoto.fromFile(
              XFile.fromData(Uint8List(SelectedRequestPhoto.maxBytes + 1))),
          throwsA(isA<AppFailure>()));
      await expectLater(
          SelectedRequestPhoto.fromFile(
              XFile.fromData(Uint8List.fromList([1, 2, 3]))),
          throwsA(isA<AppFailure>()));
      await expectLater(
          SelectedRequestPhoto.fromFile(
              XFile.fromData(Uint8List.fromList([0xff, 0xd8, 0xff]))),
          throwsA(isA<AppFailure>()));
    });
  });

  testWidgets(
      'pick/camera previews, limit three, remove, cancel and picker error',
      (tester) async {
    final picker = FakePicker();
    await mount(tester, PhotoController(), picker, FakePhotos());
    for (final label in ['Chọn ảnh', 'Chụp ảnh', 'Chọn ảnh']) {
      await tester.tap(find.text(label));
      await tester.pumpAndSettle();
    }
    expect(find.byType(Image), findsNWidgets(3));
    expect(picker.cameras, [false, true, false]);
    await tester.tap(find.text('Chọn ảnh'));
    expect(picker.count, 3);
    await tester.tap(find.byTooltip('Bỏ ảnh').first);
    await tester.pumpAndSettle();
    picker.cancel = true;
    await tester.tap(find.text('Chọn ảnh'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNWidgets(2));
    picker.fail = true;
    await tester.tap(find.text('Chụp ảnh'));
    await tester.pumpAndSettle();
    expect(find.text('Không mở được camera.'), findsOneWidget);
    expect(find.text('Địa chỉ được giữ lại'), findsOneWidget);
  });

  testWidgets(
      'partial upload preserves form and retries only missing photos without recreating request',
      (tester) async {
    final controller = PhotoController();
    final repository = FakePhotos()..failId = 'photo-2';
    await mount(tester, controller, FakePicker(), repository);
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Chọn ảnh'));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.text('Gửi yêu cầu cứu hộ'));
    await tester.pumpAndSettle();
    expect(controller.creates, 1);
    expect(controller.tabIndex, 1);
    expect(repository.uploaded, ['photo-1']);
    expect(find.textContaining('Mất kết nối.'), findsOneWidget);
    expect(find.byType(Image), findsNWidgets(3));
    for (final value in [
      'Địa chỉ được giữ lại',
      'Xe nổ lốp',
      'Khách hàng',
      '0900000000'
    ]) {
      expect(find.text(value), findsOneWidget);
    }
    repository.failId = null;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(controller.creates, 1);
    expect(repository.uploaded, ['photo-1', 'photo-2', 'photo-3']);
    expect(repository.requestIds.toSet(), {'request-1'});
    expect(controller.tabIndex, 2);
    expect(find.byType(Image), findsNothing);
  });

  testWidgets(
      'create failure preserves photo and key; uploads only after successful create',
      (tester) async {
    final controller = PhotoController()..fail = true;
    final repository = FakePhotos();
    await mount(tester, controller, FakePicker(), repository);
    await tester.tap(find.text('Chọn ảnh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi yêu cầu cứu hộ'));
    await tester.pumpAndSettle();
    expect(repository.uploaded, isEmpty);
    expect(find.byType(Image), findsOneWidget);
    controller.fail = false;
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(controller.keys.toSet(), hasLength(1));
    expect(repository.uploaded, ['photo-1']);
  });

  testWidgets(
      'never attaches draft photos to another active request returned by RPC',
      (tester) async {
    final controller = PhotoController()..returnOtherRequest = true;
    final repository = FakePhotos();
    await mount(tester, controller, FakePicker(), repository);
    await tester.tap(find.text('Chọn ảnh'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Gửi yêu cầu cứu hộ'));
    await tester.pumpAndSettle();
    expect(repository.uploaded, isEmpty);
    expect(find.textContaining('Ảnh chưa được gửi.'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
  });

  testWidgets(
      'tracking shows list, handles empty/error/retry, discards old customer results',
      (tester) async {
    final repository = FakePhotos()
      ..items = [const RequestPhoto(id: 'a', url: 'https://example.test/a')];
    Widget card(String customer) => MaterialApp(
        home: Scaffold(
            body: RequestPhotosCard(
                requestId: 'request-1',
                customerId: customer,
                isActive: true,
                repository: repository)));
    await tester.pumpWidget(card('customer-a'));
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsOneWidget);
    repository.listFails = true;
    await tester.tap(find.byTooltip('Tải lại ảnh'));
    await tester.pumpAndSettle();
    expect(find.text('Không tải được ảnh sự cố. Vui lòng thử lại.'),
        findsOneWidget);
    repository.listFails = false;
    repository.items = [];
    await tester.tap(find.byTooltip('Tải lại ảnh'));
    await tester.pumpAndSettle();
    expect(find.text('Chưa có ảnh sự cố.'), findsOneWidget);
    final old = Completer<List<RequestPhoto>>();
    repository.pendingList = old;
    await tester.tap(find.byTooltip('Tải lại ảnh'));
    await tester.pump();
    repository.pendingList = null;
    await tester.pumpWidget(card('customer-b'));
    old.complete([const RequestPhoto(id: 'a', url: 'https://example.test/a')]);
    await tester.pumpAndSettle();
    expect(find.byType(Image), findsNothing);
    expect(find.text('Chưa có ảnh sự cố.'), findsOneWidget);
  });
}
