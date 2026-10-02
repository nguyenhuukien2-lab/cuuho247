import 'dart:convert';

import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/app/app_theme.dart';
import 'package:cuu_ho_247/screens/new_request_screen.dart';
import 'package:cuu_ho_247/services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'request_failure_test.dart' as failure;
import 'request_location_test.dart' as location;
import 'request_photo_repository_test.dart' as transport;
import 'request_photos_test.dart' as photos;

const addressMessage = 'Vui lòng nhập địa chỉ cứu hộ';

Future<RescueRequestData> create(SupabaseClient client, String address) =>
    SupabaseService.createRescueRequest(
        client: client,
        clientRequestId: transport.requestId,
        vehicle: VehicleKind.car,
        service: RescueService.tire,
        locationText: address,
        description: '',
        contactName: 'Khách hàng',
        contactPhone: '0900000000',
        latitude: 10.7,
        longitude: 106.7);

Finder addressField() => find.widgetWithText(TextFormField, 'Địa chỉ');

bool addressHasFocus(WidgetTester tester) => tester
    .widget<TextField>(
        find.descendant(of: addressField(), matching: find.byType(TextField)))
    .focusNode!
    .hasFocus;

void main() {
  for (final value in ['', '   \n\t ']) {
    test('service rejects blank address before RPC: ${value.length}', () async {
      var calls = 0;
      final client = await transport.clientFor(MockClient((request) async {
        calls++;
        return transport.jsonResponse(request, {});
      }));
      await expectLater(
          create(client, value),
          throwsA(isA<AppFailure>()
              .having((e) => e.message, 'message', addressMessage)));
      expect(calls, 0);
    });

    test('controller rejects blank address before service: ${value.length}',
        () async {
      final controller = AppController()..selectedService = RescueService.tire;
      addTearDown(controller.dispose);
      // No Supabase singleton/configuration is initialized in this test.
      await expectLater(
          controller.createRequest(
              clientRequestId: transport.requestId,
              address: value,
              description: '',
              contactName: 'Khách hàng',
              contactPhone: '0900000000'),
          throwsA(isA<AppFailure>()
              .having((e) => e.locationRequired, 'address validation', true)));
      expect(controller.activeRequest, isNull);
    });

    testWidgets(
        'blank address keeps form and photos without controller call: ${value.length}',
        (tester) async {
      final controller = photos.PhotoController();
      final repository = photos.FakePhotos();
      await photos.mount(tester, controller, photos.FakePicker(), repository);
      await tester.tap(find.text('Chọn ảnh'));
      await tester.pumpAndSettle();
      await tester.enterText(addressField(), value);
      tester.testTextInput.hide();
      await tester.pump();
      await tester.tap(find.text('Gửi yêu cầu cứu hộ'));
      await tester.pumpAndSettle();
      expect(controller.creates, 0);
      expect(repository.uploaded, isEmpty);
      expect(
          find.descendant(
              of: addressField(), matching: find.text(addressMessage)),
          findsOneWidget);
      expect(addressHasFocus(tester), isTrue);
      expect(find.text('Xe nổ lốp'), findsOneWidget);
      expect(find.text('Khách hàng'), findsOneWidget);
      expect(find.text('0900000000'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      await tester.enterText(addressField(), '  456 Lê Lợi  ');
      tester.testTextInput.hide();
      await tester.pump();
      await location.sendRequest(tester);
      expect(controller.creates, 1);
      expect(repository.uploaded, ['photo-1']);
    });
  }

  testWidgets('phone submit validates address even when field is offscreen',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = location.CapturingController()
      ..selectedService = RescueService.tire;
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: NewRequestScreen(controller: controller))));
    final scroll = tester
        .widget<CustomScrollView>(find.byType(CustomScrollView))
        .controller!;
    for (var i = 0;
        i < 8 && find.byType(CheckboxListTile).evaluate().isEmpty;
        i++) {
      scroll.jumpTo(scroll.position.maxScrollExtent);
      await tester.pumpAndSettle();
    }
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    expect(tester.getRect(addressField()).bottom, lessThan(0));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Gửi yêu cầu cứu hộ'));
    await tester.pumpAndSettle();
    expect(controller.submissions, isEmpty);
    expect(
        find.descendant(
            of: addressField(), matching: find.text(addressMessage)),
        findsOneWidget);
    expect(addressHasFocus(tester), isTrue);
    expect(tester.getRect(addressField()).top, greaterThanOrEqualTo(0));
    expect(tester.getRect(addressField()).bottom, lessThanOrEqualTo(844));
  });

  for (final useMap in [false, true]) {
    testWidgets(
        '${useMap ? 'map' : 'GPS'} coordinates cannot replace text address',
        (tester) async {
      final controller = location.CapturingController();
      final gps = location.FakeLocationService();
      await location.mountForm(tester, controller, gps);
      await tester.enterText(addressField(), ' ');
      tester.testTextInput.hide();
      await tester.pumpAndSettle();
      if (useMap) {
        await tester.tapAt(
            tester.getCenter(find.byType(FlutterMap)) + const Offset(35, -20));
        await tester.pump(const Duration(milliseconds: 400));
      } else {
        await tester.tap(find.text('Lấy vị trí hiện tại'));
        gps.pending.complete(location.located);
      }
      await tester.pumpAndSettle();
      expect(find.textContaining('Tọa độ:'), findsOneWidget);
      await location.sendRequest(tester);
      expect(controller.submissions, isEmpty);
      expect(find.text(addressMessage), findsOneWidget);
    });
  }

  testWidgets(
      'client validation between retries preserves idempotency key and latest text',
      (tester) async {
    final controller = failure.FailingRequestController()
      ..selectedService = RescueService.tire;
    tester.view.physicalSize = const Size(420, 3100);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: NewRequestScreen(controller: controller))));
    await tester.enterText(addressField(), '123 Nguyễn Huệ');
    await tester.enterText(find.byType(TextFormField).at(2), 'An');
    await tester.enterText(find.byType(TextFormField).at(3), '0900000000');
    tester.testTextInput.hide();
    await location.sendRequest(tester);
    final originalKey = controller.keys.single;
    await tester.enterText(addressField(), '   ');
    tester.testTextInput.hide();
    await tester.pump();
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(controller.keys, [originalKey]);
    await tester.enterText(addressField(), '  789 Lê Lợi  ');
    tester.testTextInput.hide();
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pump();
    await tester.tap(find.text('Thử lại'));
    await tester.pumpAndSettle();
    expect(controller.keys, [originalKey, originalKey]);
    expect(controller.submittedAddresses.last, '789 Lê Lợi');
  });

  test('RPC receives trimmed text, original key and coordinates', () async {
    final client = await transport.clientFor(MockClient((request) async {
      expect(request.url.path, endsWith('/rpc/create_customer_rescue_request'));
      final body = jsonDecode(request.body) as Map;
      expect(body['p_location_text'], '123 Nguyễn Huệ');
      expect(body['p_client_request_id'], transport.requestId);
      expect(body['p_latitude'], 10.7);
      expect(body['p_longitude'], 106.7);
      return transport.jsonResponse(request, {
        'id': transport.requestId,
        'client_request_id': transport.requestId,
        'service_code': 'tire',
        'vehicle_kind': 'car',
        'location_text': body['p_location_text'],
        'created_at': '2026-10-01T00:00:00Z',
        'status': 'searching',
      });
    }));
    expect(
        (await create(client, '  123 Nguyễn Huệ  ')).address, '123 Nguyễn Huệ');
  });

  for (final error in [
    (
      code: '22023',
      message: 'LOCATION_REQUIRED',
      expected: addressMessage,
      session: false
    ),
    (
      code: 'P0001',
      message: 'ACTIVE_REQUEST_EXISTS',
      expected: 'Bạn đang có một yêu cầu được xử lý.',
      session: false
    ),
    (
      code: '23505',
      message:
          'duplicate key violates rescue_requests_one_active_per_customer_uidx',
      expected: 'Bạn đang có một yêu cầu được xử lý.',
      session: false
    ),
    (
      code: '42501',
      message: 'AUTHENTICATION_REQUIRED',
      expected: 'Vui lòng đăng nhập lại.',
      session: true
    ),
    (
      code: 'PGRST301',
      message: 'JWT expired',
      expected: 'Vui lòng đăng nhập lại.',
      session: true
    ),
    (
      code: '22023',
      message: 'INTERNAL_PRIVATE_DIAGNOSTIC',
      expected: 'Máy chủ chưa thể xử lý yêu cầu.',
      session: false
    ),
  ]) {
    test('backend ${error.message} maps to safe Vietnamese message', () async {
      final client = await transport.clientFor(MockClient((request) async =>
          transport.jsonResponse(
              request,
              {
                'code': error.code,
                'message': error.message,
                'details': 'Bad Request'
              },
              400)));
      await expectLater(
          create(client, 'Địa chỉ'),
          throwsA(isA<AppFailure>()
              .having((e) => e.message, 'message', contains(error.expected))
              .having((e) => e.sessionExpired, 'session', error.session)
              .having((e) => e.locationRequired, 'address',
                  error.message == 'LOCATION_REQUIRED')));
    });
  }

  test('network failure offers Internet check and retry', () async {
    final client = await transport.clientFor(MockClient((request) async {
      throw http.ClientException('offline');
    }));
    await expectLater(
        create(client, 'Địa chỉ'),
        throwsA(isA<AppFailure>().having((e) => e.message, 'network',
            contains('kiểm tra kết nối Internet và thử lại'))));
  });
}
