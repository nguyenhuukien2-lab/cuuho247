import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuer/app/app_theme.dart';
import 'package:rescuer/app/mobile_ui.dart';
import 'package:rescuer/app/rescuer_controller.dart';
import 'package:rescuer/models/backend_models.dart';
import 'package:rescuer/screens/preparation/account_overview.dart';
import 'package:rescuer/screens/preparation/history_panel.dart';
import 'package:rescuer/screens/preparation/new_request_preview.dart';
import 'package:rescuer/screens/preparation/partner_accordion.dart';
import 'package:rescuer/screens/preparation/preparation_components.dart';
import 'package:rescuer/screens/preparation/preparation_forms.dart';
import 'package:rescuer/screens/preparation/preparation_screen.dart';
import 'package:rescuer/screens/preparation/ui_v2_components.dart';
import 'package:rescuer/widgets/app_components.dart';

import 'connected_app_test.dart'
    show FakeService, FakeLocation, approved, mount;
import 'active_job_ui_test.dart'
    show ActiveUiFake, mountPanel, expectNoFakeData;

const manualRequest = AvailableRequest(
  id: '11111111-1111-4111-8111-111111111111',
  requestCode: 'CH-000019',
  service: 'tire',
  vehicle: 'car',
  latitude: null,
  longitude: null,
  distanceKm: null,
);
const gpsRequest = AvailableRequest(
  id: '22222222-2222-4222-8222-222222222222',
  requestCode: 'CH-000020',
  service: 'tire',
  vehicle: 'car',
  latitude: 10.775,
  longitude: 106.695,
  distanceKm: 2,
);

RescuerSnapshot operatingProfile() {
  final base = approved();
  return RescuerSnapshot(
    readiness: base.readiness,
    profile: {...base.profile!, 'rescuer_code': 'DT-000042'},
    vehicles: base.vehicles,
    services: base.services,
    capabilities: [
      {...base.capabilities.first, 'service_code': 'tire'},
    ],
  );
}

