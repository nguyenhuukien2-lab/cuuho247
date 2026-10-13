import 'dart:async';
import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/services/payment_service.dart';
import 'payment_realtime_test.dart' as rt;

const requestA = '11111111-1111-4111-8111-111111111111';
const requestB = '22222222-2222-4222-8222-222222222222';

class CashSource extends rt.FakePayments implements PaymentCommands {
  CashSource() {
    row = rt.dto(request: requestA);
  }
  final selections = <CashPaymentSelection>[];
  final preparations = <String>[];
  Future<void> Function()? selecting, preparing;
  @override
  Future<void> prepare(String id) async {
    preparations.add(id);
    if (preparing != null) await preparing!();
  }

  @override
  Future<void> selectCash(CashPaymentSelection selection) async {
    selections.add(selection);
    if (selecting != null) await selecting!();
  }
}

void main() {
  late CashSource source;
  late AppController controller;
  var serial = 0;
  setUp(() {
    source = CashSource();
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
  Future<void> open([String id = requestA]) async {
    controller.bindPaymentRequest(id);
    await controller.watchPayment(id);
    await rt.flush();
    source.emit(PaymentSignalKind.connected);
    await rt.flush();
  }

  test('prepare is explicit, scoped and followed by getter', () async {
    source.row = null;
    await open();
    expect(source.preparations, isEmpty);
    source.preparing = () async {
      source.row = rt.dto(request: requestA);
    };
    final before = source.reads;
    expect(await controller.preparePayment(requestA), isTrue);
    expect(source.preparations, [requestA]);
    expect(source.reads, greaterThan(before));
    expect(controller.payments.payment!.status, 'pending');
    expect(await controller.preparePayment(requestA), isFalse);
  });

  test('double tap shares in-flight task and one immutable cash payload',
      () async {
    await open();
    final wait = Completer<void>();
    source.selecting = () => wait.future;
    final first = controller.selectCashPayment(requestA);
    final second = controller.selectCashPayment(requestA);
    expect(identical(first, second), isTrue);
    expect(controller.paymentSubmitting(requestA), isTrue);
    expect(source.selections, hasLength(1));
    expect(source.selections.single.parameters, {
      'p_request_id': requestA,
      'p_payment_id': 'payment-$requestA',
      'p_method': 'cash',
      'p_expected_version': '1',
      'p_operation_id': 'operation-1',
    });
    source.row =
        rt.dto(request: requestA, version: '2', status: 'awaiting_payment');
    wait.complete();
    expect(await first, isTrue);
    expect(controller.payments.payment!.status, 'awaiting_payment');
    expect(controller.paymentSubmitting(requestA), isFalse);
  });

  test(
      'timeout retry retains operation id AND original payload after newer getter',
      () async {
    await open();
    source.selecting = () async {
      throw TimeoutException('unknown');
    };
    expect(await controller.selectCashPayment(requestA), isFalse);
    final original = source.selections.single;
    source.row = rt.dto(request: requestA, version: '3', status: 'paid');
    await controller.refreshPayment();
    source.selecting = () async {};
    expect(await controller.selectCashPayment(requestA), isTrue);
    expect(identical(source.selections.last, original), isTrue);
    expect(source.selections.last.parameters, original.parameters);
    expect(controller.payments.payment!.status, 'paid');
    expect(serial, 1);
  });

  test('version conflict refetches then a new action uses new version',
      () async {
    await open();
    source.selecting = () async {
      source.row = rt.dto(request: requestA, version: '2');
      throw const PaymentCommandFailure('VERSION_CONFLICT');
    };
    expect(await controller.selectCashPayment(requestA), isFalse);
    expect(controller.paymentCommandError(requestA), 'VERSION_CONFLICT');
    source.selecting = () async {};
    await controller.selectCashPayment(requestA);
    expect(source.selections.last.expectedVersion, BigInt.two);
    expect(source.selections.last.operationId, 'operation-2');
  });

  test(
      'command acknowledgement cannot mark pending paid or allow a second selection',
      () async {
    await open();
    await controller.selectCashPayment(requestA);
    expect(controller.payments.payment!.status, 'pending');
    expect(controller.paymentSelectionNeedsRefresh(requestA), isTrue);
    expect(await controller.selectCashPayment(requestA), isFalse);
    expect(source.selections, hasLength(1));
  });

  for (final code in ['PAYMENT_NOT_ELIGIBLE', 'ZERO_AMOUNT_REQUIRES_POLICY']) {
    test('$code never invents payment', () async {
      source.row = null;
      await open();
      source.preparing = () async {
        throw PaymentCommandFailure(code);
      };
      expect(await controller.preparePayment(requestA), isFalse);
      expect(controller.paymentCommandError(requestA), code);
      expect(controller.payments.payment, isNull);
    });
  }

  test('route blocks background request fallback and wrong-request commands',
      () async {
    await open();
    await controller.watchPayment(requestB);
    expect(controller.payments.requestId, requestA);
    expect(await controller.selectCashPayment(requestB), isFalse);
    expect(source.selections, isEmpty);
  });

  test('invalid request does not call getter or command', () async {
    controller.bindPaymentRequest('invalid');
    expect(await controller.preparePayment('invalid'), isFalse);
    expect(source.reads, 0);
    expect(source.preparations, isEmpty);
  });

  for (final nextUser in <String?>[null, 'another-owner']) {
    test('auth change to $nextUser clears DTO and invalidates late command',
        () async {
      await open();
      final wait = Completer<void>();
      source.selecting = () => wait.future;
      final result = controller.selectCashPayment(requestA);
      source.login(nextUser);
      wait.complete();
      expect(await result, isFalse);
      expect(controller.payments.payment, isNull);
      expect(controller.paymentCommandNotice(requestA), isNull);
      expect(controller.paymentSubmitting(requestA), isFalse);
    });
  }

  test('request switch isolates late command and keeps only one subscription',
      () async {
    await open();
    final wait = Completer<void>();
    source.selecting = () => wait.future;
    final result = controller.selectCashPayment(requestA);
    source.row = rt.dto(request: requestB);
    await open(requestB);
    wait.complete();
    await result;
    expect(controller.payments.payment!.requestId, requestB);
    expect(controller.paymentCommandNotice(requestB), isNull);
    expect(source.maximumActive, 1);
  });

  test('HTTP RPC wire uses bigint strings and ignores stale replay DTO',
      () async {
    final bodies = <Map<String, dynamic>>[];
    final paths = <String>[];
    final client = await rt.clientFor((request) async {
      paths.add(request.url.path);
      bodies.add(jsonDecode(request.body) as Map<String, dynamic>);
      if (request.url.path.endsWith('customer_get_payment')) {
        return rt.response(rt.dto(
            request: requestA, version: '9007199254740993', status: 'paid'));
      }
      if (request.url.path.endsWith('customer_prepare_payment'))
        return rt.response(rt.dto(request: requestA));
      return rt.response({
        'payment':
            rt.dto(request: requestA, version: '2', status: 'awaiting_payment'),
        'changed': false
      });
    });
    final transport = SupabasePaymentSource(client);
    await transport.prepare(requestA);
    final selection = CashPaymentSelection(
        requestId: requestA,
        paymentId: 'payment',
        expectedVersion: BigInt.parse('9007199254740993'),
        operationId: newPaymentOperationId());
    await transport.selectCash(selection);
    expect(paths.take(2), [
      '/rest/v1/rpc/customer_prepare_payment',
      '/rest/v1/rpc/customer_select_payment_method'
    ]);
    expect(bodies[1], selection.parameters);
    expect(bodies[1]['p_expected_version'], '9007199254740993');
    final live = AppController(paymentSource: transport);
    addTearDown(live.dispose);
    await live.watchPayment(requestA);
    await transport.selectCash(selection);
    expect(live.payments.payment!.status, 'paid');
    expect(live.payments.payment!.version.toString(), '9007199254740993');
  });

  test(
      'HTTP timeout is uncertain and controller retries identical serialized payload',
      () async {
    final bodies = <String>[];
    final lateResponse = Completer<void>();
    final client = await rt.clientFor((request) async {
      if (request.url.path.endsWith('customer_get_bank_capability')) {
        return rt.response({'available': false});
      }
      if (request.url.path.endsWith('customer_get_payment'))
        return rt.response(rt.dto(request: requestA));
      bodies.add(request.body);
      if (bodies.length == 1) await lateResponse.future;
      return rt
          .response({'payment': rt.dto(request: requestA), 'changed': false});
    });
    final live = AppController(
        paymentSource: SupabasePaymentSource(client,
            commandTimeout: const Duration(milliseconds: 10)));
    addTearDown(live.dispose);
    await live.watchPayment(requestA);
    expect(await live.selectCashPayment(requestA), isFalse);
    expect(live.paymentCommandError(requestA), 'PAYMENT_COMMAND_UNCERTAIN');
    expect(await live.selectCashPayment(requestA), isTrue);
    expect(bodies, hasLength(2));
    expect(bodies[0], bodies[1]);
    lateResponse.complete();
  });

  test(
      'HTTP business and access errors are mapped without exposing server detail',
      () async {
    var error = 'ZERO_AMOUNT_REQUIRES_POLICY';
    final client = await rt.clientFor(
        (_) async => rt.response({'code': 'P0001', 'message': error}, 400));
    final transport = SupabasePaymentSource(client);
    await expectLater(
        transport.prepare(requestA),
        throwsA(isA<PaymentCommandFailure>()
            .having((e) => e.code, 'code', error)
            .having((e) => e.outcomeUnknown, 'ambiguous', false)));
    error = 'PAYMENT_NOT_ACCESSIBLE';
    await expectLater(
        transport.prepare(requestA), throwsA(isA<PaymentAccessDenied>()));
  });
}
