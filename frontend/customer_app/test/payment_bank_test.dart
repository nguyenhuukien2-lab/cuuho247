import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/screens/payment_screen.dart';
import 'package:cuu_ho_247/services/payment_service.dart';
import 'package:cuu_ho_247/widgets/payment_ui.dart';
import 'package:cuu_ho_247/widgets/bank_payment_ui.dart';
import 'package:cuu_ho_247/core/utils/payment_format.dart';
import 'payment_commands_test.dart' show CashSource, requestA, requestB;
import 'payment_ui_test.dart' show PaymentDetails;
import 'payment_realtime_test.dart' as rt;

// Synthetic server fixture only, never an app beneficiary/fallback.
const qrFixture =
    '00020101021238560010A0000007270126000697043601121234567890120208QRIBFTTA530370454061000005802VN62250821BK000000000000000000163048CBA';
Map<String, dynamic> bankDto(
        {String intentStatus = 'ready',
        String status = 'awaiting_payment',
        String intentId = '91000000-0000-4000-8000-000000000101',
        String version = '2',
        String intentVersion = '2'}) =>
    {
      'payment_id': 'payment-$requestA',
      'bank_intent_id': intentId,
      'payment_code': 'TT-000001',
      'request_id': requestA,
      'payment_status': status,
      'payment_method': 'bank_transfer',
      'amount_expected': '100000',
      'currency': 'VND',
      'bank_intent_status': intentStatus,
      'bank_reference': 'BK-00000000000000000000000000000001',
      'bank_code': 'TEST',
      'bank_bin': '970436',
      'bank_name': 'Synthetic bank',
      'account_number': '123456789012',
      'account_name': 'SYNTHETIC BENEFICIARY',
      'transfer_content': 'BK0000000000000000001',
      'expires_at': '2026-10-11T01:15:00Z',
      'server_time': '2026-10-11T01:00:00Z',
      'available': true,
      'qr_payload': intentStatus == 'ready' ? qrFixture : null,
      'version': version,
      'bank_intent_version': intentVersion,
    };

class BankSource extends CashSource implements BankPaymentSource {
  bool available = true;
  Object? bankFailure;
  Map<String, dynamic>? bankRow;
  final bankSelections = <BankPaymentSelection>[];
  final bankRegenerations = <BankPaymentRegeneration>[];
  final order = <String>[];
  Future<void> Function()? selectingBank;
  Future<void> Function()? regeneratingBank;
  Future<Map<String, dynamic>?> Function()? bankLoader;
  int bankReads = 0;
  @override
  Future<Map<String, dynamic>?> load(String id) {
    order.add('payment');
    return super.load(id);
  }

  @override
  Future<bool> bankCapability(String id) async => available;
  @override
  Future<Map<String, dynamic>?> loadBank(String id) async {
    order.add('bank');
    bankReads++;
    if (bankFailure != null) throw bankFailure!;
    return bankLoader == null ? bankRow : bankLoader!();
  }

  @override
  Future<void> selectBank(BankPaymentSelection selection) async {
    bankSelections.add(selection);
    if (selectingBank != null) await selectingBank!();
  }

  @override
  Future<void> regenerateBank(BankPaymentRegeneration regeneration) async {
    bankRegenerations.add(regeneration);
    if (regeneratingBank != null) await regeneratingBank!();
  }

  void awaiting(
      {String status = 'awaiting_payment', String intentStatus = 'ready'}) {
    row = rt.dto(request: requestA, status: status, version: '2')
      ..['method'] = 'bank_transfer';
    bankRow = bankDto(status: status, intentStatus: intentStatus);
  }
}