Future<void> reveal(
  WidgetTester tester,
  Finder target, {
  double delta = 180,
}) async {
  await tester.scrollUntilVisible(
    target,
    delta,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

Future<void> navTo(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}

void expectNoUuid() => expect(
  find.textContaining(
    RegExp(
      r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
      caseSensitive: false,
    ),
  ),
  findsNothing,
);

void main() {
  testWidgets('manual labels and horizontal chips stay readable at 320px', (
    tester,
  ) async {
    final base = operatingProfile();
    final s = FakeService()
      ..userId = 'rescuer'
      ..snapshot = RescuerSnapshot(
        profile: base.profile,
        readiness: base.readiness,
        vehicles: base.vehicles,
        services: base.services,
        capabilities: [
          for (final code in ['tire', 'battery', 'towing', 'fuel', 'other'])
            {...base.capabilities.first, 'service_code': code},
        ],
      )
      ..page = const RequestPage([manualRequest, gpsRequest], null);
    final c = RescuerController(s, FakeLocation());
    addTearDown(() => s.changes.close());
    await mount(tester, c);
    tester.view.physicalSize = const Size(320, 740);
    tester.platformDispatcher.textScaleFactorTestValue = 1.8;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpAndSettle();
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).destinations,
      hasLength(5),
    );
    final services = find.byKey(const ValueKey('work-services'));
    await reveal(tester, services);
    final serviceScroll = tester.widget<SingleChildScrollView>(services);
    expect(serviceScroll.scrollDirection, Axis.horizontal);
    final badges = find.descendant(
      of: services,
      matching: find.byType(StatusBadge),
    );
    expect(badges, findsNWidgets(3));
    final badgeRects = [
      for (final e in badges.evaluate())
        tester.getRect(find.byWidget(e.widget)),
    ];
    expect(badgeRects.map((r) => r.center.dy).toSet(), hasLength(1));
    await tester.drag(services, const Offset(-600, 0));
    await tester.pumpAndSettle();
    expect(find.text('+3 dịch vụ').hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    await c.setOnline(true);
    await navTo(tester, 'Đơn mới');
    final filters = find.byKey(const ValueKey('new-orders-filters'));
    await reveal(tester, filters);
    expect(
      tester.widget<SingleChildScrollView>(filters).scrollDirection,
      Axis.horizontal,
    );
    for (final key in [
      'filter-all',
      'filter-towing',
      'filter-battery_tire',
      'filter-other',
    ]) {
      final chip = find.byKey(ValueKey(key));
      final chipRect = tester.getRect(chip);
      final viewport = tester.getRect(filters);
      expect(chipRect.top, greaterThan(viewport.top));
      expect(chipRect.bottom, lessThan(viewport.bottom));
    }
    await tester.drag(filters, const Offset(-800, 0));
    await tester.pumpAndSettle();
    final other = find.byKey(const ValueKey('filter-other'));
    expect(other.hitTestable(), findsOneWidget);
    final before = s.calls.length;
    await tester.tap(other);
    await tester.pumpAndSettle();
    expect(find.byType(NewRequestCard), findsNothing);
    expect(s.calls.length, before);
    await tester.drag(filters, const Offset(800, 0));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('filter-all')));
    await tester.pumpAndSettle();
    final preview = find.byKey(ValueKey('preview-${manualRequest.id}'));
    await reveal(tester, preview);
    final card = find.ancestor(
      of: preview,
      matching: find.byType(NewRequestCard),
    );
    expect(
      find.descendant(of: card, matching: find.text('Vị trí nhập tay')),
      findsOneWidget,
    );
    expect(find.textContaining('V? tr?'), findsNothing);
    expect(find.textContaining('�'), findsNothing);
    expect(find.text('Chưa có tọa độ GPS'), findsNothing);
    expect(find.textContaining('ETA'), findsNothing);
    expect(find.textContaining('0901234567'), findsNothing);
    expect(find.textContaining('0 km'), findsNothing);
    expectNoUuid();
    final ignore = find.byKey(ValueKey('ignore-${manualRequest.id}'));
    expect(
      tester.getRect(ignore).top,
      greaterThanOrEqualTo(tester.getRect(preview).bottom),
    );
    expect(preview.hitTestable(), findsOneWidget);
    await reveal(tester, ignore);
    expect(ignore.hitTestable(), findsOneWidget);
    await tester.tap(ignore);
    await tester.pumpAndSettle();
    expect(find.byKey(ValueKey('preview-${manualRequest.id}')), findsNothing);
    expect(c.requests, hasLength(2));
    expect(s.calls.length, before);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'compact vehicle row preserves offline selection and locks changes online',
    (tester) async {
      final base = operatingProfile();
      final s = FakeService()
        ..userId = 'rescuer'
        ..snapshot = RescuerSnapshot(
          profile: base.profile,
          readiness: {...base.readiness!, 'eligible_vehicle_ids': ['vehicle', 'vehicle-2']},
          services: base.services,
          vehicles: [
            ...base.vehicles,
            {
              ...base.vehicles.first,
              'id': 'vehicle-2',
              'license_plate': 'TEST02',
              'display_name': 'Xe hỗ trợ 2',
            },
          ],
          capabilities: [
            ...base.capabilities,
            {...base.capabilities.first, 'vehicle_id': 'vehicle-2'},
          ],
        );
      final c = RescuerController(s, FakeLocation());
      addTearDown(() => s.changes.close());
      await mount(tester, c);
      final choose = find.byKey(const ValueKey('dashboard-choose-vehicle'));
      await reveal(tester, choose);
      await tester.tap(choose);
      await tester.pumpAndSettle();
      expect(find.text('Chọn xe đang dùng'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('choose-vehicle-vehicle-2')));
      await tester.pumpAndSettle();
      expect(c.selectedVehicle, 'vehicle-2');
      expect(find.text('TEST02 · Xe hỗ trợ 2'), findsOneWidget);
      expect(s.calls, isEmpty);
      await reveal(tester, find.byKey(const ValueKey('toggle-online')));
      await tester.tap(find.byKey(const ValueKey('toggle-online')));
      await tester.pumpAndSettle();
      expect(c.online, isTrue);
      expect(s.calls.first.$1, 'rescuer_set_online');
      expect(s.calls.first.$2['p_vehicle_id'], 'vehicle-2');
      expect(tester.widget<TextButton>(choose).onPressed, isNull);
      c.selectVehicle('vehicle');
      expect(c.selectedVehicle, 'vehicle-2');
      await reveal(tester, find.byKey(const ValueKey('dashboard-gps')));
      await tester.tap(find.byKey(const ValueKey('dashboard-gps')));
      await tester.pumpAndSettle();
      expect(c.tab, 4);
      expect(c.accountSection, 'gps');
      expect(find.byType(PreparationGps), findsOneWidget);
      expect(find.text('Kiểm tra GPS'), findsOneWidget);
      expectNoUuid();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'busy dashboard keeps its current trip accessible on a small phone with large text',
    (tester) async {
      final s = ActiveUiFake();
      final c = RescuerController(s, FakeLocation());
      addTearDown(() => s.changes.close());
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await mount(tester, c);
      tester.view.physicalSize = const Size(320, 740);
      await navTo(tester, 'Trang chủ');
      await reveal(tester, find.byKey(const ValueKey('toggle-online')));
      expect(find.text('Bật Online'), findsOneWidget);
      final openJob = find.widgetWithText(FilledButton, 'Tiếp tục tác nghiệp');
      await reveal(tester, openJob);
      expect(openJob.hitTestable(), findsOneWidget);
      expect(
        tester.getRect(openJob).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(NavigationBar)).top),
      );
      expect(find.text('Mã đơn: CH-000042'), findsOneWidget);
      expect(c.canClaim, isFalse);
      expect(s.calls, isEmpty);
      await tester.tap(openJob);
      await tester.pumpAndSettle();
      expect(c.tab, 2);
      await reveal(tester, find.byKey(const ValueKey('open-quote')));
      expect(
        find.byKey(const ValueKey('open-quote')).hitTestable(),
        findsOneWidget,
      );
      expect(s.calls, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  testWidgets(
    'dashboard is compact, shows factual counts and keeps requests in their own tab',
    (tester) async {
      final base = operatingProfile();
      final s = FakeService()
        ..userId = 'rescuer'
        ..snapshot = RescuerSnapshot(
          profile: base.profile,
          readiness: base.readiness,
          vehicles: base.vehicles,
          services: base.services,
          capabilities: [
            for (final service in [
              'tire',
              'towing',
              'battery',
              'fuel',
              'other',
            ])
              {...base.capabilities.first, 'service_code': service},
          ],
        )
        ..page = const RequestPage([manualRequest, gpsRequest], null);
      final c = RescuerController(s, FakeLocation());
      addTearDown(() => s.changes.close());
      await mount(tester, c);
      final work = find.byKey(const ValueKey('dashboard-work'));
      expect(tester.getSize(work).width, lessThanOrEqualTo(390));
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.textContaining('Dịch vụ đang bật:'), findsNothing);
      final chips = find.byKey(const ValueKey('work-services'));
      expect(
        find.descendant(of: chips, matching: find.byType(StatusBadge)),
        findsNWidgets(3),
      );
      expect(find.text('+3 dịch vụ'), findsOneWidget);
      final toggle = find.byKey(const ValueKey('toggle-online'));
      final filled = find.descendant(
        of: toggle,
        matching: find.byType(FilledButton),
      );
      expect(
        tester.widget<FilledButton>(filled).style!.backgroundColor!.resolve({}),
        AppColors.orange,
      );
      final gps = find.byKey(const ValueKey('dashboard-gps'));
      expect(
        tester.getRect(gps).top,
        greaterThanOrEqualTo(tester.getRect(toggle).bottom),
      );
      await reveal(tester, filled);
      expect(filled.hitTestable(), findsOneWidget);
      await tester.tap(filled);
      await tester.pumpAndSettle();
      expect(c.online, isTrue);
      expect(c.canClaim, isTrue);
      expect(
        tester
            .widget<Icon>(
              find.descendant(
                of: find.byType(PartnerHeader),
                matching: find.byIcon(Icons.circle),
              ),
            )
            .color,
        AppColors.success,
      );
      expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
      expect(find.text('ĐANG TRỰC TUYẾN'), findsOneWidget);
      expect(find.text('Tạm dừng nhận đơn'), findsOneWidget);
      expect(s.calls.map((call) => call.$1), [
        'rescuer_set_online',
        'rescuer_update_location',
        'rescuer_list_available_requests',
      ]);
      tester.view.physicalSize = const Size(320, 740);
      tester.view.viewPadding = const FakeViewPadding(bottom: 24);
      addTearDown(tester.view.resetViewPadding);
      tester.platformDispatcher.textScaleFactorTestValue = 1.5;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      await reveal(tester, find.byKey(const ValueKey('dashboard-open-orders')));
      final groups =
          (tester.widget<ListView>(find.byType(ListView)).childrenDelegate
                  as SliverChildListDelegate)
              .children;
      expect(
        groups.where((w) => w is PartnerSection || w is PreparationOnline),
        hasLength(3),
      );
      expect(find.byKey(const ValueKey('dashboard-orders')), findsNothing);
      expect(find.byType(NewRequestCard), findsNothing);
      expect(find.byKey(ValueKey('preview-${manualRequest.id}')), findsNothing);
      expectNoUuid();
      final openOrders = find.byKey(const ValueKey('dashboard-open-orders'));
      await reveal(tester, openOrders);
      expect(openOrders.hitTestable(), findsOneWidget);
      expect(
        tester.getRect(openOrders).bottom,
        lessThanOrEqualTo(tester.getRect(find.byType(NavigationBar)).top),
      );
      expect(
        tester
            .widget<ListView>(find.byType(ListView))
            .padding!
            .resolve(TextDirection.ltr)
            .bottom,
        greaterThanOrEqualTo(72),
      );
      await tester.tap(openOrders);
      await tester.pumpAndSettle();
      expect(c.tab, 1);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        1,
      );
      await reveal(tester, find.byKey(ValueKey('preview-${manualRequest.id}')));
      expect(find.text('Mã đơn: CH-000019'), findsOneWidget);
      expect(find.text('Vị trí nhập tay'), findsOneWidget);
      expect(find.text('Chưa có tọa độ GPS'), findsNothing);
      await reveal(tester, find.text('2 km'));
      expect(find.text('2 km'), findsOneWidget);
      expect(find.textContaining('0 km'), findsNothing);
      expectNoUuid();
      final calls = s.calls.length;
      await reveal(
        tester,
        find.byKey(ValueKey('preview-${manualRequest.id}')),
        delta: -180,
      );
      await tester.tap(find.byKey(ValueKey('preview-${manualRequest.id}')));
      await tester.pumpAndSettle();
      expect(find.byType(NewRequestPreview), findsOneWidget);
      expect(find.text('Nhận đơn'), findsOneWidget);
      expect(find.textContaining('0901234567'), findsNothing);
      expectNoUuid();
      await tester.tap(find.text('Để sau'));
      await tester.pumpAndSettle();
      expect(s.calls.length, calls);
      expect(c.tab, 1);
      await navTo(tester, 'Trang chủ');
      await reveal(tester, find.byKey(const ValueKey('toggle-online')));
      await tester.tap(find.byKey(const ValueKey('toggle-online')));
      await tester.pumpAndSettle();
      expect(c.online, isFalse);
      expect(
        tester
            .widget<Icon>(
              find.descendant(
                of: find.byType(PartnerHeader),
                matching: find.byIcon(Icons.circle),
              ),
            )
            .color,
        RescueColors.secondaryText,
      );
      expect(s.calls.last.$1, 'rescuer_set_online');
      expect(s.calls.last.$2['p_online'], isFalse);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'summary never presents stale request counts when the feed is unavailable',
    (tester) async {
      final s = FakeService()
        ..userId = 'rescuer'
        ..snapshot = operatingProfile()
        ..page = const RequestPage([manualRequest, gpsRequest], null);
      final c = RescuerController(s, FakeLocation());
      addTearDown(() => s.changes.close());
      await mount(tester, c);
      await c.setOnline(true);
      for (final status in [
        FeedStatus.loading,
        FeedStatus.error,
        FeedStatus.unavailable,
      ]) {
        c.feedStatus = status;
        c.selectTab(0);
        await tester.pumpAndSettle();
        await reveal(
          tester,
          find.byKey(const ValueKey('dashboard-open-orders')),
        );
        expect(find.byKey(const ValueKey('dashboard-orders')), findsNothing);
        expect(find.byKey(const ValueKey('dashboard-current')), findsOneWidget);
        expect(
          find.byKey(const ValueKey('dashboard-open-orders')).hitTestable(),
          findsOneWidget,
        );
        expect(find.text('Có 2 đơn phù hợp'), findsNothing);
        expect(find.byType(NewRequestCard), findsNothing);
        expectNoUuid();
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'account accordions keep identity, editors and GPS controls reachable',
    (tester) async {
      final s = FakeService()
        ..userId = 'rescuer'
        ..snapshot = operatingProfile();
      final c = RescuerController(s, FakeLocation());
      addTearDown(() => s.changes.close());
      await mount(tester, c);
      await navTo(tester, 'Tài khoản');
      expect(find.byType(PartnerAccordion), findsNWidgets(7));
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('DT-000042'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('account-identity')),
          matching: find.text('Đã được duyệt'),
        ),
        findsNWidgets(2),
      );
      expect(find.text('Lịch sử chuyến'), findsNothing);
      const editors = <(String, String, Type)>[
        ('Chỉnh sửa hồ sơ', 'profile', PreparationProfile),
        ('Tải / bổ sung giấy tờ', 'documents', PreparationDocuments),
        ('Thêm / sửa phương tiện', 'vehicles', PreparationVehicles),
        ('Quản lý dịch vụ', 'services', PreparationServices),
        ('Xem trạng thái / gửi xác minh', 'review', PreparationReview),
      ];
      for (final (label, section, type) in editors) {
        final group = section == 'review' ? 'documents' : section;
        final toggle = find.byKey(ValueKey('accordion-$group-toggle'));
        await reveal(tester, toggle);
        await tester.tap(toggle);
        await tester.pumpAndSettle();
        await reveal(tester, find.text(label));
        await tester.tap(find.text(label));
        await tester.pumpAndSettle();
        expect(c.accountSection, section);
        expect(find.byType(type), findsOneWidget);
        expect(find.byType(AccountOverview), findsNothing);
        expectNoUuid();
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(BackButton));
        await tester.pumpAndSettle();
        expect(find.byType(AccountOverview), findsOneWidget);
      }
      final gpsToggle = find.byKey(const ValueKey('accordion-gps-toggle'));
      await reveal(tester, gpsToggle);
      await tester.tap(gpsToggle);
      await tester.pumpAndSettle();
      await reveal(tester, find.text('Kiểm tra GPS'));
      await tester.tap(find.text('Kiểm tra GPS'));
      await tester.pumpAndSettle();
      expect(c.gpsReady, isTrue);
      expect(find.text('Mở Cài đặt quyền vị trí'), findsOneWidget);
      expect(find.text('Mở Cài đặt GPS'), findsOneWidget);
      expect(s.calls, isEmpty);
      await reveal(tester, find.text('Đăng xuất'));
      await tester.tap(find.text('Đăng xuất'));
      await tester.pumpAndSettle();
      expect(find.text('Đăng xuất?'), findsOneWidget);
      await tester.tap(find.text('Ở lại'));
      await tester.pumpAndSettle();
      expect(c.signedIn, isTrue);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'active job has exactly four groups with one order code and distinct quote/actions',
    (tester) async {
      final s = ActiveUiFake();
      final c = RescuerController(s, FakeLocation())..start();
      addTearDown(() => s.changes.close());
      await mountPanel(tester, c, size: const Size(320, 740), scale: 1.5);
      expect(find.byType(PartnerSection), findsNWidgets(4));
      expect(find.byType(AppCard), findsNothing);
      expect(find.text('Mã đơn: CH-000042'), findsOneWidget);
      final actions = find.byKey(const ValueKey('active-job-actions'));
      for (final key in ['open-quote', 'quote-main', 'send-quote']) {
        expect(
          find.descendant(
            of: key == 'open-quote'
                ? actions
                : find.byKey(const ValueKey('active-job-finance')),
            matching: find.byKey(ValueKey(key)),
          ),
          findsOneWidget,
        );
      }
      final button = tester.widget<FilledButton>(
        find.descendant(
          of: find.byKey(const ValueKey('open-quote')),
          matching: find.byType(FilledButton),
        ),
      );
      expect(button.style!.backgroundColor!.resolve({}), AppColors.orange);
      expectNoFakeData();
      expect(s.calls, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'history keeps fees factual and expands details only on request',
    (tester) async {
      final s = ActiveUiFake()
        ..state = 'completed'
        ..quoteId = 'quote'
        ..total = 120000
        ..missingJob = true;
      final c = RescuerController(s, FakeLocation());
      addTearDown(() => s.changes.close());
      await mount(tester, c);
      await navTo(tester, 'Lịch sử');
      expect(find.byType(HistoryPanel), findsOneWidget);
      expect(find.text('Mã đơn: CH-000042'), findsOneWidget);
      expect(find.text('Chi phí đã ghi nhận'), findsOneWidget);
      expect(find.text('120.000 ₫'), findsNWidgets(2));
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('history-assignment')),
          matching: find.text('120.000 ₫'),
        ),
        findsOneWidget,
      );
      expect(find.text('Chi tiết chuyến đã kết thúc'), findsNothing);
      await reveal(tester, find.text('Xem chi tiết chuyến'));
      await tester.tap(find.text('Xem chi tiết chuyến'));
      await tester.pumpAndSettle();
      expect(find.text('Chi tiết chuyến đã kết thúc'), findsOneWidget);
      expect(find.text('Mã báo giá: BG-000018'), findsOneWidget);
      expect(find.textContaining('0901234567'), findsNothing);
      expectNoUuid();
      expect(s.calls, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
