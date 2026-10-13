import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/app/user_session.dart';
import 'package:cuu_ho_247/screens/history_details_screen.dart';
import 'package:cuu_ho_247/core/utils/payment_format.dart';
import 'package:cuu_ho_247/screens/payment_screen.dart';
import 'package:cuu_ho_247/services/payment_service.dart';
import 'package:cuu_ho_247/services/request_details_service.dart';
import 'package:cuu_ho_247/widgets/payment_ui.dart';
import 'payment_commands_test.dart' show CashSource, requestA, requestB;
import 'payment_realtime_test.dart' as rt;
import 'history_details_test.dart' as history;
import 'customer_request_reviews_test.dart' as reviews;

class PaymentDetails implements RequestDetailsRepository {
  String status = 'completed';
  String owner = 'owner';
  @override
  Future<RequestDetails?> load(String id) async => RequestDetails({
        'id': id,
        'customer_id': owner,
        'request_code': id == requestA ? 'CH-000123' : 'CH-000456',
        'status': status,
        'service_code': 'tire',
        'contact_name': 'Customer not rescuer',
        'contact_phone': 'customer-phone',
      }, []);
}

void main() {
  late CashSource source;
  late AppController controller;
  late PaymentDetails details;
  setUp(() {
    source = CashSource();
    controller = AppController(paymentSource: source);
    details = PaymentDetails();
  });
  tearDown(() async {
    controller.dispose();
    await rt.flush();
    await source.close();
  });

  Future<void> render(WidgetTester tester,
      {String id = requestA,
      double width = 390,
      double scale = 1,
      bool settle = true}) async {
    tester.view.reset();
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: PaymentScreen(
            key: const ValueKey('payment'),
            requestId: id,
            controller: controller,
            repository: details)));
    await tester.runAsync(rt.flush);
    await tester.pump();
    if (source.channels.isNotEmpty) source.emit(PaymentSignalKind.connected);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Future<void> openSheet(WidgetTester tester) async {
    final cash = find.byWidgetPredicate(
        (widget) => widget is PaymentMethodCard && widget.cash);
    await tester.ensureVisible(cash);
    await tester.tap(cash);
    await tester.pumpAndSettle();
  }

  testWidgets('loading never shows mock payment', (tester) async {
    final wait = Completer<Map<String, dynamic>?>();
    source.loader = (_) => wait.future;
    await render(tester, settle: false);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    expect(find.byType(PaymentSummaryCard), findsNothing);
    expect(find.text('Chuẩn bị thanh toán'), findsNothing);
    expect(find.text('170.000đ'), findsNothing);
    wait.complete(null);
    await tester.pumpAndSettle();
  });

  testWidgets('null payment only prepares on explicit user action',
      (tester) async {
    source.row = null;
    source.preparing = () async {
      source.row = rt.dto(request: requestA);
    };
    await render(tester);
    expect(find.text('Chưa có thông tin thanh toán cho yêu cầu này.'),
        findsOneWidget);
    expect(source.preparations, isEmpty);
    await tester.tap(find.text('Chuẩn bị thanh toán'));
    await tester.pumpAndSettle();
    expect(source.preparations, [requestA]);
    expect(find.byType(PaymentSummaryCard), findsOneWidget);
    expect(find.text('100.000 đ'), findsOneWidget);
    expect(find.byType(PaymentCashPaidSection), findsNothing);
  });

  testWidgets('ineligible or unowned metadata cannot offer prepare',
      (tester) async {
    source.row = null;
    details.status = 'in_progress';
    await render(tester);
    expect(find.text('Chuẩn bị thanh toán'), findsNothing);
    expect(source.preparations, isEmpty);
  });

  for (final entry in {
    'PAYMENT_NOT_ELIGIBLE': 'Yêu cầu này chưa đủ điều kiện tạo thanh toán.',
    'ZERO_AMOUNT_REQUIRES_POLICY':
        'Thanh toán có số tiền bằng 0 chưa được hỗ trợ.',
  }.entries) {
    testWidgets('prepare ${entry.key} remains null with honest error',
        (tester) async {
      source.row = null;
      source.preparing = () async {
        throw PaymentCommandFailure(entry.key);
      };
      await render(tester);
      await tester.tap(find.text('Chuẩn bị thanh toán'));
      await tester.pumpAndSettle();
      expect(find.text(entry.value), findsOneWidget);
      expect(find.byType(PaymentAmountText), findsNothing);
      expect(find.byType(PaymentCashPaidSection), findsNothing);
    });
  }

  testWidgets(
      'pending uses real CH TT and amount; bank disabled never calls RPC',
      (tester) async {
    await render(tester);
    expect(find.text('Mã cứu hộ: CH-000123'), findsOneWidget,
        reason:
            'reads=${source.reads}; request=${controller.payments.requestId}; status=${controller.payments.payment?.status}; error=${controller.payments.error}; texts=${tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList()}');
    expect(find.text('TT-000001'), findsOneWidget);
    final bank = find.byWidgetPredicate(
        (widget) => widget is PaymentMethodCard && !widget.cash);
    expect(tester.widget<PaymentMethodCard>(bank).onTap, isNull);
    await tester.ensureVisible(bank);
    await tester.tap(bank);
    await tester.pumpAndSettle();
    expect(find.text('Chưa hỗ trợ'), findsOneWidget);
    expect(find.byType(PaymentConfirmationSheet), findsNothing);
    expect(source.selections, isEmpty);
    expect(source.preparations, isEmpty);
  });

  testWidgets(
      'cash sheet loading and double tap sends once then authoritative awaiting',
      (tester) async {
    final wait = Completer<void>();
    source.selecting = () => wait.future;
    await render(tester);
    await openSheet(tester);
    final confirm = find.byKey(const ValueKey('confirm-cash'));
    await tester.tap(confirm);
    await tester.tap(confirm);
    await tester.pump();
    expect(source.selections, hasLength(1));
    expect(tester.widget<PaymentActionButton>(confirm).loading, isTrue);
    expect(find.byType(PaymentCashPaidSection), findsNothing);
    source.row =
        rt.dto(request: requestA, version: '2', status: 'awaiting_payment');
    wait.complete();
    await tester.pumpAndSettle();
    expect(find.byType(PaymentConfirmationSheet), findsNothing);
    expect(find.byType(PaymentCashAwaitingSection), findsOneWidget);
    expect(find.text('Đã chọn tiền mặt. Chờ đối tác xác nhận thu tiền.'),
        findsOneWidget);
  });

  testWidgets('sheet timeout retry preserves operation id', (tester) async {
    source.selecting = () async {
      throw TimeoutException('unknown');
    };
    await render(tester);
    await openSheet(tester);
    await tester.tap(find.byKey(const ValueKey('confirm-cash')));
    await tester.pumpAndSettle();
    final payload = source.selections.single.parameters;
    source.selecting = () async {
      source.row =
          rt.dto(request: requestA, version: '2', status: 'awaiting_payment');
    };
    await tester.ensureVisible(find.byKey(const ValueKey('confirm-cash')));
    await tester.tap(find.byKey(const ValueKey('confirm-cash')));
    await tester.pumpAndSettle();
    expect(source.selections, hasLength(2));
    expect(source.selections.last.parameters, payload);
    expect(find.byType(PaymentCashAwaitingSection), findsOneWidget);
  });

  testWidgets('cash acknowledgement with unchanged getter remains pending',
      (tester) async {
    await render(tester);
    await openSheet(tester);
    await tester.tap(find.byKey(const ValueKey('confirm-cash')));
    await tester.pumpAndSettle();
    expect(find.byType(PaymentSummaryCard), findsOneWidget);
    expect(find.byType(PaymentCashPaidSection), findsNothing);
    expect(find.byType(PaymentCashAwaitingSection), findsNothing);
    final cash = find.byWidgetPredicate(
        (widget) => widget is PaymentMethodCard && widget.cash);
    await tester.ensureVisible(cash);
    expect(tester.widget<PaymentMethodCard>(cash).onTap, isNull);
  });

  testWidgets('awaiting has no customer paid action or fabricated recipient',
      (tester) async {
    source.row = rt.dto(request: requestA, status: 'awaiting_payment');
    await render(tester);
    expect(find.text('Đang chờ đối tác xác nhận'), findsOneWidget);
    expect(find.text('Vui lòng thanh toán trực tiếp cho đối tác cứu hộ.'),
        findsOneWidget);
    expect(find.text('Tôi đã thanh toán'), findsNothing);
    expect(find.text('Đã trả tiền'), findsNothing);
    expect(find.text('Customer not rescuer'), findsNothing);
    expect(find.text('customer-phone'), findsNothing);
    expect(find.byType(PaymentCashPaidSection), findsNothing);
  });

  testWidgets(
      'realtime getter enables paid, lower/equal versions cannot revert',
      (tester) async {
    source.row =
        rt.dto(request: requestA, status: 'awaiting_payment', version: '2');
    await render(tester);
    source.row = rt.dto(request: requestA, status: 'paid', version: '3');
    source.emit(PaymentSignalKind.changed);
    await tester.pumpAndSettle();
    expect(find.byType(PaymentCashPaidSection), findsOneWidget);
    expect(find.text('Đối tác đã xác nhận nhận tiền mặt.'), findsOneWidget);
    expect(find.text('100.000 đ'), findsOneWidget);
    for (final version in ['2', '3']) {
      source.row = rt.dto(
          request: requestA, status: 'awaiting_payment', version: version);
      source.emit(PaymentSignalKind.changed);
      await tester.pumpAndSettle();
      expect(find.byType(PaymentCashPaidSection), findsOneWidget);
    }
    expect(source.maximumActive, 1);
    expect(source.selections, isEmpty);
  });

  testWidgets('paid bank does not render cash paid', (tester) async {
    source.row = {
      ...rt.dto(request: requestA, status: 'paid'),
      'method': 'bank_transfer'
    };
    await render(tester);
    expect(find.byType(PaymentCashPaidSection), findsNothing);
    expect(
        find.text('Thanh toán chuyển khoản đã được xác nhận.'), findsOneWidget);
  });

  testWidgets('offline preserves last valid DTO and safe refresh recovers',
      (tester) async {
    source.row = rt.dto(request: requestA, status: 'awaiting_payment');
    await render(tester);
    source.failure = TimeoutException('offline');
    source.emit(PaymentSignalKind.disconnected);
    await controller.refreshPayment();
    await tester.pump();
    expect(find.text('Dữ liệu có thể chưa được cập nhật.'), findsOneWidget);
    expect(find.byType(PaymentCashAwaitingSection), findsOneWidget);
    expect(find.text('Thanh toán thất bại'), findsNothing);
    source.failure = null;
    source.emit(PaymentSignalKind.connected);
    await tester.tap(find.text('Tải lại'));
    await tester.pumpAndSettle();
    expect(find.text('Dữ liệu có thể chưa được cập nhật.'), findsNothing);
  });

  for (final nextUser in <String?>[null, 'another-owner']) {
    testWidgets(
        'auth change $nextUser clears visible sensitive payment and sheet',
        (tester) async {
      await render(tester);
      await openSheet(tester);
      source.login(nextUser);
      await tester.pumpAndSettle();
      expect(find.text('100.000 đ'), findsNothing);
      expect(find.byType(PaymentSummaryCard), findsNothing);
      expect(find.byType(PaymentConfirmationSheet), findsNothing);
      expect(controller.payments.payment, isNull);
      expect(source.selections, isEmpty);
    });
  }

  testWidgets('switch request removes old paid DTO and binds exact new request',
      (tester) async {
    source.row = rt.dto(request: requestA, status: 'paid');
    await render(tester);
    source.row = rt.dto(request: requestB);
    await render(tester, id: requestB);
    expect(find.byType(PaymentCashPaidSection), findsNothing);
    expect(find.text('Mã cứu hộ: CH-000456'), findsOneWidget);
    expect(controller.payments.requestId, requestB);
    expect(source.maximumActive, 1);
  });

  testWidgets('invalid route request safe error no latest completed fallback',
      (tester) async {
    await render(tester, id: 'invalid');
    expect(find.text('Mã yêu cầu không hợp lệ.'), findsOneWidget);
    expect(source.reads, 0);
    expect(find.byType(PaymentSummaryCard), findsNothing);
  });

  testWidgets('history payment CTA routes exact request with shared controller',
      (tester) async {
    UserSession.userId = 'owner';
    addTearDown(UserSession.clear);
    String? routedId;
    await tester.pumpWidget(MaterialApp(
        routes: {
          '/payment': (context) {
            routedId = ModalRoute.of(context)!.settings.arguments as String;
            return PaymentScreen(
                requestId: routedId!,
                controller: controller,
                repository: details);
          }
        },
        home: HistoryDetailsScreen(
            requestId: requestA,
            controller: controller,
            repository: details,
            photoRepository: history.PhotosFake(),
            reviewRepository: reviews.ReviewsFake())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Thanh toán'));
    await tester.pump();
    await tester.runAsync(rt.flush);
    await tester.pumpAndSettle();
    expect(routedId, requestA);
    expect(controller.payments.requestId, requestA);
    expect(find.byType(PaymentSummaryCard), findsOneWidget);
    expect(find.byType(PaymentCashPaidSection), findsNothing);
    expect(source.preparations, isEmpty);
  });

  testWidgets('A to B to A cannot revive a page from an earlier login',
      (tester) async {
    await render(tester);
    source.login('another-owner');
    source.login('owner');
    await tester.pumpAndSettle();
    expect(find.byType(PaymentSummaryCard), findsNothing);
    expect(find.byType(PaymentCashPaidSection), findsNothing);
    expect(find.textContaining('Phiên đăng nhập đã thay đổi'), findsOneWidget);
  });

  testWidgets('BigInt above 2^53 displays exact amount', (tester) async {
    source.row = {
      ...rt.dto(request: requestA),
      'amount_expected': '9007199254740993'
    };
    await render(tester);
    expect(find.text('9.007.199.254.740.993 đ'), findsOneWidget);
    expect(paymentMoney(BigInt.parse('9223372036854775807'), 'VND'),
        '9.223.372.036.854.775.807 đ');
    expect(tester.takeException(), isNull);
  });

  for (final width in [320.0, 390.0, 480.0]) {
    for (final status in ['pending', 'awaiting_payment', 'paid']) {
      for (final scale in [1.0, 2.0]) {
        testWidgets(
            '$status at width $width text scale $scale does not clip CTA',
            (tester) async {
          source.row = rt.dto(request: requestA, status: status);
          await render(tester, width: width, scale: scale);
          expect(tester.takeException(), isNull);
          if (status == 'pending') {
            await openSheet(tester);
            await tester
                .ensureVisible(find.byKey(const ValueKey('confirm-cash')));
            await tester.tap(find.byKey(const ValueKey('confirm-cash')));
            await tester.pumpAndSettle();
            expect(source.selections, hasLength(1));
          } else if (status == 'paid') {
            final cta = find.text('Xem chi tiết đơn cứu hộ');
            await tester.scrollUntilVisible(cta, 180,
                scrollable: find.byType(Scrollable).first);
            await tester.pumpAndSettle();
            expect(cta.hitTestable(), findsOneWidget);
          }
          expect(tester.takeException(), isNull);
        });
      }
    }
  }
}
