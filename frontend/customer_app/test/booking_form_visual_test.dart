import 'dart:io';

import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/app/app_theme.dart';
import 'package:cuu_ho_247/app/user_session.dart';
import 'package:cuu_ho_247/screens/new_request_screen.dart';
import 'package:cuu_ho_247/screens/customer_vehicles_screen.dart';
import 'package:cuu_ho_247/services/customer_vehicle_service.dart';
import 'package:cuu_ho_247/services/location_service.dart';
import 'package:cuu_ho_247/widgets/booking_form_ui.dart';
import 'package:cuu_ho_247/widgets/booking_ui.dart';
import 'package:cuu_ho_247/widgets/booking_detail_sections.dart';
import 'package:cuu_ho_247/widgets/customer_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'customer_vehicles_test.dart' as vehicles;
import 'request_steps.dart';
import 'request_photos_test.dart' as photos;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    final artifacts = File(Platform.resolvedExecutable).parent.parent.parent;
    final root = Platform.environment['FLUTTER_ROOT'];
    final candidates = [
      File('${artifacts.path}/material_fonts/roboto-regular.ttf'),
      if (root != null)
        File('$root/bin/cache/artifacts/material_fonts/roboto-regular.ttf'),
    ];
    final font = candidates.firstWhere((file) => file.existsSync());
    await (FontLoader('Roboto')
          ..addFont(
              Future.value(ByteData.sublistView(await font.readAsBytes()))))
        .load();
  });
  tearDown(UserSession.clear);

  testWidgets('selected service replaces grid and change action reopens it',
      (tester) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: NewRequestScreen(controller: controller))));
    await tester.pumpAndSettle();
    expect(find.byType(ServiceGrid), findsOneWidget);
    expect(
        tester
            .widget<CustomerStepIndicator>(find.byType(CustomerStepIndicator))
            .visualStep,
        0);
    await tester.tap(find.text('Kích bình'));
    await tester.pumpAndSettle();
    expect(controller.selectedService, RescueService.battery);
    expect(find.byType(ServiceGrid), findsNothing);
    expect(find.byType(SelectedServiceCard), findsOneWidget);
    expect(find.text('Đã chọn'), findsOneWidget);
    expect(find.text('Báo giá sau khi tiếp nhận'), findsOneWidget);
    final indicator = tester
        .widget<CustomerStepIndicator>(find.byType(CustomerStepIndicator));
    expect(indicator.step, 0); // Presentation does not advance the real form.
    expect(indicator.visualStep, 1);
    final completed =
        tester.widget<ChoiceChip>(find.byKey(const ValueKey('request-step-0')));
    expect(completed.backgroundColor, BookingFormStyle.green);
    expect(
        find.descendant(
            of: find.byKey(const ValueKey('request-step-0')),
            matching: find.byIcon(Icons.check)),
        findsOneWidget);
    expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('request-step-1')))
            .selected,
        isTrue);
    expect(
        tester
            .widget<ColoredBox>(
                find.byKey(const ValueKey('request-connector-0')))
            .color,
        BookingFormStyle.green);
    for (var connector = 1; connector < 4; connector++) {
      expect(
          tester
              .widget<ColoredBox>(
                  find.byKey(ValueKey('request-connector-$connector')))
              .color,
          BookingFormStyle.border);
    }
    await tester.tap(find.text('Đổi dịch vụ'));
    await tester.pumpAndSettle();
    expect(find.byType(ServiceGrid), findsOneWidget);
    expect(find.byType(SelectedServiceCard), findsNothing);
    expect(
        tester
            .widget<CustomerStepIndicator>(find.byType(CustomerStepIndicator))
            .visualStep,
        0);
    await tester.tap(find.text('Vá lốp'));
    await tester.pumpAndSettle();
    expect(controller.selectedService, RescueService.tire);
    expect(find.byType(ServiceGrid), findsNothing);
    expect(
        tester
            .widget<SelectedServiceCard>(find.byType(SelectedServiceCard))
            .service,
        RescueService.tire);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'empty location chooses existing editor and real address becomes pickup',
      (tester) async {
    final controller = AppController()..selectedService = RescueService.tire;
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: NewRequestScreen(controller: controller))));
    final empty = find.byKey(const ValueKey('booking-location-empty'));
    await tester.ensureVisible(empty);
    await tester.pumpAndSettle();
    expect(find.text('Chưa chọn vị trí cứu hộ'), findsOneWidget);
    await tester.tap(find.text('Chọn vị trí'));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('request-step-2')))
            .selected,
        isTrue);
    final address = find.widgetWithText(TextFormField, 'Địa chỉ');
    await enterRequest(tester, address, '75 Điện Biên Phủ');
    await requestStep(tester, 0);
    final summary = find.byKey(const ValueKey('booking-location-summary'));
    await tester.ensureVisible(summary);
    await tester.pumpAndSettle();
    expect(find.descendant(of: summary, matching: find.text('ĐIỂM ĐÓN XE')),
        findsOneWidget);
    expect(
        find.descendant(of: summary, matching: find.text('75 Điện Biên Phủ')),
        findsOneWidget);
    expect(find.descendant(of: summary, matching: find.text('Tọa độ đã chọn')),
        findsNothing);
    await tester
        .tap(find.descendant(of: summary, matching: find.text('Đổi vị trí')));
    await tester.pumpAndSettle();
    expect(tester.widget<TextFormField>(address).controller!.text,
        '75 Điện Biên Phủ');
    expect(tester.takeException(), isNull);
  });

  testWidgets(
      'incident empty opens editor; actual text and photo are previewed and removable',
      (tester) async {
    final controller = AppController()..selectedService = RescueService.tire;
    addTearDown(controller.dispose);
    final picker = photos.FakePicker();
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
            body: NewRequestScreen(
                controller: controller,
                photoPicker: picker,
                photoRepository: photos.FakePhotos()))));
    final empty = find.byKey(const ValueKey('booking-incident-empty'));
    await tester.ensureVisible(empty);
    await tester.pumpAndSettle();
    expect(find.text('Thêm mô tả hoặc ảnh sự cố'), findsOneWidget);
    await tester.tap(find.text('Bổ sung mô tả / ảnh'));
    await tester.pumpAndSettle();
    final description = find.byType(TextFormField, skipOffstage: false).at(1);
    await enterRequest(tester, description, 'Xe mất điện, không khởi động');
    await tapRequest(tester, find.text('Chọn ảnh'));
    await tester.pumpAndSettle();
    await requestStep(tester, 0);
    final summary = find.byKey(const ValueKey('booking-incident-summary'));
    await tester.ensureVisible(summary);
    await tester.pumpAndSettle();
    expect(
        find.descendant(
            of: summary, matching: find.text('Xe mất điện, không khởi động')),
        findsOneWidget);
    expect(find.descendant(of: summary, matching: find.byType(Image)),
        findsOneWidget);
    expect(find.descendant(of: summary, matching: find.text('1/3 ảnh')),
        findsOneWidget);
    final remove =
        find.descendant(of: summary, matching: find.byTooltip('Bỏ ảnh'));
    await tester.ensureVisible(remove);
    await tester.tap(remove);
    await tester.pumpAndSettle();
    expect(find.descendant(of: summary, matching: find.byType(Image)),
        findsNothing);
    expect(find.descendant(of: summary, matching: find.text('0/3 ảnh')),
        findsOneWidget);
    expect(find.descendant(of: summary, matching: find.text('Thêm ảnh')),
        findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('booking request code never exposes internal UUIDs', () {
    expect(bookingRequestCode('CH-000042'), 'CH-000042');
    expect(bookingRequestCode(null), 'Chưa có mã');
    expect(bookingRequestCode('11111111-1111-4111-8111-111111111111'),
        'Chưa có mã');
  });

  testWidgets('new draft does not borrow a quote from another active request',
      (tester) async {
    final controller = AppController()..selectedService = RescueService.tire;
    addTearDown(controller.dispose);
    controller.activeRequest = RescueRequestData(
        id: '11111111-1111-4111-8111-111111111111',
        quoteCode: 'BG-000099',
        requestCode: 'CH-000099',
        service: RescueService.tire,
        vehicle: VehicleKind.car,
        address: 'Địa chỉ đơn cũ',
        createdAt: DateTime(2026),
        stage: RequestStage.accepted,
        price: 600000);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: NewRequestScreen(controller: controller))));
    await requestStep(tester, 4);
    final quote = find.byKey(const ValueKey('booking-quote-card'));
    await tester.ensureVisible(quote);
    await tester.pumpAndSettle();
    expect(find.text('Chưa có báo giá'), findsOneWidget);
    expect(find.textContaining('600.000'), findsNothing);
    expect(find.text('BG-000099'), findsNothing);
    expect(find.byKey(const ValueKey('booking-real-total')), findsNothing);
    expect(find.textContaining('11111111-1111'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 1.3, 1.5]) {
      testWidgets('populated location and incident cards fit $width / $scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        var removed = -1;
        var edited = 0;
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: Scaffold(
                body: SingleChildScrollView(
                    padding: const EdgeInsets.all(18),
                    child: Column(children: [
                      BookingLocationSummary(
                          address:
                              '75 Điện Biên Phủ, phường Đa Kao, quận 1, Thành phố Hồ Chí Minh',
                          coordinates: const RescueCoordinates(10.7, 106.7),
                          onEdit: () => edited++),
                      const SizedBox(height: 18),
                      BookingIncidentSummary(
                          description:
                              'Xe không khởi động, đèn trên bảng điều khiển không sáng.',
                          photos: [
                            photos.photo('one'),
                            photos.photo('two'),
                            photos.photo('three')
                          ],
                          uploaded: const {'one'},
                          onEdit: () => edited++,
                          onAdd: null,
                          onRemove: (index) => removed = index),
                    ])))));
        expect(find.text('Tọa độ đã chọn'), findsOneWidget);
        expect(find.text('3/3 ảnh'), findsOneWidget);
        expect(find.byType(Image), findsNWidgets(3));
        expect(find.text('Thêm ảnh'), findsNothing);
        expect(find.text('Đã gửi'), findsOneWidget);
        expect(tester.takeException(), isNull);
        final remove = find.byTooltip('Bỏ ảnh').first;
        await tester.ensureVisible(remove);
        await tester.pumpAndSettle();
        await tester.tap(remove);
        expect(removed, 0);
        final edit = find.text('Chỉnh sửa mô tả / ảnh');
        await tester.ensureVisible(edit);
        await tester.pumpAndSettle();
        await tester.tap(edit);
        expect(edited, 1);
        expect(find.textContaining('GARAGE'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('booking skeleton and sticky footer at $width / $scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        UserSession.userId = 'owner';
        final controller = AppController()
          ..selectedService = RescueService.tire;
        addTearDown(controller.dispose);
        final repository = vehicles.VehiclesFake();
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.light,
            builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: TextScaler.linear(scale)),
                child: child!),
            home: Scaffold(
                body: NewRequestScreen(
                    controller: controller, vehicleRepository: repository),
                bottomNavigationBar:
                    CustomerBottomNav(controller: controller))));
        await tester.pumpAndSettle();
        expect(find.byType(ServiceGrid), findsNothing);
        expect(find.byKey(const ValueKey('booking-empty-vehicles')),
            findsOneWidget);
        expect(find.byType(BookingLocationSummary), findsOneWidget);
        expect(find.byType(BookingIncidentSummary), findsOneWidget);
        for (var step = 0; step < 5; step++) {
          final point = find.byKey(ValueKey('request-step-$step'));
          expect(point, findsOneWidget);
          expect(point.hitTestable(), findsOneWidget);
        }
        for (var step = 0; step < 5; step++) {
          await requestStep(tester, step);
          await tester.pumpAndSettle();
          expect(
              tester
                  .widget<ChoiceChip>(find
                      .byKey(ValueKey('request-step-${step == 0 ? 1 : step}')))
                  .selected,
              isTrue);
          final footer = find.byKey(const ValueKey('booking-submit-button'));
          if (step < 4) expect(find.text('TIẾP TỤC'), findsOneWidget);
          final nav = find.byType(CustomerBottomNav);
          expect(tester.getRect(footer).bottom,
              lessThanOrEqualTo(tester.getRect(nav).top));
          expect(tester.getRect(footer).left, greaterThanOrEqualTo(18));
          if (step == 1) {
            final empty = find.byKey(const ValueKey('booking-empty-vehicles'));
            await tester.ensureVisible(empty);
            expect(find.text('0 xe có sẵn'), findsOneWidget);
            expect(find.text('Chưa có xe đã lưu'), findsOneWidget);
            expect(find.text('Thêm phương tiện'), findsOneWidget);
          }
          if (step == 4) {
            expect(find.text('XÁC NHẬN ĐẶT CỨU HỘ'), findsOneWidget);
            expect(tester.widget<FilledButton>(footer).onPressed, isNull);
            final quote = find.byKey(const ValueKey('booking-quote-card'));
            await tester.ensureVisible(quote);
            await tester.pumpAndSettle();
            expect(find.text('Chưa có báo giá'), findsOneWidget);
            expect(
                find.byKey(const ValueKey('booking-real-total')), findsNothing);
          }
          expect(find.textContaining('GARAGE'), findsNothing);
          expect(find.textContaining('500.000'), findsNothing);
          expect(find.textContaining('1–3 phút'), findsNothing);
          expect(find.textContaining('1900'), findsNothing);
          expect(tester.takeException(), isNull);
        }
      });
    }
  }

  testWidgets(
      'vehicle selection uses actual saved metadata and original callback',
      (tester) async {
    UserSession.userId = 'owner';
    final controller = AppController()..selectedService = RescueService.tire;
    addTearDown(controller.dispose);
    final repository = vehicles.VehiclesFake()..vehicles = [vehicles.truck];
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
            body: NewRequestScreen(
                controller: controller, vehicleRepository: repository))));
    await tester.pumpAndSettle();
    expect(
        tester
            .widget<ChoiceChip>(find.byKey(const ValueKey('request-step-1')))
            .selected,
        isTrue);
    final card = find.byType(VehicleSelectCard);
    expect(find.ancestor(of: card, matching: find.byType(CustomerCard)),
        findsNothing);
    expect(find.byType(DropdownButtonFormField<VehicleKind>), findsNothing);
    expect(find.text('Phương tiện thủ công'), findsNothing);
    expect(find.text('Tải lại xe đã lưu'), findsNothing);
    await tester.ensureVisible(card);
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(controller.selectedSavedVehicle, same(vehicles.truck));
    expect(tester.widget<VehicleSelectCard>(card).selected, isTrue);
    expect(
        find.byKey(const ValueKey('booking-vehicle-selected')), findsOneWidget);
    expect(find.text('Isuzu QKR'), findsOneWidget);
    expect(find.text('51C-12345'), findsOneWidget);
    expect(find.text('1 xe có sẵn'), findsOneWidget);
    final manual = find.byKey(const ValueKey('booking-manual-vehicle-toggle'));
    await tester.ensureVisible(manual);
    await tester.tap(manual);
    await tester.pumpAndSettle();
    expect(find.byType(DropdownButtonFormField<VehicleKind>), findsOneWidget);
    expect(controller.selectedSavedVehicle, isNull);
    expect(controller.vehicle, VehicleKind.truck);
    final addVehicle = find.text('Thêm phương tiện khác');
    await tester.ensureVisible(addVehicle);
    await tester.pumpAndSettle();
    expect(addVehicle.hitTestable(), findsOneWidget);
    await tester.tap(addVehicle);
    await tester.pumpAndSettle();
    expect(find.byType(CustomerVehiclesScreen), findsOneWidget);
    expect(find.text('Isuzu QKR'), findsOneWidget);
    expect(repository.vehicles, [vehicles.truck]);
    Navigator.of(tester.element(find.byType(CustomerVehiclesScreen))).pop();
    await tester.pumpAndSettle();
    expect(find.byType(NewRequestScreen), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 360.0, 390.0]) {
    for (final scale in [1.0, 1.3]) {
      testWidgets(
          'saved vehicle cards and collapsed manual form at $width / $scale',
          (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        UserSession.userId = 'owner';
        const car = CustomerVehicle(
          id: '11111111-1111-4111-8111-111111111111',
          customerId: 'owner',
          kind: VehicleKind.car,
          brandModel: 'Toyota Corolla Cross',
          licensePlate: '51A-67890',
          color: 'Đen',
        );
        final controller = AppController()
          ..selectedService = RescueService.tire;
        addTearDown(controller.dispose);
        final repository = vehicles.VehiclesFake()
          ..vehicles = [vehicles.truck, car];
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
              body: NewRequestScreen(
                  controller: controller, vehicleRepository: repository)),
        ));
        await tester.pumpAndSettle();
        expect(find.byType(VehicleSelectCard), findsNWidgets(2));
        expect(find.text('2 xe có sẵn'), findsOneWidget);
        expect(find.byType(DropdownButtonFormField<VehicleKind>), findsNothing);
        expect(find.text(car.id), findsNothing);
        expect(find.text('Báo giá sau khi tiếp nhận'), findsOneWidget);
        for (final card in find.byType(VehicleSelectCard).evaluate().toList()) {
          final finder = find.byWidget(card.widget);
          await tester.ensureVisible(finder);
          await tester.pumpAndSettle();
          final rect = tester.getRect(finder);
          expect(rect.left, greaterThanOrEqualTo(18));
          expect(rect.right, lessThanOrEqualTo(width - 18));
          expect(find.ancestor(of: finder, matching: find.byType(CustomerCard)),
              findsNothing);
          expect(tester.takeException(), isNull);
        }
        final lastCard = find.byType(VehicleSelectCard).last;
        await tester.tap(lastCard);
        await tester.pumpAndSettle();
        expect(controller.selectedSavedVehicle, same(car));
        expect(find.byKey(const ValueKey('booking-vehicle-selected')),
            findsOneWidget);
        final manual =
            find.byKey(const ValueKey('booking-manual-vehicle-toggle'));
        await tester.ensureVisible(manual);
        await tester.tap(manual);
        await tester.pumpAndSettle();
        expect(
            find.byType(DropdownButtonFormField<VehicleKind>), findsOneWidget);
        expect(controller.selectedSavedVehicle, isNull);
        expect(controller.vehicle, VehicleKind.car);
        final dropdown = find.byType(DropdownButtonFormField<VehicleKind>);
        await tester.ensureVisible(dropdown);
        await tester.pumpAndSettle();
        final refresh = find.byKey(const ValueKey('booking-vehicles-refresh'));
        await tester.ensureVisible(refresh);
        await tester.pumpAndSettle();
        expect(refresh.hitTestable(), findsOneWidget);
        await tester.tap(refresh);
        await tester.pumpAndSettle();
        expect(find.byType(VehicleSelectCard), findsNWidgets(2));
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets(
      'quote shows only supplied amounts, including zero, and hides UUID codes',
      (tester) async {
    for (final amount in [null, 0, 1250000]) {
      for (final code in [
        'BG-000018',
        '11111111-1111-4111-8111-111111111111'
      ]) {
        final request = RescueRequestData(
            id: 'private-id',
            requestCode: 'CH-000042',
            service: RescueService.tire,
            vehicle: VehicleKind.car,
            address: 'Địa chỉ thật',
            createdAt: DateTime(2026),
            stage: RequestStage.searching,
            price: amount,
            quoteCode: code);
        await tester.pumpWidget(MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(body: BookingQuoteCard(request: request))));
        expect(find.text('Chưa có báo giá'),
            amount == null ? findsOneWidget : findsNothing);
        expect(find.byKey(const ValueKey('booking-real-total')),
            amount == null ? findsNothing : findsOneWidget);
        if (amount != null)
          expect(
              find.text(amount == 0 ? '0 đ' : '1.250.000 đ'), findsOneWidget);
        expect(
            find.text('BG-000018'),
            amount != null && code == 'BG-000018'
                ? findsOneWidget
                : findsNothing);
        expect(find.text('11111111-1111-4111-8111-111111111111'), findsNothing);
        expect(find.textContaining('Miễn phí'), findsNothing);
        expect(tester.takeException(), isNull);
      }
    }
  });

  testWidgets('pickup has one real point, GPS badge only with real coordinates',
      (tester) async {
    for (final point in [null, const RescueCoordinates(10.7, 106.7)]) {
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          home: Scaffold(
              body: BookingPickupPoint(
                  address: '75 Điện Biên Phủ', coordinates: point))));
      expect(find.text('75 Điện Biên Phủ'), findsOneWidget);
      expect(find.text('Tọa độ đã chọn'),
          point == null ? findsNothing : findsOneWidget);
      expect(find.byIcon(Icons.flag_outlined), findsNothing);
      expect(find.textContaining('GARAGE'), findsNothing);
      expect(find.textContaining('km'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
}
