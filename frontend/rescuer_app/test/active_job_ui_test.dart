import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rescuer/app/app_theme.dart';
import 'package:rescuer/app/mobile_ui.dart';
import 'package:rescuer/app/rescuer_controller.dart';
import 'package:rescuer/models/backend_models.dart';
import 'package:rescuer/screens/preparation/active_job_panel.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'connected_app_test.dart' show FakeLocation;
import 'job_finance_test.dart' show FinanceFake;

const uuid = '11111111-1111-4111-8111-111111111111';

class ActiveUiFake extends FinanceFake {
  String? requestCode = 'CH-000042', quoteCode = 'BG-000018';
  String? phone = '0901234567',
      address = 'Điểm cứu hộ thật',
      note = 'Lốp trước bị thủng';
  bool coordinates = true;
  @override
  Json get data => {
    ...super.data,
    'request_code': requestCode,
    'quote_code': quoteCode,
    'contact_name': null,
    'contact_phone': phone,
    'location_text': address,
    'description': note,
    'latitude': coordinates ? 10.771234 : null,
    'longitude': coordinates ? 106.691234 : null,
  };
}

Future<void> mountPanel(
  WidgetTester tester,
  RescuerController c, {
  Size size = const Size(390, 844),
  double scale = 1,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context)
            .copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: _ActivePanelHost(c: c),
    ),
  );
  await tester.pumpAndSettle();
}

class _ActivePanelHost extends StatefulWidget {
  const _ActivePanelHost({required this.c});
  final RescuerController c;

  @override
  State<_ActivePanelHost> createState() => _ActivePanelHostState();
}

class _ActivePanelHostState extends State<_ActivePanelHost> {
  @override
  void dispose() {
    widget.c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SingleChildScrollView(
      padding: RescueSpace.page,
      child: ListenableBuilder(
        listenable: widget.c,
        builder: (_, _) => ActiveJobPanel(c: widget.c),
      ),
    ),
  );
}

void expectNoFakeData() {
  expect(
    find.textContaining(
      RegExp(
        r'[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}',
        caseSensitive: false,
      ),
    ),
    findsNothing,
  );
  expect(
    find.textContaining(
      RegExp(
        r'\bETA\b|\b\d+(?:[.,]\d+)?\s*(?:km|phút)\b',
        caseSensitive: false,
      ),
    ),
    findsNothing,
  );
  expect(find.text('Chưa có dữ liệu'), findsNothing);
  expect(find.textContaining('Chưa tích hợp bản đồ'), findsNothing);
}

