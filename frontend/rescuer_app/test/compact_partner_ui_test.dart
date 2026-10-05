import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuer/app/app_theme.dart';
import 'package:rescuer/app/rescuer_controller.dart';
import 'package:rescuer/models/backend_models.dart';
import 'package:rescuer/screens/preparation/account_overview.dart';
import 'package:rescuer/screens/preparation/history_panel.dart';
import 'package:rescuer/screens/preparation/new_request_preview.dart';
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
    profile: {...base.profile!, 'rescuer_code': 'DT-000042'},
    vehicles: base.vehicles,
    services: base.services,
    capabilities: [
      {...base.capabilities.first, 'service_code': 'tire'},
    ],
  );
}

Future<void> reveal(WidgetTester tester, Finder target) async {
  await tester.scrollUntilVisible(
    target,
    180,
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
  testWidgets(
    'compact vehicle row preserves offline selection and locks changes online',
    (tester) async {
      final base = operatingProfile();
      final s = FakeService()
        ..userId = 'rescuer'
        ..snapshot = RescuerSnapshot(
          profile: base.profile,
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
      await tester.tap(choose);
      await tester.pumpAndSettle();
      expect(find.text('Chọn xe đang dùng'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('choose-vehicle-vehicle-2')));
      await tester.pumpAndSettle();
      expect(c.selectedVehicle, 'vehicle-2');
      expect(find.text('TEST02 · Xe hỗ trợ 2'), findsOneWidget);
      expect(s.calls, isEmpty);
      await tester.tap(find.byKey(const ValueKey('toggle-online')));
      await tester.pumpAndSettle();
      expect(c.online, isTrue);
      expect(s.calls.first.$1, 'rescuer_set_online');
      expect(s.calls.first.$2['p_vehicle_id'], 'vehicle-2');
      expect(tester.widget<TextButton>(choose).onPressed, isNull);
      c.selectVehicle('vehicle');
      expect(c.selectedVehicle, 'vehicle-2');
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
      expect(find.text('Bật Online'), findsOneWidget);
      final openJob = find.widgetWithText(FilledButton, 'Mở chuyến');
      await reveal(tester, openJob);
      expect(openJob.hitTestable(), findsOneWidget);
      expect(tester.getRect(openJob).bottom, lessThan(660));
      expect(find.text('Mã đơn: CH-000042'), findsOneWidget);
      expect(c.canClaim, isFalse);
      expect(s.calls, isEmpty);
      await tester.tap(openJob);
      await tester.pumpAndSettle();
      expect(c.tab, 2);
      expect(find.byKey(const ValueKey('open-quote')), findsOneWidget);
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
      expect(tester.getSize(work).height, lessThanOrEqualTo(350));
      expect(find.byType(SwitchListTile), findsNothing);
      expect(find.textContaining('Dịch vụ đang bật:'), findsNothing);
      final chips = find.byKey(const ValueKey('work-services'));
      expect(
        find.descendant(of: chips, matching: find.byType(StatusBadge)),
        findsNWidgets(3),
      );
      expect(find.text('+3'), findsOneWidget);
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
        (tester.getCenter(gps).dy - tester.getCenter(toggle).dy).abs(),
        lessThan(2),
      );
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
      expect(
        tester
            .widget<StatusBadge>(
              find.byKey(const ValueKey('work-online-status')),
            )
            .tone,
        BadgeTone.green,
      );
      expect(find.text('Tắt Online'), findsOneWidget);
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
      expect(find.text('Có 2 đơn phù hợp'), findsOneWidget);
      expect(find.byType(NewRequestCard), findsNothing);
      expect(find.byKey(ValueKey('preview-${manualRequest.id}')), findsNothing);
      expectNoUuid();
      final position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      position.jumpTo(position.maxScrollExtent);
      await tester.pumpAndSettle();
      final openOrders = find.byKey(const ValueKey('dashboard-open-orders'));
      expect(openOrders.hitTestable(), findsOneWidget);
      expect(
        tester.getRect(openOrders).bottom,
        lessThan(tester.getRect(find.byType(NavigationBar)).top - 20),
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
      expect(find.text('Chưa có tọa độ GPS'), findsOneWidget);
      expect(find.text('Khoảng cách ước tính · 2 km'), findsOneWidget);
      expect(find.textContaining('0 km'), findsNothing);
      expectNoUuid();
      final calls = s.calls.length;
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
        AppColors.warning,
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
      for (final (status, text) in [
        (FeedStatus.loading, 'Đang tìm đơn phù hợp'),
        (FeedStatus.error, 'Chưa tải được đơn mới'),
        (FeedStatus.unavailable, 'Mở Đơn mới để kiểm tra điều kiện.'),
      ]) {
        c.feedStatus = status;
        c.selectTab(0);
        await tester.pumpAndSettle();
        await reveal(
          tester,
          find.byKey(const ValueKey('dashboard-open-orders')),
        );
        expect(find.text(text), findsOneWidget);
        expect(find.text('Có 2 đơn phù hợp'), findsNothing);
        expect(find.byType(NewRequestCard), findsNothing);
        expectNoUuid();
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'account has three groups, one DT code and all six editors remain reachable without chips',
    (tester) async {
      final s = FakeService()
        ..userId = 'rescuer'
        ..snapshot = operatingProfile();
      final c = RescuerController(s, FakeLocation());
      addTearDown(() => s.changes.close());
      await mount(tester, c);
      await navTo(tester, 'Tài khoản');
      expect(find.byType(PartnerSection), findsNWidgets(3));
      expect(find.byType(ChoiceChip), findsNothing);
      expect(find.text('Mã đối tác: DT-000042'), findsOneWidget);
      expect(find.text('Đã được duyệt'), findsOneWidget);
      expect(find.text('Lịch sử chuyến'), findsNothing);
      const editors = <(String, String, Type)>[
        ('Thông tin cá nhân', 'profile', PreparationProfile),
        ('Hồ sơ xác minh', 'documents', PreparationDocuments),
        ('Xe của tôi', 'vehicles', PreparationVehicles),
        ('Dịch vụ cứu hộ', 'services', PreparationServices),
        ('Trạng thái duyệt', 'review', PreparationReview),
        ('GPS & quyền vị trí', 'gps', PreparationGps),
      ];
      for (final (label, section, type) in editors) {
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
    'active job has exactly three groups with one order code and grouped quote/actions',
    (tester) async {
      final s = ActiveUiFake();
      final c = RescuerController(s, FakeLocation())..start();
      addTearDown(() => s.changes.close());
      await mountPanel(tester, c, size: const Size(320, 740), scale: 1.5);
      expect(find.byType(PartnerSection), findsNWidgets(3));
      expect(find.byType(AppCard), findsNothing);
      expect(find.text('Mã đơn: CH-000042'), findsOneWidget);
      final actions = find.byKey(const ValueKey('active-job-header'));
      for (final key in ['open-quote', 'quote-main', 'send-quote']) {
        expect(
          find.descendant(of: actions, matching: find.byKey(ValueKey(key))),
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
      expect(find.text('120.000 ₫'), findsOneWidget);
      expect(find.text('Xem chi tiết chuyến'), findsNothing);
      await reveal(
        tester,
        find.byKey(const ValueKey('expand-history-assignment')),
      );
      await tester.tap(find.byKey(const ValueKey('expand-history-assignment')));
      await tester.pumpAndSettle();
      expect(find.text('Xem chi tiết chuyến'), findsOneWidget);
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