void main() {
  late BankSource source;
  late AppController controller;
  var serial = 0;
  setUp(() {
    source = BankSource();
    serial = 0;
    controller = AppController(
        paymentSource: source,
        paymentOperationId: () => 'operation-${++serial}');
  });
  tearDown(() async {
    controller.dispose();
    await rt.flush();
    await source.close();
  });
  Future<void> open() async {
    controller.bindPaymentRequest(requestA);
    await controller.watchPayment(requestA);
    source.emit(PaymentSignalKind.connected);
    await rt.flush();
  }

  Future<void> render(WidgetTester tester,
      {bool settle = true,
      double width = 390,
      double scale = 1,
      String id = requestA}) async {
    tester.view.physicalSize = Size(width, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(MaterialApp(
        builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(scale)),
            child: child!),
        home: PaymentScreen(
            requestId: id,
            controller: controller,
            repository: PaymentDetails())));
    await tester.runAsync(rt.flush);
    await tester.pump();
    if (source.channels.isNotEmpty) source.emit(PaymentSignalKind.connected);
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  Finder bankCard() =>
      find.byWidgetPredicate((w) => w is PaymentMethodCard && !w.cash);

  test('bank capability fails closed', () async {
    source.available = false;
    await open();
    expect(await controller.selectBankPayment(requestA), false);
    expect(source.bankSelections, isEmpty);
    expect(await controller.selectCashPayment(requestA), true);
  });
  test('bank double tap coalesces with exact params and authoritative refresh',
      () async {
    await open();
    final gate = Completer<void>();
    source.selectingBank = () => gate.future;
    final a = controller.selectBankPayment(requestA),
        b = controller.selectBankPayment(requestA);
    expect(identical(a, b), true);
    expect(source.bankSelections.length, 1);
    expect(source.bankSelections.single.parameters, {
      'p_request_id': requestA,
      'p_payment_id': 'payment-$requestA',
      'p_expected_version': '1',
      'p_operation_id': 'operation-1'
    });
    source.awaiting();
    gate.complete();
    await a;
    expect(controller.payments.payment!.status, 'awaiting_payment');
    expect(controller.payments.bankPayment!.qrPayload, qrFixture);
  });
  test('bank timeout preserves retry payload and blocks cash switch', () async {
    await open();
    source.selectingBank = () async {
      throw TimeoutException('ambiguous');
    };
    expect(await controller.selectBankPayment(requestA), false);
    final original = source.bankSelections.single;
    expect(await controller.selectCashPayment(requestA), false);
    source.selectingBank = () async {
      source.awaiting();
    };
    expect(await controller.selectBankPayment(requestA), true);
    expect(identical(original, source.bankSelections.last), true);
    expect(serial, 1);
  });
  test('expired regeneration double tap uses exact guards then refetches',
      () async {
    source.awaiting(intentStatus: 'expired');
    await open();
    final reads = source.reads, bankReads = source.bankReads;
    final gate = Completer<void>();
    source.regeneratingBank = () => gate.future;
    final a = controller.regenerateBankPayment(requestA),
        b = controller.regenerateBankPayment(requestA);
    expect(identical(a, b), true);
    expect(source.bankRegenerations.length, 1);
    expect(source.bankRegenerations.single.parameters, {
      'p_request_id': requestA,
      'p_payment_id': 'payment-$requestA',
      'p_expected_version': '2',
      'p_expected_intent_id': '91000000-0000-4000-8000-000000000101',
      'p_expected_intent_version': '2',
      'p_operation_id': 'operation-1'
    });
    source.row = rt.dto(
        request: requestA, status: 'awaiting_payment', version: '3')
      ..['method'] = 'bank_transfer';
    source.bankRow =
        bankDto(intentId: '91000000-0000-4000-8000-000000000102', version: '3');
    gate.complete();
    expect(await a, true);
    expect(source.reads, greaterThan(reads));
    expect(source.bankReads, greaterThan(bankReads));
    expect(controller.payments.payment!.status, 'awaiting_payment');
    expect(controller.payments.bankPayment!.intentId,
        '91000000-0000-4000-8000-000000000102');
  });
  test('expired regeneration timeout retries the same operation id', () async {
    source.awaiting(intentStatus: 'expired');
    await open();
    source.regeneratingBank = () async => throw TimeoutException('ambiguous');
    expect(await controller.regenerateBankPayment(requestA), false);
    final original = source.bankRegenerations.single;
    source.regeneratingBank = () async {
      source.row = rt.dto(
          request: requestA, status: 'awaiting_payment', version: '3')
        ..['method'] = 'bank_transfer';
      source.bankRow = bankDto(
          intentId: '91000000-0000-4000-8000-000000000103', version: '3');
    };
    expect(await controller.regenerateBankPayment(requestA), true);
    expect(identical(original, source.bankRegenerations.last), true);
    expect(serial, 1);
  });
  test('uncertain cash blocks bank', () async {
    await open();
    source.selecting = () async {
      throw TimeoutException('ambiguous');
    };
    await controller.selectCashPayment(requestA);
    expect(await controller.selectBankPayment(requestA), false);
    expect(source.bankSelections, isEmpty);
  });
  test('bank version conflict refresh then new payload', () async {
    await open();
    source.selectingBank = () async {
      source.row = rt.dto(request: requestA, version: '3');
      throw const PaymentCommandFailure('VERSION_CONFLICT');
    };
    await controller.selectBankPayment(requestA);
    expect(controller.paymentCommandError(requestA), 'VERSION_CONFLICT');
    source.selectingBank = () async {};
    await controller.selectBankPayment(requestA);
    expect(source.bankSelections.last.expectedVersion, BigInt.from(3));
    expect(source.bankSelections.last.operationId, 'operation-2');
  });
  test(
      'bank acknowledgement alone never updates payment or permits new selection',
      () async {
    await open();
    await controller.selectBankPayment(requestA);
    expect(controller.payments.payment!.status, 'pending');
    expect(await controller.selectBankPayment(requestA), false);
    expect(await controller.selectCashPayment(requestA), false);
  });
  test('bank HTTP sends no amount beneficiary reference or method', () async {
    final paths = <String>[], bodies = <Map<String, dynamic>>[];
    final client = await rt.clientFor((request) async {
      paths.add(request.url.path);
      bodies.add(jsonDecode(request.body));
      if (request.url.path.endsWith('customer_get_bank_capability'))
        return rt.response({'available': true});
      if (request.url.path.endsWith('customer_get_bank_payment'))
        return rt.response(bankDto());
      return rt
          .response({'payment': rt.dto(request: requestA), 'changed': true});
    });
    final transport = SupabasePaymentSource(client);
    final selection = BankPaymentSelection(
        requestId: requestA,
        paymentId: 'payment',
        expectedVersion: BigInt.parse('9007199254740993'),
        operationId: newPaymentOperationId());
    await transport.selectBank(selection);
    expect(bodies.single, selection.parameters);
    expect(paths.single, '/rest/v1/rpc/customer_select_bank_transfer');
    expect(await transport.bankCapability(requestA), true);
    expect((await transport.loadBank(requestA))!['qr_payload'], qrFixture);
  });
  test('regeneration HTTP uses exact RPC path and server-owned bank fields',
      () async {
    late String path;
    late Map<String, dynamic> body;
    final client = await rt.clientFor((request) async {
      path = request.url.path;
      body = Map<String, dynamic>.from(jsonDecode(request.body));
      return rt
          .response({'payment': rt.dto(request: requestA), 'changed': true});
    });
    final transport = SupabasePaymentSource(client);
    final regeneration = BankPaymentRegeneration(
        requestId: requestA,
        paymentId: 'payment-$requestA',
        expectedVersion: BigInt.parse('9007199254740993'),
        expectedIntentId: '91000000-0000-4000-8000-000000000101',
        expectedIntentVersion: BigInt.from(2),
        operationId: '91000000-0000-4000-8000-000000000199');
    await transport.regenerateBank(regeneration);
    expect(path, '/rest/v1/rpc/customer_regenerate_bank_transfer');
    expect(body, regeneration.parameters);
    for (final forbidden in [
      'amount',
      'p_amount',
      'reference',
      'p_reference',
      'beneficiary',
      'bank_bin',
      'account_number',
      'expires_at'
    ]) {
      expect(body.containsKey(forbidden), false);
    }
  });
  test('bank realtime reads public getter before bank getter', () async {
    source.awaiting();
    await open();
    source.order.clear();
    source.emit(PaymentSignalKind.changed);
    await rt.flush();
    expect(source.order, ['payment', 'bank']);
    expect(controller.payments.payment!.status, 'awaiting_payment');
  });
  test('raw realtime paid bank row is ignored by both getters', () async {
    final client = await rt.clientFor((request) async {
      if (request.url.path.endsWith('customer_get_bank_payment'))
        return rt.response(bankDto());
      return rt.response(
          rt.dto(request: requestA, status: 'awaiting_payment', version: '2')
            ..['method'] = 'bank_transfer');
    });
    final live = AppController(paymentSource: SupabasePaymentSource(client));
    addTearDown(live.dispose);
    await live.watchPayment(requestA);
    client.created.single.row({
      'request_id': requestA,
      'customer_id': client.auth.currentUser!.id,
      'method': 'bank_transfer',
      'status': 'paid',
      'version': 999
    });
    await rt.flush();
    expect(live.payments.payment!.status, 'awaiting_payment');
    expect(live.payments.bankPayment!.status, 'awaiting_payment');
  });
  test('bank wrong snapshot rejected and auth change clears private display',
      () async {
    source.awaiting();
    source.bankRow!['request_id'] = 'other';
    await open();
    expect(controller.payments.bankPayment, isNull);
    expect(controller.payments.bankError, isNotNull);
    source.bankRow = bankDto();
    await controller.refreshPayment();
    expect(controller.payments.bankPayment, isNotNull);
    source.login('other');
    await rt.flush();
    expect(controller.payments.bankPayment, isNull);
  });
  test('late bank getter after auth switch cannot restore old account',
      () async {
    source.awaiting();
    final gate = Completer<Map<String, dynamic>?>();
    source.bankLoader = () => gate.future;
    final pending = controller.watchPayment(requestA);
    await rt.flush();
    source.login('new-owner');
    gate.complete(bankDto());
    await pending;
    expect(controller.payments.bankPayment, isNull);
  });

  for (final available in [false, true]) {
    testWidgets('bank card available=$available comes from capability',
        (tester) async {
      source.available = available;
      await render(tester);
      final card = tester.widget<PaymentMethodCard>(bankCard());
      expect(card.onTap != null, available);
      expect(card.bankAvailable, available);
    });
  }
  testWidgets('select bank loading and double tap', (tester) async {
    await render(tester);
    final gate = Completer<void>();
    source.selectingBank = () => gate.future;
    await tester.ensureVisible(bankCard());
    await tester.tap(bankCard());
    await tester.pumpAndSettle();
    final confirm = find.byKey(const ValueKey('confirm-bank'));
    await tester.tap(confirm);
    await tester.tap(confirm);
    await tester.pump();
    expect(source.bankSelections.length, 1);
    expect(find.byType(CircularProgressIndicator), findsWidgets);
    source.awaiting();
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
  });
  testWidgets('QR uses backend payload, amount, bank and real request code',
      (tester) async {
    source.awaiting();
    await render(tester);
    expect(controller.payments.bankPayment!.qrPayload, qrFixture);
    await tester.ensureVisible(find.text('Synthetic bank'));
    expect(find.text('100.000 đ'), findsOneWidget);
    expect(find.text('TT-000001'), findsOneWidget);
    expect(find.text('CH-000123'), findsOneWidget);
    expect(find.text('123456789012'), findsOneWidget);
    expect(find.text('SYNTHETIC BENEFICIARY'), findsOneWidget);
    expect(find.text('850.000đ'), findsNothing);
    expect(find.text('MB Bank'), findsNothing);
    expect(find.byType(PaymentCashPaidSection), findsNothing);
    expect(find.text('Tôi đã chuyển khoản'), findsNothing);
    expect(find.text('Tôi đã thanh toán'), findsNothing);
  });
  for (final entry in {
    'copy-bank-account': '123456789012',
    'copy-bank-content': 'BK0000000000000000001'
  }.entries) {
    testWidgets('${entry.key} clipboard acknowledged', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData')
          copied = (call.arguments as Map)['text'];
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      source.awaiting();
      await render(tester);
      final button = find.byKey(ValueKey(entry.key));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      expect(copied, entry.value);
      expect(find.text('Đã sao chép'), findsOneWidget);
    });
  }
  testWidgets('clipboard failure never claims copied', (tester) async {
    tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData')
        throw PlatformException(code: 'denied');
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));
    source.awaiting();
    await render(tester);
    final button = find.byKey(const ValueKey('copy-bank-account'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pump();
    expect(find.text('Đã sao chép'), findsNothing);
    expect(find.textContaining('Không thể sao chép'), findsOneWidget);
  });
  testWidgets('refresh only getters never selects or verifies', (tester) async {
    source.awaiting();
    await render(tester);
    final reads = source.reads, bankReads = source.bankReads;
    final button = find.text('Kiểm tra thanh toán');
    await tester.ensureVisible(button);
    await tester.pumpAndSettle();
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(source.reads, greaterThan(reads));
    expect(source.bankReads, greaterThan(bankReads));
    expect(source.bankSelections, isEmpty);
    expect(source.selections, isEmpty);
    expect(controller.payments.payment!.status, 'awaiting_payment');
  });
  for (final status in ['expired', 'cancelled', 'failed']) {
    testWidgets('intent $status hides QR without marking payment paid',
        (tester) async {
      source.awaiting(intentStatus: status);
      await render(tester);
      expect(find.byType(QrImageView), findsNothing);
      expect(
          find.text(switch (status) {
            'expired' => 'Phiên thanh toán đã hết hạn.',
            'cancelled' => 'Yêu cầu chuyển khoản đã hủy',
            _ => 'Không thể tạo thông tin chuyển khoản',
          }),
          findsOneWidget);
      expect(controller.payments.payment!.status, 'awaiting_payment');
      expect(find.text('Tạo mã mới'),
          status == 'expired' ? findsOneWidget : findsNothing);
    });
  }
  testWidgets('expired Tạo mã mới coalesces and keeps payment awaiting',
      (tester) async {
    source.awaiting(intentStatus: 'expired');
    await render(tester);
    expect(find.byType(QrImageView), findsNothing);
    final gate = Completer<void>();
    source.regeneratingBank = () => gate.future;
    final button = find.byKey(const ValueKey('regenerate-bank'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.tap(button);
    await tester.pump();
    expect(source.bankRegenerations.length, 1);
    expect(tester.widget<PaymentActionButton>(button).onPressed, isNull);
    source.row = rt.dto(
        request: requestA, status: 'awaiting_payment', version: '3')
      ..['method'] = 'bank_transfer';
    source.bankRow =
        bankDto(intentId: '91000000-0000-4000-8000-000000000104', version: '3');
    gate.complete();
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
    expect(find.text('Tạo mã mới'), findsNothing);
    expect(controller.payments.payment!.status, 'awaiting_payment');
  });
  testWidgets('reconciliation-required keeps expired safe read-only UI',
      (tester) async {
    source.awaiting(intentStatus: 'expired');
    source.regeneratingBank = () async => throw const PaymentCommandFailure(
        'BANK_TRANSFER_RECONCILIATION_REQUIRED');
    await render(tester);
    final button = find.byKey(const ValueKey('regenerate-bank'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.textContaining('cần đối soát'), findsOneWidget);
    expect(find.textContaining('Không chuyển tiền thêm'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    expect(controller.payments.payment!.status, 'awaiting_payment');
  });
  testWidgets('offline stale disables expired regeneration', (tester) async {
    source.awaiting(intentStatus: 'expired');
    await render(tester);
    source.failure = Exception('offline');
    source.emit(PaymentSignalKind.disconnected);
    await tester.pumpAndSettle();
    final button = find.byKey(const ValueKey('regenerate-bank'));
    await tester.ensureVisible(button);
    expect(tester.widget<PaymentActionButton>(button).onPressed, isNull);
    expect(source.bankRegenerations, isEmpty);
    controller.setForeground(false);
  });
  testWidgets('timer expiry refetches backend and does not mutate payment',
      (tester) async {
    source.awaiting();
    source.bankRow!['expires_at'] = '2026-10-11T01:00:01Z';
    await render(tester);
    final reads = source.reads;
    source.bankRow = bankDto(intentStatus: 'expired');
    await tester.pump(const Duration(seconds: 2));
    await tester.pumpAndSettle();
    expect(source.reads, greaterThan(reads));
    expect(controller.payments.payment!.status, 'awaiting_payment');
    expect(source.bankSelections, isEmpty);
  });
  testWidgets('bank getter loading no fake QR', (tester) async {
    source.awaiting();
    final gate = Completer<Map<String, dynamic>?>();
    source.bankLoader = () => gate.future;
    await render(tester, settle: false);
    expect(find.byType(QrImageView), findsNothing);
    gate.complete(bankDto());
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsOneWidget);
  });
  testWidgets(
      'offline stale hides QR and preserves last account with disabled copy',
      (tester) async {
    source.awaiting();
    await render(tester);
    source.failure = Exception('offline');
    source.emit(PaymentSignalKind.disconnected);
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    await tester.ensureVisible(find.byKey(const ValueKey('copy-bank-account')));
    expect(
        tester
            .widget<IconButton>(find.byKey(const ValueKey('copy-bank-account')))
            .onPressed,
        isNull);
    expect(find.text('Dữ liệu có thể chưa được cập nhật.'), findsOneWidget);
    controller.setForeground(false);
  });
  testWidgets('bank getter error remains recoverable without fake success',
      (tester) async {
    source.awaiting();
    await render(tester);
    source.bankFailure = Exception('offline');
    await controller.refreshPayment();
    await tester.pumpAndSettle();
    expect(find.byType(QrImageView), findsNothing);
    expect(
        find.text('Chưa cập nhật được thông tin chuyển khoản'), findsOneWidget);
  });
  testWidgets('disabled configuration hides existing QR', (tester) async {
    source.awaiting();
    source.bankRow!['available'] = false;
    source.bankRow!['qr_payload'] = null;
    await render(tester);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Chuyển khoản chưa khả dụng'), findsOneWidget);
  });
  testWidgets('verifying is read only from getter', (tester) async {
    source.awaiting(status: 'verifying');
    await render(tester, settle: false);
    expect(find.text('Đang xác minh giao dịch'), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    expect(source.bankSelections, isEmpty);
  });

  void paid({String version = '3'}) {
    source.awaiting(status: 'paid', intentStatus: 'settled');
    source.row!['version'] = version;
    source.row!['cash_received_at'] = null;
    source.bankRow!['version'] = version;
  }

  testWidgets(
      'bank paid renders received amount and server time with safe reference',
      (tester) async {
    paid();
    await render(tester);
    expect(find.byType(BankPaymentPaidSection), findsOneWidget);
    expect(
        find.text('Thanh toán chuyển khoản đã được xác nhận.'), findsOneWidget);
    expect(find.text('100.000 đ'), findsOneWidget);
    expect(
        find.text(
            paymentTime(DateTime.parse(source.row!['paid_at'] as String))),
        findsOneWidget);
    expect(
        find.text(source.bankRow!['bank_reference'] as String), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.byType(PaymentCashPaidSection), findsNothing);
    for (final forbidden in [
      'Tôi đã chuyển khoản',
      'Xác nhận đã trả',
      'Mark paid',
      'API WEBHOOK BACKEND: SYNCING...'
    ]) {
      expect(find.text(forbidden), findsNothing);
    }
    expect(source.bankSelections, isEmpty);
    expect(source.selections, isEmpty);
  });
  testWidgets('missing received amount never falls back to expected amount',
      (tester) async {
    paid();
    source.row!['amount_received'] = null;
    source.row!['paid_at'] = null;
    await render(tester);
    expect(find.text('100.000 đ'), findsNothing);
    expect(find.text('Chưa có thông tin số tiền đã nhận.'), findsOneWidget);
    expect(find.text('Chưa có thông tin'), findsOneWidget);
  });
  testWidgets('paid remains authoritative when optional bank getter fails',
      (tester) async {
    paid();
    source.bankFailure = Exception('offline');
    await render(tester);
    expect(find.byType(BankPaymentPaidSection), findsOneWidget);
    expect(find.text('Không thể cập nhật trạng thái.'), findsOneWidget);
    expect(find.text('Mã tham chiếu thanh toán'), findsNothing);
  });
  testWidgets('bank realtime shows paid before slow optional bank enrichment',
      (tester) async {
    source.awaiting();
    await render(tester);
    paid();
    final gate = Completer<Map<String, dynamic>?>();
    source.bankLoader = () => gate.future;
    source.emit(PaymentSignalKind.changed);
    await tester.pump();
    await tester.pump();
    expect(find.byType(BankPaymentPaidSection), findsOneWidget);
    expect(find.byType(QrImageView), findsNothing);
    expect(find.text('Mã tham chiếu thanh toán'), findsNothing);
    gate.complete(source.bankRow);
    await tester.pumpAndSettle();
    expect(find.text('Mã tham chiếu thanh toán'), findsOneWidget);
    expect(source.bankSelections, isEmpty);
  });
  testWidgets('bank resume refetch recovers paid without manual refresh',
      (tester) async {
    source.awaiting();
    await render(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    paid();
    source.emit(PaymentSignalKind.changed);
    await tester.pump();
    expect(find.byType(BankPaymentPaidSection), findsNothing);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(find.byType(BankPaymentPaidSection), findsOneWidget);
  });
  testWidgets(
      'network failure preserves paid with stale warning and refresh recovers',
      (tester) async {
    paid();
    await render(tester);
    source.failure = Exception('offline');
    await controller.refreshPayment();
    await tester.pump();
    expect(find.byType(BankPaymentPaidSection), findsOneWidget);
    expect(find.byType(BankPaymentOutcomeSection), findsNothing);
    expect(find.text('Dữ liệu có thể chưa được cập nhật.'), findsOneWidget);
    expect(find.text('Không thể cập nhật trạng thái.'), findsOneWidget);
    source.failure = null;
    await tester.ensureVisible(find.text('Tải lại'));
    await tester.tap(find.text('Tải lại'));
    await tester.pumpAndSettle();
    expect(find.text('Không thể cập nhật trạng thái.'), findsNothing);
    expect(find.byType(BankPaymentPaidSection), findsOneWidget);
  });
  for (final owner in <String?>[null, 'another-owner']) {
    testWidgets('bank paid clears on auth switch $owner', (tester) async {
      paid();
      await render(tester);
      source.login(owner);
      await tester.pumpAndSettle();
      expect(find.byType(BankPaymentPaidSection), findsNothing);
      expect(find.text('100.000 đ'), findsNothing);
      expect(controller.payments.bankPayment, isNull);
    });
  }
  testWidgets('request switch cannot reuse bank paid or bank reference',
      (tester) async {
    paid();
    await render(tester);
    source.row = rt.dto(request: requestB);
    source.bankRow = null;
    await render(tester, id: requestB);
    expect(find.byType(BankPaymentPaidSection), findsNothing);
    expect(find.text('Mã tham chiếu thanh toán'), findsNothing);
    expect(controller.payments.requestId, requestB);
  });
  testWidgets('refresh and elapsed timer cannot manufacture verifying or paid',
      (tester) async {
    source.awaiting();
    await render(tester);
    await tester.pump(const Duration(minutes: 16));
    await tester.pumpAndSettle();
    await controller.refreshPayment();
    await tester.pumpAndSettle();
    expect(controller.payments.payment!.status, 'awaiting_payment');
    expect(find.byType(BankPaymentVerifyingSection), findsNothing);
    expect(find.byType(BankPaymentPaidSection), findsNothing);
    expect(source.bankSelections, isEmpty);
  });
  testWidgets('backend verifying transitions to paid on getter invalidation',
      (tester) async {
    source.awaiting(status: 'verifying');
    await render(tester, settle: false);
    expect(find.byType(BankPaymentVerifyingSection), findsOneWidget);
    expect(find.text('API WEBHOOK BACKEND: SYNCING...'), findsNothing);
    paid();
    source.emit(PaymentSignalKind.changed);
    await tester.pumpAndSettle();
    expect(find.byType(BankPaymentPaidSection), findsOneWidget);
    expect(find.byType(BankPaymentVerifyingSection), findsNothing);
  });
  for (final entry in {
    'failed': 'Thanh toán không thành công',
    'cancelled': 'Thanh toán đã hủy',
    'refunded': 'Thanh toán đã hoàn tiền',
  }.entries) {
    testWidgets('bank backend ${entry.key} has distinct outcome',
        (tester) async {
      source.awaiting(status: entry.key);
      await render(tester);
      expect(find.text(entry.value), findsOneWidget);
      expect(find.byType(QrImageView), findsNothing);
      expect(find.byType(BankPaymentPaidSection), findsNothing);
    });
  }
  for (final status in ['awaiting_payment', 'verifying', 'paid']) {
    for (final width in [320.0, 390.0, 480.0]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('bank $status responsive $width scale $scale',
            (tester) async {
          if (status == 'paid') {
            paid();
          } else {
            source.awaiting(status: status);
          }
          await render(tester,
              width: width, scale: scale, settle: status != 'verifying');
          final label = status == 'paid'
              ? 'Xem chi tiết đơn cứu hộ'
              : status == 'awaiting_payment'
                  ? 'Kiểm tra thanh toán'
                  : 'Chuyển khoản ngân hàng';
          await tester.ensureVisible(find.text(label));
          await tester.pump();
          expect(tester.takeException(), isNull);
          final rect = tester.getRect(find.text(label));
          expect(rect.left, greaterThanOrEqualTo(0));
          expect(rect.right, lessThanOrEqualTo(width));
        });
      }
    }
  }
  for (final width in [320.0, 390.0, 480.0]) {
    testWidgets('bank layout width $width text scale 2', (tester) async {
      source.awaiting();
      await render(tester, width: width, scale: 2);
      await tester.ensureVisible(find.text('Kiểm tra thanh toán'));
      await tester.pump();
      expect(tester.takeException(), isNull);
    });
  }
}
