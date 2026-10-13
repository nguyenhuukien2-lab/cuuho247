import 'dart:async';
import 'package:cuu_ho_247/services/location_service.dart';
import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/app/app_theme.dart';
import 'package:cuu_ho_247/app/user_session.dart';
import 'package:cuu_ho_247/screens/new_home_screen.dart';
import 'package:cuu_ho_247/widgets/home_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'request_location_test.dart' as gps;

void main() {
  testWidgets('live GPS stays separate from the chosen rescue address',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
      body: HomeGreetingLocation(
        name: 'Khách hàng',
        selectedAddress: 'Địa chỉ cứu hộ đã chọn thủ công',
        selectedCoordinates: const RescueCoordinates(10.7, 106.7),
        location: LocationResult(LocationStatus.acquired, 'GPS',
            coordinates: const RescueCoordinates(10.8, 106.8),
            accuracy: 9,
            capturedAt: DateTime.now()),
        loading: false,
        onRefresh: () {},
      ),
    )));
    expect(find.text('Địa chỉ cứu hộ đã chọn thủ công'), findsOneWidget);
    expect(find.byTooltip('Vị trí cứu hộ đã chọn'), findsOneWidget);
    expect(find.text('GPS thiết bị: 10.800000, 106.800000'), findsOneWidget);
    expect(find.text('Độ chính xác GPS: 9 m'), findsOneWidget);
    expect(find.text('GPS sẵn sàng'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('active card typography separates badge, title and compact code',
      (tester) async {
    final request = RescueRequestData(
        id: '11111111-1111-4111-8111-111111111111',
        requestCode: 'CH-000022',
        service: RescueService.tire,
        vehicle: VehicleKind.car,
        address: '',
        createdAt: DateTime(2026),
        stage: RequestStage.searching);
    var tracked = 0;
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
            body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: ActiveOrderBanner(
                    request: request, onTrack: () => tracked++)))));
    final badge = find.byKey(const ValueKey('home-active-status'));
    final label = tester.widget<Text>(find.text('ĐANG TÌM ĐỐI TÁC'));
    final title = find.byKey(const ValueKey('home-active-title'));
    final meta = find.byKey(const ValueKey('home-active-request-meta'));
    final badgeWidget = tester.widget<Container>(badge);
    final decoration = badgeWidget.decoration as BoxDecoration;
    expect(decoration.color, const Color(0xFFFEF3C7));
    expect(decoration.borderRadius, BorderRadius.circular(999));
    expect(badgeWidget.padding,
        const EdgeInsets.symmetric(horizontal: 8, vertical: 4));
    expect(tester.getSize(badge).height, inInclusiveRange(20, 22));
    expect(label.style!.fontSize, inInclusiveRange(10, 11));
    expect(label.style!.fontWeight, FontWeight.w700);
    expect(label.style!.color, const Color(0xFFB45309));
    final titleWidget = tester.widget<Text>(title);
    expect(titleWidget.data, 'Vá / thay lốp');
    expect(titleWidget.style!.fontSize, inInclusiveRange(15, 16));
    expect(titleWidget.style!.fontWeight, FontWeight.w700);
    expect(titleWidget.style!.color, const Color(0xFF0B1C30));
    expect(titleWidget.style!.height, 1.15);
    final metaWidget = tester.widget<Text>(meta);
    expect(metaWidget.data, 'CH-000022 • Ô tô');
    expect(metaWidget.style!.fontSize, inInclusiveRange(11, 12));
    expect(metaWidget.style!.fontWeight, FontWeight.w500);
    expect(metaWidget.style!.color, const Color(0xFF64748B));
    expect(tester.getRect(title).top - tester.getRect(badge).bottom,
        closeTo(4, .01));
    expect(tester.getRect(meta).top - tester.getRect(title).bottom,
        closeTo(3, .01));
    expect(find.textContaining('Mã đơn:'), findsNothing);
    expect(find.textContaining('11111111-1111'), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Theo dõi →'));
    expect(tracked, 1);
    expect(tester.takeException(), isNull);
  });

  for (final setting in [(390.0, 1.0), (320.0, 1.8)]) {
    testWidgets(
        'home visual cards and carousel at ${setting.$1}px / ${setting.$2}',
        (tester) async {
      tester.view.physicalSize = Size(setting.$1, 740);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(setting.$2)),
              child: child!),
          home: Scaffold(
              body: SingleChildScrollView(
                  child: Column(children: [
            HomeAppHeader(onAccount: () {}, onRefresh: () {}),
            Padding(
                padding: const EdgeInsets.all(16),
                child: Column(children: [
                  EmergencyHeroCard(onRequest: () {}),
                  HomeServiceGrid(onSelected: (_) {}),
                  const TrustCommitmentCard(),
                  const SafetyTipsCarousel(),
                ])),
          ])))));
      await tester.pumpAndSettle();
      // The support label uses available space, without inventing a hotline.
      expect(find.text('Hỗ trợ'), findsNothing);
      expect(find.text('6 gói'), findsOneWidget);
      expect(find.byType(ServiceCard), findsNWidgets(6));
      final hero = find
          .descendant(
              of: find.byType(EmergencyHeroCard),
              matching: find.byType(Container))
          .first;
      final decoration =
          tester.widget<Container>(hero).decoration as BoxDecoration;
      expect((decoration.gradient! as LinearGradient).colors, [
        const Color(0xFF0037B0),
        const Color(0xFF1D4ED8),
        const Color(0xFF2151DA)
      ]);
      final trustItems = ['Gửi yêu cầu', 'Xem báo giá', 'Theo dõi trạng thái']
          .map((text) => find.byKey(ValueKey('hero-trust-$text')))
          .toList();
      for (final item in trustItems.skip(1)) {
        expect(tester.getSize(item), tester.getSize(trustItems.first));
        expect(
            tester.getCenter(item).dy, tester.getCenter(trustItems.first).dy);
      }
      final panel = find
          .descendant(
              of: find.byKey(const ValueKey('home-trust-panel')),
              matching: find.byType(Container))
          .first;
      expect(
          (tester.widget<Container>(panel).decoration as BoxDecoration).color,
          const Color(0xFFEEF6FF));
      final firstTip = find.text('Bật đèn cảnh báo');
      final lastTip = find.text('Giữ khoảng cách an toàn');
      await tester.ensureVisible(firstTip);
      await tester.pumpAndSettle();
      expect(firstTip.hitTestable(), findsOneWidget);
      expect(lastTip.hitTestable(), findsNothing);
      final carousel = find.descendant(
          of: find.byType(SafetyTipsCarousel),
          matching: find.byType(SingleChildScrollView));
      await tester.drag(carousel, const Offset(-500, 0));
      await tester.pumpAndSettle();
      expect(lastTip.hitTestable(), findsOneWidget);
      expect(find.text('Ghi nhớ khi gặp sự cố'), findsNWidgets(3));
      expect(find.text('Xem tất cả'), findsOneWidget);
      for (final forbidden in [
        '1900',
        '50m',
        '142 xe',
        '99.8%',
        '10–15p',
        '₫',
        '�'
      ]) {
        expect(find.textContaining(forbidden), findsNothing);
      }
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets(
      'header actions align and white hero CTA keeps its callback at 320px',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var accounts = 0, refreshes = 0, requests = 0;
    await tester.pumpWidget(MaterialApp(
      builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.8)),
          child: child!),
      home: Scaffold(
          body: SingleChildScrollView(
              child: Column(children: [
        HomeAppHeader(
            onAccount: () => accounts++, onRefresh: () => refreshes++),
        Padding(
            padding: const EdgeInsets.all(16),
            child: EmergencyHeroCard(onRequest: () => requests++)),
        const TrustCommitmentCard(),
      ]))),
    ));
    await tester.pumpAndSettle();
    final account = find.byTooltip('Mở tài khoản');
    final refresh = find.byTooltip('Tải lại yêu cầu');
    expect((tester.getCenter(account).dy - tester.getCenter(refresh).dy).abs(),
        lessThan(2));
    await tester.tap(account);
    await tester.tap(refresh);
    expect(accounts, 1);
    expect(refreshes, 1);
    final action = find.widgetWithText(FilledButton, 'YÊU CẦU CỨU HỘ NGAY');
    await tester.ensureVisible(action);
    await tester.pumpAndSettle();
    final style = tester.widget<FilledButton>(action).style!;
    expect(style.backgroundColor!.resolve({}), Colors.white);
    expect(style.foregroundColor!.resolve({}), const Color(0xFF1D4ED8));
    expect(
        find.descendant(of: action, matching: find.byType(Icon)), findsNothing);
    expect(find.byKey(const ValueKey('hero-sos-dot')), findsOneWidget);
    expect(find.text('Yêu cầu cứu hộ trực tuyến'), findsOneWidget);
    expect(action.hitTestable(), findsOneWidget);
    await tester.tap(action);
    expect(requests, 1);
    expect(find.text('Gửi yêu cầu'), findsOneWidget);
    expect(find.text('Theo dõi trạng thái'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('home-trust-panel')));
    await tester.pumpAndSettle();
    final panel = find.byKey(const ValueKey('home-trust-panel'));
    final whites = find
        .descendant(of: panel, matching: find.byType(Container))
        .evaluate()
        .where((element) {
      final decoration = (element.widget as Container).decoration;
      return decoration is BoxDecoration && decoration.color == Colors.white;
    });
    expect(whites, hasLength(3));
    expect(find.textContaining('1900'), findsNothing);
    expect(find.textContaining('142 xe'), findsNothing);
    expect(find.textContaining('99.8%'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'home sections and real active code stay usable at 320px with large text',
      (tester) async {
    tester.view.physicalSize = const Size(320, 740);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = AppController()
      ..activeRequest = RescueRequestData(
          id: '11111111-1111-4111-8111-111111111111',
          requestCode: 'CH-000042',
          service: RescueService.tire,
          vehicle: VehicleKind.car,
          address: 'Địa chỉ từ yêu cầu thật',
          createdAt: DateTime(2026),
          stage: RequestStage.accepted);
    addTearDown(controller.dispose);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!),
        home: Scaffold(body: NewHomeScreen(controller: controller))));
    await tester.pumpAndSettle();
    expect(find.text('CH-000042 • Ô tô'), findsOneWidget);
    expect(find.text('Địa chỉ từ yêu cầu thật'), findsOneWidget);
    expect(find.text('Vị trí đã chọn'), findsOneWidget);
    final children = (tester
            .widget<ListView>(find.byType(ListView))
            .childrenDelegate as SliverChildListDelegate)
        .children;
    expect(children.indexWhere((widget) => widget is ActiveOrderBanner),
        lessThan(children.indexWhere((widget) => widget is EmergencyHeroCard)));
    expect(find.textContaining('Cập nhật'), findsNothing);
    await tester.ensureVisible(find.text('Theo dõi →'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Theo dõi →'));
    expect(controller.tabIndex, 2);
    for (final title in [
      'Bạn cần cứu hộ khẩn cấp?',
      'Dịch vụ tại chỗ',
      'Cam kết vàng từ Cứu Hộ 24/7',
      'Cẩm nang an toàn khẩn cấp'
    ]) {
      await tester.scrollUntilVisible(find.text(title), 150,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.text(title).hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
    for (final text in [
      'ETA',
      '30 giây',
      '142 xe',
      '99.8%',
      '1900',
      'Thời tiết',
      'Kỹ thuật viên'
    ]) {
      expect(find.textContaining(text), findsNothing);
    }
    expect(
        find.textContaining(RegExp(
            r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
            caseSensitive: false)),
        findsNothing);
    final firstTip = find.text('Bật đèn cảnh báo');
    await tester.ensureVisible(firstTip);
    await tester.pumpAndSettle();
    expect(firstTip.hitTestable(), findsOneWidget);
    await tester.dragFrom(tester.getCenter(firstTip), const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('Giữ khoảng cách an toàn').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  tearDown(UserSession.clear);
  testWidgets(
      'selected address remains while the chip reports real GPS failure',
      (tester) async {
    for (final status in [LocationStatus.denied, LocationStatus.unavailable]) {
      await tester.pumpWidget(MaterialApp(
          home: Scaffold(
              body: HomeGreetingLocation(
                  name: 'Khách hàng',
                  selectedAddress: 'Địa chỉ từ yêu cầu',
                  loading: false,
                  onRefresh: () {},
                  location: LocationResult(
                      status, 'Giải thích dài về quyền vị trí')))));
      expect(find.text('Địa chỉ từ yêu cầu'), findsOneWidget);
      expect(find.text('Chưa chọn vị trí'), findsNothing);
      expect(find.text('GPS sẵn sàng'), findsNothing);
      expect(
          find.text(status == LocationStatus.denied
              ? 'Chưa cấp quyền vị trí'
              : 'Không thể lấy vị trí'),
          findsOneWidget);
      expect(find.byKey(const ValueKey('home-greeting-location-badge')),
          findsOneWidget);
      expect(find.text('Giải thích dài về quyền vị trí'), findsNothing);
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('active banner searching copy follows the real request stage',
      (tester) async {
    var tracked = 0;
    final request = RescueRequestData(
        id: '11111111-1111-4111-8111-111111111111',
        requestCode: 'CH-000042',
        service: RescueService.tire,
        vehicle: VehicleKind.car,
        address: 'Địa chỉ thật',
        createdAt: DateTime(2026),
        stage: RequestStage.searching);
    Future<void> mount() => tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ActiveOrderBanner(
                request: request, onTrack: () => tracked++))));
    await mount();
    expect(find.textContaining('Hệ thống đang tìm đối tác phù hợp'),
        findsOneWidget);
    expect(find.text('ĐANG TÌM ĐỐI TÁC'), findsOneWidget);
    expect(tester.getRect(find.text('ĐANG TÌM ĐỐI TÁC')).bottom,
        lessThan(tester.getRect(find.text('Vá / thay lốp')).top));
    expect(tester.getRect(find.text('Vá / thay lốp')).bottom,
        lessThan(tester.getRect(find.text('CH-000042 • Ô tô')).top));
    expect(find.textContaining('Mã đơn:'), findsNothing);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.textContaining('Cập nhật'), findsNothing);
    await tester.tap(find.text('Theo dõi →'));
    expect(tracked, 1);
    request.stage = RequestStage.accepted;
    await mount();
    expect(
        find.textContaining('Hệ thống đang tìm đối tác phù hợp'), findsNothing);
    expect(find.textContaining('Đối tác đã tiếp nhận yêu cầu'), findsOneWidget);
    expect(find.textContaining('11111111-1111'), findsNothing);
    expect(find.textContaining('ETA'), findsNothing);
    expect(tester.takeException(), isNull);
  });
  testWidgets(
      'GPS refresh preserves retry without long permission text on home',
      (tester) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    final location = gps.FakeLocationService();
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
            body: NewHomeScreen(
                controller: controller, locationService: location))));
    expect(find.text('Chưa chọn vị trí'), findsNWidgets(2));
    expect(location.calls, 0);
    await tester.tap(find.byTooltip('Làm mới vị trí'));
    await tester.pump();
    expect(location.calls, 1);
    location.pending.complete(
        const LocationResult(LocationStatus.denied, 'Quyền vị trí bị từ chối'));
    await tester.pumpAndSettle();
    expect(find.text('Quyền vị trí bị từ chối'), findsNothing);
    expect(find.text('GPS sẵn sàng'), findsNothing);
    expect(find.byTooltip('Làm mới vị trí').hitTestable(), findsOneWidget);
    location.pending = Completer<LocationResult>();
    await tester.tap(find.byTooltip('Làm mới vị trí'));
    location.pending.complete(gps.located);
    await tester.pumpAndSettle();
    expect(find.text('10.776900, 106.700900'), findsOneWidget);
    expect(find.text('GPS sẵn sàng'), findsOneWidget);
    expect(find.textContaining('chính xác'), findsNothing);
  });
  testWidgets('home exposes active order only while nonterminal',
      (tester) async {
    final controller = AppController();
    addTearDown(controller.dispose);
    Future<void> mount() => tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: NewHomeScreen(controller: controller))));
    await mount();
    expect(find.byType(ActiveOrderBanner), findsNothing);
    controller.activeRequest = RescueRequestData(
        id: 'real-order',
        service: RescueService.tire,
        vehicle: VehicleKind.car,
        address: 'Địa chỉ từ đơn',
        createdAt: DateTime(2026),
        stage: RequestStage.searching);
    await mount();
    expect(find.byType(ActiveOrderBanner), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Theo dõi →'), findsOneWidget);
    expect(find.text('Theo dõi đơn'), findsNothing);
    final disabled = find.widgetWithText(FilledButton, 'YÊU CẦU ĐANG XỬ LÝ');
    expect(tester.widget<FilledButton>(disabled).onPressed, isNull);
    await tester.ensureVisible(find.text('Theo dõi →'));
    await tester.pumpAndSettle();
    expect(find.text('Theo dõi →').hitTestable(), findsOneWidget);
    await tester.tap(find.text('Theo dõi →'));
    expect(controller.tabIndex, 2);
    for (final stage in [RequestStage.completed, RequestStage.cancelled]) {
      controller.activeRequest!.stage = stage;
      await mount();
      expect(find.byType(ActiveOrderBanner), findsNothing);
      expect(find.text('YÊU CẦU ĐANG XỬ LÝ'), findsNothing);
      expect(
          tester
              .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'YÊU CẦU CỨU HỘ NGAY'))
              .onPressed,
          isNotNull);
    }
  });
  testWidgets('service cards forward supported codes and preserve fallback',
      (tester) async {
    RescueService? selection;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: SingleChildScrollView(
                child: HomeServiceGrid(
                    onSelected: (service) => selection = service)))));
    expect(find.byType(ServiceCard), findsNWidgets(6));
    expect(find.text('6 gói'), findsOneWidget);
    for (final tag in ['Xem chi tiết', 'Tùy tình huống', 'Theo yêu cầu']) {
      expect(find.text(tag), findsNWidgets(2));
    }
    expect(HomeServiceGrid.services.map((service) => service.$4).toSet(),
        hasLength(6));
    expect(find.text('Cẩu & Kéo xe'), findsOneWidget);
    expect(find.text('Sửa tại chỗ'), findsOneWidget);
    final first =
        tester.getSize(find.widgetWithText(ServiceCard, 'Cẩu & Kéo xe'));
    final second =
        tester.getSize(find.widgetWithText(ServiceCard, 'Kích bình ắc quy'));
    expect(first, second);
    for (final service in HomeServiceGrid.services) {
      final card = find.widgetWithText(ServiceCard, service.$1);
      await tester.ensureVisible(card);
      await tester.tap(card);
      expect(selection, service.$5);
    }
  });
  testWidgets('active banner renders only a real server update time',
      (tester) async {
    final request = RescueRequestData(
        id: '11111111-1111-4111-8111-111111111111',
        requestCode: 'CH-000042',
        service: RescueService.other,
        vehicle: VehicleKind.car,
        address: '',
        createdAt: DateTime(2026, 10, 6),
        updatedAt: DateTime(2026, 10, 6, 9, 10),
        stage: RequestStage.accepted);
    var tracked = 0;
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(
            body: ActiveOrderBanner(
                request: request, onTrack: () => tracked++))));
    expect(find.text('Cập nhật: 09:10'), findsOneWidget);
    expect(find.byTooltip('06/10/2026 • 09:10'), findsOneWidget);
    final container = find
        .descendant(
            of: find.byType(ActiveOrderBanner),
            matching: find.byType(Container))
        .first;
    final decoration =
        tester.widget<Container>(container).decoration as BoxDecoration;
    expect((decoration.gradient as LinearGradient).colors,
        [const Color(0xFFDCEEFF), const Color(0xFFDDFBEF)]);
    expect(decoration.borderRadius, BorderRadius.circular(20));
    expect(decoration.boxShadow, isNotEmpty);
    await tester.tap(find.text('Theo dõi →'));
    expect(tracked, 1);
    final cardRect = tester.getRect(find.byType(ActiveOrderBanner));
    final buttonRect =
        tester.getRect(find.widgetWithText(FilledButton, 'Theo dõi →'));
    expect(cardRect.right - buttonRect.right, greaterThanOrEqualTo(14));
    expect(cardRect.bottom - buttonRect.bottom, greaterThanOrEqualTo(12));
    final footer =
        tester.getRect(find.byKey(const ValueKey('home-active-footer')));
    expect(footer.contains(buttonRect.topLeft), isTrue);
    expect(footer.contains(buttonRect.bottomRight), isTrue);
    expect(
        tester
            .getRect(find.textContaining('Đối tác đã tiếp nhận yêu cầu'))
            .overlaps(buttonRect),
        isFalse);
    final button = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Theo dõi →'));
    expect(button.style!.backgroundColor!.resolve({}), const Color(0xFF0B4EDB));
    expect(buttonRect.height, inInclusiveRange(30, 34));
    expect(find.textContaining('11111111-1111'), findsNothing);
  });
}