void main() {
  for (final size in [const Size(320, 740), const Size(390, 844)]) {
    testWidgets('primary action stays in header on $size with large text', (
      tester,
    ) async {
      final s = ActiveUiFake()
        ..state = 'accepted'
        ..version = 1;
      final c = RescuerController(s, FakeLocation())..start();
      addTearDown(() => s.changes.close());
      await mountPanel(tester, c, size: size, scale: 1.5);
      const scenarios = [
        ('accepted', 'Đã nhận đơn', 'advance-job', 'Đang đến điểm cứu hộ'),
        ('en_route', 'Đang đến điểm cứu hộ', 'advance-job', 'Đã đến nơi'),
        ('arrived', 'Đã đến nơi', 'advance-job', 'Bắt đầu hỗ trợ'),
        ('in_progress', 'Đang hỗ trợ khách', 'open-quote', 'Tạo báo giá'),
        ('in_progress', 'Đang hỗ trợ khách', 'complete-job', 'Hoàn tất chuyến'),
      ];
      for (var i = 0; i < scenarios.length; i++) {
        final (state, status, key, label) = scenarios[i];
        s.state = state;
        s.version = i + 1;
        s.quoteId = i == 4 ? 'quote' : null;
        s.total = i == 4 ? 0 : null;
        await c.refreshActiveJob();
        await tester.pumpAndSettle();
        tester
            .state<ScrollableState>(find.byType(Scrollable).first)
            .position
            .jumpTo(0);
        await tester.pumpAndSettle();
        final header = find.byKey(const ValueKey('active-job-header'));
        expect(
          find.descendant(of: header, matching: find.text('Mã đơn: CH-000042')),
          findsOneWidget,
        );
        expect(
          find.descendant(of: header, matching: find.text(status)),
          findsOneWidget,
        );
        final action = find.byKey(ValueKey(key));
        expect(action, findsOneWidget);
        expect(find.descendant(of: header, matching: action), findsOneWidget);
        expect(
          find.descendant(of: action, matching: find.text(label)),
          findsOneWidget,
        );
        final button = find.descendant(
          of: action,
          matching: find.byType(FilledButton),
        );
        expect(tester.widget<FilledButton>(button).onPressed, isNotNull);
        expect(tester.getRect(action).bottom, lessThanOrEqualTo(size.height));
        if (i == 4) {
          expect(find.text('Mã báo giá: BG-000018'), findsOneWidget);
          expect(find.text('0 ₫'), findsOneWidget);
          expect(find.byKey(const ValueKey('open-quote')), findsNothing);
        }
        expect(
          s.calls.where(
            (call) =>
                call.$1 == 'rescuer_update_job_status' ||
                call.$1 == 'rescuer_create_quote',
          ),
          isEmpty,
        );
        expectNoFakeData();
        expect(tester.takeException(), isNull);
      }
      await tester.pumpWidget(const SizedBox());
    });
  }

  testWidgets('contact, location and notes come from the active job', (
    tester,
  ) async {
    final s = ActiveUiFake()
      ..state = 'accepted'
      ..version = 1;
    final c = RescuerController(s, FakeLocation())..start();
    addTearDown(() => s.changes.close());
    await mountPanel(tester, c);
    expect(find.text('0901234567'), findsOneWidget);
    expect(find.text('Điểm cứu hộ thật'), findsOneWidget);
    expect(find.text('Lốp trước bị thủng'), findsOneWidget);
    expect(find.text('Vá/thay lốp'), findsOneWidget);
    expect(find.text('Ô tô'), findsOneWidget);
    expect(find.text('Gọi ngay'), findsOneWidget);
    expect(find.text('Mở Google Maps'), findsOneWidget);
    final info = find
        .ancestor(
          of: find.text('Thông tin chuyến'),
          matching: find.byType(Column),
        )
        .first;
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('advance-job'))).dy,
      lessThan(tester.getTopLeft(info).dy),
    );
    expectNoFakeData();
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets(
    'missing contact and coordinates explain unavailable actions without fake data',
    (tester) async {
      final s = ActiveUiFake()
        ..state = 'accepted'
        ..phone = null
        ..address = null
        ..note = null
        ..coordinates = false;
      final c = RescuerController(s, FakeLocation())..start();
      addTearDown(() => s.changes.close());
      await mountPanel(tester, c);
      expect(find.text('Gọi ngay'), findsNothing);
      expect(find.text('Mở Google Maps'), findsNothing);
      expect(find.text('Đơn chưa có số điện thoại liên hệ.'), findsOneWidget);
      expect(
        find.text('Chưa có GPS. Xác nhận điểm cứu hộ với khách.'),
        findsOneWidget,
      );
      expect(find.text('Đơn chưa có địa chỉ cứu hộ.'), findsOneWidget);
      expect(find.text('Khách hàng'), findsNothing);
      expect(find.text('Ghi chú sự cố'), findsNothing);
      expect(find.text('0901234567'), findsNothing);
      expectNoFakeData();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'only server milestone times render and current state is emphasized',
    (tester) async {
      final s = ActiveUiFake()
        ..state = 'en_route'
        ..version = 2;
      final c = RescuerController(s, FakeLocation())..start();
      addTearDown(() => s.changes.close());
      await mountPanel(tester, c);
      final current = find.byKey(const ValueKey('job-step-en_route'));
      final old = find.byKey(const ValueKey('job-step-accepted'));
      expect(
        find.descendant(of: current, matching: find.text('Hiện tại')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: old, matching: find.text('Hiện tại')),
        findsNothing,
      );
      final activeText = tester.widget<Text>(
        find.descendant(
          of: current,
          matching: find.text('Đang đến điểm cứu hộ'),
        ),
      );
      final oldText = tester.widget<Text>(
        find.descendant(of: old, matching: find.text('Đã nhận đơn')),
      );
      expect(activeText.style!.fontWeight, FontWeight.w700);
      expect(oldText.style!.fontWeight, FontWeight.w400);
      for (final key in ['arrived', 'in_progress', 'completed']) {
        expect(
          find.descendant(
            of: find.byKey(ValueKey('job-step-$key')),
            matching: find.textContaining(RegExp(r'\d\d:\d\d')),
          ),
          findsNothing,
        );
      }
      expect(find.byKey(const ValueKey('job-step-quote')), findsNothing);
      expectNoFakeData();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'cancelled state remains visible without offering another job action',
    (tester) async {
      final s = ActiveUiFake()..state = 'cancelled';
      final c = RescuerController(s, FakeLocation())..start();
      addTearDown(() => s.changes.close());
      await mountPanel(tester, c);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('job-step-cancelled')),
          matching: find.text('Hiện tại'),
        ),
        findsOneWidget,
      );
      for (final key in ['advance-job', 'open-quote', 'complete-job']) {
        expect(find.byKey(ValueKey(key)), findsNothing);
      }
      expectNoFakeData();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'quote summary protects UUIDs and never invents fee items or a complete receipt',
    (tester) async {
      final s = ActiveUiFake()
        ..quoteId = 'quote'
        ..total = 120000
        ..requestCode = uuid
        ..quoteCode = uuid;
      final c = RescuerController(s, FakeLocation())..start();
      addTearDown(() => s.changes.close());
      await mountPanel(tester, c);
      expect(find.text('Mã đơn: Chưa có mã'), findsOneWidget);
      expect(find.text('Mã báo giá: Chưa có mã'), findsOneWidget);
      expect(find.text('Tổng báo giá'), findsOneWidget);
      expect(find.text('120.000 ₫'), findsOneWidget);
      expect(
        find.text('Hiện có tổng tiền; chi tiết dòng phí chưa được cung cấp.'),
        findsOneWidget,
      );
      expect(find.textContaining('×'), findsNothing);
      expect(find.textContaining('Biên nhận'), findsNothing);
      c.currentQuote = const QuoteDetails(
        id: 'other-quote',
        assignmentId: 'other-assignment',
        totalVnd: 999999,
        status: 'issued',
        note: 'OTHER CUSTOMER NOTE',
        items: [QuoteItem('tire', 1, 999999)],
      );
      c.selectTab(0);
      await tester.pumpAndSettle();
      expect(find.textContaining('OTHER CUSTOMER NOTE'), findsNothing);
      expect(find.textContaining('999.999'), findsNothing);
      expectNoFakeData();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'quote without a total cannot complete and explains what is missing',
    (tester) async {
      final s = ActiveUiFake()
        ..quoteId = 'quote'
        ..total = null;
      final c = RescuerController(s, FakeLocation())..start();
      addTearDown(() => s.changes.close());
      await mountPanel(tester, c);
      final action = find.descendant(
        of: find.byKey(const ValueKey('complete-job')),
        matching: find.byType(FilledButton),
      );
      expect(tester.widget<FilledButton>(action).onPressed, isNull);
      expect(
        find.text(
          'Tổng tiền chưa được cung cấp. Tải lại chuyến để kiểm tra báo giá.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Hiện có tổng tiền; chi tiết dòng phí chưa được cung cấp.'),
        findsNothing,
      );
      expect(find.byKey(const ValueKey('send-quote')), findsNothing);
      expectNoFakeData();
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets(
    'empty job offers new requests and loading/error retain retry without stale PII',
    (tester) async {
      final s = ActiveUiFake()..missingJob = true;
      final c = RescuerController(s, FakeLocation())..start();
      addTearDown(() => s.changes.close());
      await mountPanel(tester, c);
      expect(find.text('Chưa có chuyến đang xử lý'), findsOneWidget);
      await tester.tap(find.text('Xem đơn mới'));
      await tester.pumpAndSettle();
      expect(c.tab, 1);
      expect(find.text('Tải lại chuyến'), findsOneWidget);
      s.missingJob = false;
      s.state = 'accepted';
      await c.refreshActiveJob();
      c.jobStatus = JobStatus.loading;
      c.selectTab(0);
      await tester.pump();
      expect(find.text('Đang tải chuyến'), findsOneWidget);
      expect(find.text('0901234567'), findsNothing);
      final action = find.descendant(
        of: find.byKey(const ValueKey('advance-job')),
        matching: find.byType(FilledButton),
      );
      expect(tester.widget<FilledButton>(action).onPressed, isNull);
      s.jobFailure = const PostgrestException(
        message: 'permission denied',
        code: '42501',
      );
      await c.refreshActiveJob();
      await tester.pumpAndSettle();
      expect(find.text('Chưa tải được thông tin chuyến'), findsOneWidget);
      expect(find.text('0901234567'), findsNothing);
      expect(find.text('Điểm cứu hộ thật'), findsNothing);
      expect(tester.widget<FilledButton>(action).onPressed, isNull);
      expect(find.text('Tải lại chuyến'), findsOneWidget);
      expectNoFakeData();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
