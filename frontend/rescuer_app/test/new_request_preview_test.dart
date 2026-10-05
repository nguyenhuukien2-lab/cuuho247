import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuer/app/app_theme.dart';
import 'package:rescuer/app/rescuer_controller.dart';
import 'package:rescuer/models/backend_models.dart';
import 'package:rescuer/screens/preparation/new_request_preview.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'claim_request_test.dart' show ClaimFake, request;
import 'connected_app_test.dart' show FakeLocation, mount;

const previewRequest = AvailableRequest(
  id: '11111111-1111-4111-8111-111111111111',
  requestCode: 'CH-000123',
  service: 'towing',
  vehicle: 'truck',
  latitude: 10.775,
  longitude: 106.695,
  distanceKm: 3,
);

void expectPrivateDataHidden() {
  for (final text in [
    'Khách sau nhận',
    '0901234567',
    'Điểm cứu hộ chính xác',
    'Lốp xe bị thủng',
    '10.771234',
    '106.691234',
    'ETA',
  ]) {
    expect(find.textContaining(text), findsNothing);
  }
  expect(
    find.textContaining(
      RegExp(
        r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
        caseSensitive: false,
      ),
    ),
    findsNothing,
  );
}

Future<void> openPreview(
  WidgetTester tester,
  RescuerController c,
  String id,
) async {
  if (c.tab != 1) c.selectTab(1);
  await tester.pumpAndSettle();
  final action = find.byKey(ValueKey('preview-$id'));
  await tester.scrollUntilVisible(
    action,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
  await tester.tap(action);
  await tester.pumpAndSettle();
}

void main() {
  for (final size in [const Size(320, 740), const Size(390, 844)]) {
    testWidgets('card and preview are readable at $size with large text', (
      tester,
    ) async {
      final service = ClaimFake()
        ..page = const RequestPage([previewRequest], null);
      final c = RescuerController(service, FakeLocation())
        ..userId = 'rescuer'
        ..snapshot = service.snapshot
        ..selectedVehicle = 'vehicle'
        ..online = true
        ..locationReady = true
        ..jobStatus = JobStatus.empty
        ..loading = false
        ..requests = [previewRequest];
      addTearDown(c.dispose);
      addTearDown(() => service.changes.close());
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: Scaffold(
            body: SingleChildScrollView(
              child: NewRequestCard(
                request: previewRequest,
                onPreview: () {},
                onIgnore: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Mã đơn: CH-000123'), findsOneWidget);
      expect(find.text('Kéo xe'), findsOneWidget);
      expect(find.text('Loại xe: Xe tải'), findsOneWidget);
      expect(find.text('Yêu cầu mới'), findsOneWidget);
      expect(find.text('Khu vực cứu hộ gần đúng'), findsOneWidget);
      expect(find.text('Khoảng cách ước tính · 3 km'), findsOneWidget);
      expect(find.text('Xem trước'), findsOneWidget);
      expect(find.text('Nhận đơn'), findsNothing);
      expect(find.textContaining('10.775'), findsNothing);
      expect(find.textContaining('106.695'), findsNothing);
      expectPrivateDataHidden();
      expect(tester.takeException(), isNull);

      // Render the sheet through a real modal route and keep its actions visible.
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: const TextScaler.linear(1.8)),
            child: child!,
          ),
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  builder: (_) =>
                      NewRequestPreview(controller: c, request: previewRequest),
                ),
                child: const Text('Mở xem trước'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Mở xem trước'));
      await tester.pumpAndSettle();
      expect(find.text('Mã đơn: CH-000123'), findsOneWidget);
      expect(find.text('Kéo xe'), findsOneWidget);
      expect(find.text('Loại xe: Xe tải'), findsOneWidget);
      expect(find.text('Quyền riêng tư của khách hàng'), findsOneWidget);
      expect(find.textContaining('10.775'), findsNothing);
      final accept = find.widgetWithText(FilledButton, 'Nhận đơn');
      expect(tester.widget<FilledButton>(accept).onPressed, isNotNull);
      expect(tester.getRect(accept).bottom, lessThanOrEqualTo(size.height));
      final coordinates = find.text('Xem tọa độ khu vực');
      await tester.ensureVisible(coordinates);
      await tester.tap(coordinates);
      await tester.pumpAndSettle();
      expect(find.text('10.775, 106.695'), findsOneWidget);
      expectPrivateDataHidden();
      expect(
        service.calls.where((call) => call.$1 == 'rescuer_claim_request'),
        isEmpty,
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Để sau'));
      await tester.pumpAndSettle();
      expect(find.byType(NewRequestPreview), findsNothing);
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets(
    'defer closes preview without changing the feed or calling claim',
    (tester) async {
      final service = ClaimFake();
      final c = RescuerController(service, FakeLocation());
      addTearDown(() => service.changes.close());
      await mount(tester, c);
      await c.setOnline(true);
      c.selectTab(1);
      await tester.pumpAndSettle();
      final before = service.calls.length;
      await openPreview(tester, c, request.id);
      expectPrivateDataHidden();
      await tester.tap(find.text('Để sau'));
      await tester.pumpAndSettle();
      expect(find.byType(NewRequestPreview), findsNothing);
      expect(c.requests.single.id, request.id);
      expect(service.calls.length, before);
      expect(c.tab, 1);
      expect(c.claimSuccessSerial, 0);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'request disappearing during preview disables claim and explains why',
    (tester) async {
      final service = ClaimFake();
      final c = RescuerController(service, FakeLocation());
      addTearDown(() => service.changes.close());
      await mount(tester, c);
      await c.setOnline(true);
      await openPreview(tester, c, request.id);
      service.page = const RequestPage([], null);
      await c.refreshRequests();
      await tester.pumpAndSettle();
      final action = find.widgetWithText(FilledButton, 'Nhận đơn');
      expect(tester.widget<FilledButton>(action).onPressed, isNull);
      expect(
        find.text(
          'Yêu cầu không còn trong danh sách đơn mới. Đóng xem trước và tải lại.',
        ),
        findsOneWidget,
      );
      expect(
        service.calls.where((call) => call.$1 == 'rescuer_claim_request'),
        isEmpty,
      );
      expectPrivateDataHidden();
      await tester.tap(find.text('Để sau'));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('GPS becoming unavailable while preview is open disables claim', (
    tester,
  ) async {
    final service = ClaimFake();
    final c = RescuerController(service, FakeLocation());
    addTearDown(() => service.changes.close());
    await mount(tester, c);
    await c.setOnline(true);
    await openPreview(tester, c, request.id);
    c.locationReady = false;
    c.selectTab(0);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Nhận đơn'))
          .onPressed,
      isNull,
    );
    expect(
      find.text(
        'Kiểm tra online, GPS và chuyến đang xử lý trước khi nhận đơn.',
      ),
      findsOneWidget,
    );
    expect(
      service.calls.where((call) => call.$1 == 'rescuer_claim_request'),
      isEmpty,
    );
    expectPrivateDataHidden();
    await tester.tap(find.text('Để sau'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'failed claim stays in preview with real error and allows closing',
    (tester) async {
      final service = ClaimFake();
      final c = RescuerController(service, FakeLocation());
      addTearDown(() => service.changes.close());
      await mount(tester, c);
      await c.setOnline(true);
      await openPreview(tester, c, request.id);
      service.failedMutation = 'rescuer_claim_request';
      service.mutationFailure = const PostgrestException(
        message: 'REQUEST_UNAVAILABLE',
        code: 'P0001',
      );
      service.page = const RequestPage([], null);
      await tester.tap(find.text('Nhận đơn'));
      await tester.pumpAndSettle();
      expect(find.byType(NewRequestPreview), findsOneWidget);
      expect(find.text('Chưa nhận được đơn'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(NewRequestPreview),
          matching: find.textContaining('Đơn đã có người nhận'),
        ),
        findsOneWidget,
      );
      expect(
        service.calls
            .where((call) => call.$1 == 'rescuer_claim_request')
            .length,
        1,
      );
      expect(c.claimSuccessSerial, 0);
      expectPrivateDataHidden();
      await tester.tap(find.text('Để sau'));
      await tester.pumpAndSettle();
      expect(find.byType(NewRequestPreview), findsNothing);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'missing public code never displays UUID and distances are never fabricated',
    (tester) async {
      for (final distance in [-1, 0, 2]) {
        final r = AvailableRequest(
          id: previewRequest.id,
          requestCode: previewRequest.id,
          service: 'battery',
          vehicle: 'motorbike',
          latitude: 10.775,
          longitude: 106.695,
          distanceKm: distance,
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.light,
            home: Scaffold(
              body: SingleChildScrollView(
                child: NewRequestCard(
                  request: r,
                  onPreview: () {},
                  onIgnore: () {},
                ),
              ),
            ),
          ),
        );
        expect(find.text('Mã đơn: Chưa có mã'), findsOneWidget);
        expect(find.text('Kích bình'), findsOneWidget);
        expect(find.text('Loại xe: Xe máy'), findsOneWidget);
        if (distance < 0) {
          expect(find.text('Chưa có khoảng cách ước tính'), findsNothing);
          expect(find.textContaining(' km'), findsNothing);
        } else {
          expect(
            find.text('Khoảng cách ước tính · $distance km'),
            findsOneWidget,
          );
        }
        expectPrivateDataHidden();
        expect(tester.takeException(), isNull);
      }
    },
  );
}
