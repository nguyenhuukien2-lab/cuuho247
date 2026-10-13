import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rescuer/app/payment_watcher.dart';
import 'package:rescuer/models/payment_dto.dart';
import 'package:rescuer/services/payment_service.dart';
import 'package:rescuer/app/rescuer_controller.dart';

import 'connected_app_test.dart' show FakeLocation;
import 'job_finance_test.dart' show FinanceFake;

Map<String, dynamic> dto({
  String request = 'request',
  String version = '1',
  String status = 'pending',
}) => {
  'payment_id': 'payment-$request',
  'payment_code': 'TT-000001',
  'request_id': request,
  'assignment_id': 'assignment',
  'quote_id': 'quote',
  'amount_expected': '100000',
  'amount_received': status == 'paid' ? '100000' : null,
  'currency': 'VND',
  'method': status == 'pending' ? null : 'cash',
  'status': status,
  'version': version,
  'created_at': '2026-10-10T01:00:00Z',
  'updated_at': '2026-10-10T02:00:00Z',
  'paid_at': status == 'paid' ? '2026-10-10T02:00:00Z' : null,
  'cash_received_at': status == 'paid' ? '2026-10-10T02:00:00Z' : null,
};

Future<void> flush() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

class FakePayments implements PaymentSource {
  @override
  String? userId = 'owner';
  final auth = StreamController<String?>.broadcast(sync: true);
  final channels = <StreamController<PaymentSignal>>[];
  final requests = <String>[];
  Map<String, dynamic>? row = dto();
  Object? failure;
  Future<Map<String, dynamic>?> Function(String)? loader;
  int reads = 0, active = 0, maximumActive = 0, removed = 0;
  @override
  Stream<String?> get authChanges => auth.stream;
  @override
  Future<Map<String, dynamic>?> load(String id) async {
    reads++;
    if (failure != null) {
      throw failure!;
    }
    return loader == null ? row : loader!(id);
  }

  @override
  Stream<PaymentSignal> watch(String id) {
    requests.add(id);
    final stream = StreamController<PaymentSignal>(
      onListen: () {
        active++;
        if (active > maximumActive) {
          maximumActive = active;
        }
      },
      onCancel: () {
        active--;
        removed++;
      },
    );
    channels.add(stream);
    return stream.stream;
  }

  void emit(PaymentSignalKind kind, {String? request}) =>
      channels.last.add(PaymentSignal(request ?? requests.last, kind));
  void login(String? user) {
    userId = user;
    auth.add(user);
  }

  Future<void> close() async {
    await auth.close();
    for (final channel in channels) {
      await channel.close();
    }
  }
}

class FakeChannel extends RealtimeChannel {
  FakeChannel(super.name, super.socket);
  final registrations =
      <
        ({
          PostgresChangeEvent event,
          String? schema,
          String? table,
          PostgresChangeFilter? filter,
          void Function(PostgresChangePayload) callback,
        })
      >[];
  void Function(RealtimeSubscribeStatus, Object?)? status;
  @override
  RealtimeChannel onPostgresChanges({
    required PostgresChangeEvent event,
    String? schema,
    String? table,
    PostgresChangeFilter? filter,
    List<PostgresChangeFilter>? filters,
    List<String>? select,
    required void Function(PostgresChangePayload) callback,
  }) {
    registrations.add((
      event: event,
      schema: schema,
      table: table,
      filter: filter,
      callback: callback,
    ));
    return this;
  }

  @override
  RealtimeChannel subscribe([
    void Function(RealtimeSubscribeStatus, Object?)? callback,
    Duration? timeout,
  ]) {
    status = callback;
    return this;
  }

  void row(Map<String, dynamic> record) => registrations.last.callback(
    PostgresChangePayload(
      schema: 'public',
      table: 'payments',
      commitTimestamp: DateTime.utc(2026),
      eventType: PostgresChangeEvent.update,
      newRecord: record,
      oldRecord: {},
      errors: null,
    ),
  );
}

class ChannelClient extends SupabaseClient {
  ChannelClient(http.Client transport)
    : super(
        'https://test.supabase.co',
        'public-test-key',
        httpClient: transport,
        authOptions: const AuthClientOptions(autoRefreshToken: false),
      );
  final created = <FakeChannel>[];
  int removed = 0;
  @override
  RealtimeChannel channel(
    String name, {
    RealtimeChannelConfig opts = const RealtimeChannelConfig(),
  }) {
    final channel = FakeChannel(name, realtime);
    created.add(channel);
    return channel;
  }

  @override
  Future<String> removeChannel(RealtimeChannel channel) async {
    removed++;
    return 'ok';
  }
}

Future<ChannelClient> clientFor(
  Future<http.Response> Function(http.Request) handler,
) async {
  final client = ChannelClient(
    MockClient((request) async {
      final result = await handler(request);
      return http.Response(
        result.body,
        result.statusCode,
        headers: result.headers,
        request: request,
      );
    }),
  );
  await client.auth.setInitialSession(
    jsonEncode({
      'access_token': 'payment-test-token',
      'refresh_token': 'refresh-test-token',
      'token_type': 'bearer',
      'expires_in': 3600,
      'expires_at': 4102444800,
      'user': {
        'id': 'owner',
        'app_metadata': {},
        'user_metadata': {},
        'aud': 'authenticated',
        'created_at': '2026-10-10T00:00:00Z',
      },
    }),
  );
  addTearDown(client.dispose);
  return client;
}

http.Response response(Object? data, [int status = 200]) => http.Response(
  jsonEncode(data),
  status,
  headers: {'content-type': 'application/json'},
);

void main() {
  late FakePayments source;
  late PaymentWatcher watcher;
  setUp(() {
    source = FakePayments();
    watcher = PaymentWatcher(source);
  });
  tearDown(() async {
    watcher.dispose();
    await flush();
    await source.close();
  });

  test(
    'load own payment and null without preparing or inventing defaults',
    () async {
      source.row = null;
      await watcher.watch('request');
      expect(watcher.payment, isNull);
      source.row = dto();
      await watcher.refresh();
      expect(watcher.payment!.amountExpected, BigInt.from(100000));
      expect(watcher.payment!.method, isNull);
    },
  );
  test('SUBSCRIBED and INSERT/UPDATE invalidation refetch authoritative transitions', () async {
    await watcher.watch('request');
    final before = source.reads;
    source.row = dto(version: '2', status: 'awaiting_payment');
    source.emit(PaymentSignalKind.connected);
    await flush();
    expect(source.reads, greaterThan(before));
    expect(watcher.payment!.status, 'awaiting_payment');
    source.row = dto(version: '3', status: 'paid');
    source.emit(PaymentSignalKind.changed);
    await flush();
    expect(watcher.payment!.status, 'paid');
    expect(watcher.payment!.amountReceived, BigInt.from(100000));
    expect(watcher.payment!.paidAt, isNotNull);
  });
  test(
    'lower AND equal versions cannot overwrite accepted paid snapshot',
    () async {
      source.row = dto(version: '3', status: 'paid');
      await watcher.watch('request');
      final paid = watcher.payment;
      for (final version in ['2', '3']) {
        source.row = dto(version: version, status: 'awaiting_payment');
        await watcher.refresh();
        expect(identical(watcher.payment, paid), isTrue);
      }
    },
  );
  test('newer version accepted without using websocket ordering', () async {
    await watcher.watch('request');
    source.row = dto(version: '8', status: 'paid');
    await watcher.refresh();
    expect(watcher.payment!.version, BigInt.from(8));
  });
  test('bigint strings remain exact above JavaScript safe integer range', () {
    final payment = PaymentDto.fromJson({
      ...dto(version: '9223372036854775807'),
      'amount_expected': '9007199254740993',
    });
    expect(payment.amountExpected.toString(), '9007199254740993');
    expect(payment.version.toString(), '9223372036854775807');
  });
  test('malformed version triggers one bounded authoritative retry', () async {
    await watcher.watch('request');
    var n = 0;
    source.loader = (_) async => ++n == 1
        ? dto(version: 'broken')
        : dto(version: '2', status: 'awaiting_payment');
    await watcher.refresh();
    expect(n, 2);
    expect(watcher.payment!.version, BigInt.two);
    source.loader = (_) async => dto(version: 'broken');
    final before = source.reads;
    await watcher.refresh();
    expect(source.reads - before, 2);
    expect(watcher.payment!.version, BigInt.two);
    expect(watcher.stale, isTrue);
  });
  test('reconnect refetch catches paid update missed while offline', () async {
    await watcher.watch('request');
    source.emit(PaymentSignalKind.disconnected);
    await flush();
    expect(watcher.stale, isTrue);
    expect(watcher.payment!.status, 'pending');
    source.row = dto(version: '3', status: 'paid');
    source.emit(PaymentSignalKind.connected);
    await flush();
    expect(watcher.payment!.status, 'paid');
    expect(watcher.stale, isFalse);
    expect(source.requests, hasLength(1));
  });
  test(
    'resume refetches without active job online or GPS prerequisites',
    () async {
      await watcher.watch('request');
      source.emit(PaymentSignalKind.connected);
      await flush();
      watcher.setForeground(false);
      source.row = dto(version: '3', status: 'paid');
      watcher.setForeground(true);
      await flush();
      expect(watcher.payment!.status, 'paid');
      expect(source.maximumActive, 1);
    },
  );
  test('logout clears DTO and removes channel immediately', () async {
    await watcher.watch('request');
    source.login(null);
    expect(watcher.payment, isNull);
    expect(watcher.requestId, isNull);
    await flush();
    expect(source.active, 0);
  });
  test('user switch cannot inherit old request or old DTO', () async {
    await watcher.watch('request');
    source.login('other');
    expect(watcher.payment, isNull);
    expect(watcher.requestId, isNull);
    source.row = dto(request: 'other-request');
    await watcher.watch('other-request');
    expect(watcher.payment!.requestId, 'other-request');
    expect(source.maximumActive, 1);
  });
  test(
    'late response from previous user cannot repopulate cleared payment',
    () async {
      final late = Completer<Map<String, dynamic>?>();
      source.loader = (_) => late.future;
      final pending = watcher.watch('request');
      await flush();
      source.login('other');
      late.complete(dto(version: '3', status: 'paid'));
      await pending;
      expect(watcher.payment, isNull);
      expect(watcher.requestId, isNull);
    },
  );
  test(
    'request switch cancels old channel and ignores late response',
    () async {
      await watcher.watch('request');
      final late = Completer<Map<String, dynamic>?>();
      source.loader = (id) =>
          id == 'request' ? late.future : Future.value(dto(request: id));
      final pending = watcher.refresh();
      await watcher.watch('next');
      late.complete(dto(version: '99', status: 'paid'));
      await pending;
      expect(watcher.payment!.requestId, 'next');
      expect(source.removed, 1);
      expect(source.maximumActive, 1);
    },
  );
  test('repeated watch same request never duplicates subscription', () async {
    await watcher.watch('request');
    await Future.wait([watcher.watch('request'), watcher.watch('request')]);
    expect(source.requests, ['request']);
    expect(source.maximumActive, 1);
  });
  test('unrelated invalidation ignored', () async {
    await watcher.watch('request');
    final before = source.reads;
    source.emit(PaymentSignalKind.changed, request: 'another');
    await flush();
    expect(source.reads, before);
  });
  test('auth/RLS denial clears stale sensitive snapshot', () async {
    await watcher.watch('request');
    source.failure = const PaymentAccessDenied();
    await watcher.refresh();
    expect(watcher.payment, isNull);
    expect(watcher.error, 'PAYMENT_NOT_ACCESSIBLE');
  });
  test(
    'network failure retains same-user snapshot and never fabricates paid',
    () async {
      await watcher.watch('request');
      source.failure = TimeoutException('offline');
      await watcher.refresh();
      expect(watcher.payment!.status, 'pending');
      expect(watcher.stale, isTrue);
      expect(watcher.error, 'PAYMENT_REFRESH_FAILED');
    },
  );
  test(
    'same-user auth restoration refetches without duplicate channel',
    () async {
      await watcher.watch('request');
      source.row = dto(version: '3', status: 'paid');
      source.login('owner');
      await flush();
      expect(watcher.payment!.status, 'paid');
      expect(source.requests, hasLength(1));
    },
  );
  test('event during fetch schedules another authoritative read', () async {
    await watcher.watch('request');
    final late = Completer<Map<String, dynamic>?>();
    var n = 0;
    source.loader = (_) => ++n == 1
        ? late.future
        : Future.value(dto(version: '3', status: 'paid'));
    final pending = watcher.refresh();
    source.emit(PaymentSignalKind.changed);
    await flush();
    late.complete(dto(version: '2', status: 'awaiting_payment'));
    await pending;
    expect(n, 2);
    expect(watcher.payment!.status, 'paid');
  });
  test('wrong request DTO fails closed', () async {
    await watcher.watch('request');
    source.row = dto(request: 'another', version: '9', status: 'paid');
    await watcher.refresh();
    expect(watcher.payment, isNull);
    expect(watcher.error, 'PAYMENT_NOT_ACCESSIBLE');
  });
  test('RPC service uses getter only, JWT and request selector', () async {
    final calls = <http.Request>[];
    final client = await clientFor((request) async {
      calls.add(request);
      return response(dto());
    });
    final payment = await SupabasePaymentSource(client).load('request');
    expect(payment!['status'], 'pending');
    expect(calls, hasLength(1));
    expect(calls.single.url.path, '/rest/v1/rpc/rescuer_get_job_payment');
    expect(jsonDecode(calls.single.body), {'p_request_id': 'request'});
    expect(calls.single.headers['authorization'], 'Bearer payment-test-token');
  });
  test('RPC absence/denial clears via documented getter contract', () async {
    final client = await clientFor(
      (_) async =>
          response({'code': '42501', 'message': 'PAYMENT_NOT_ACCESSIBLE'}, 403),
    );
    expect(
      SupabasePaymentSource(client).load('request'),
      throwsA(isA<PaymentAccessDenied>()),
    );
  });
  test(
    'real service channel filters payments only and raw paid is not trusted',
    () async {
      var reads = 0;
      final client = await clientFor((_) async {
        reads++;
        return response(dto());
      });
      final live = PaymentWatcher(SupabasePaymentSource(client));
      addTearDown(live.dispose);
      await live.watch('request');
      final channel = client.created.single;
      expect(channel.registrations.map((r) => r.event), [
        PostgresChangeEvent.insert,
        PostgresChangeEvent.update,
      ]);
      for (final registration in channel.registrations) {
        expect(registration.schema, 'public');
        expect(registration.table, 'payments');
        expect(registration.filter!.column, 'request_id');
        expect(registration.filter!.value, 'request');
      }
      final before = reads;
      channel.row({
        'request_id': 'another',
        'rescuer_id': 'owner',
        'status': 'paid',
        'version': '9',
      });
      channel.row({
        'request_id': 'request',
        'rescuer_id': 'another',
        'status': 'paid',
        'version': '9',
      });
      await flush();
      expect(reads, before);
      channel.row({
        'request_id': 'request',
        'rescuer_id': 'owner',
        'status': 'paid',
        'version': 'broken',
      });
      await flush();
      expect(reads, before + 1);
      expect(live.payment!.status, 'pending');
      channel.status!(RealtimeSubscribeStatus.subscribed, null);
      await flush();
      expect(reads, before + 2);
      live.clear();
      await flush();
      expect(client.removed, 1);
    },
  );

  test('refresh listener reentry shares one task and never recurses', () async {
    await watcher.watch('request');
    Future<void>? nested;
    var entered = false;
    watcher.addListener(() {
      if (watcher.loading && !entered) {
        entered = true;
        nested = watcher.refresh();
      }
    });
    final before = source.reads;
    final pending = watcher.refresh();
    await pending;
    expect(nested, same(pending));
    expect(source.reads, before + 1);
    expect(watcher.loading, isFalse);
  });

  test(
    'clear during loading notification cannot poison the next watch',
    () async {
      var cleared = false;
      watcher.addListener(() {
        if (watcher.loading && !cleared) {
          cleared = true;
          watcher.clear();
        }
      });
      await watcher.watch('request');
      expect(source.reads, 0);
      expect(watcher.requestId, isNull);
      source.row = dto(request: 'next');
      await watcher.watch('next');
      expect(watcher.payment!.requestId, 'next');
      expect(source.maximumActive, 1);
    },
  );

  test(
    'failed event refetch retries even while websocket stays connected',
    () async {
      await watcher.watch('request');
      source.emit(PaymentSignalKind.connected);
      await flush();
      source.failure = TimeoutException('RPC offline');
      source.emit(PaymentSignalKind.changed);
      await flush();
      expect(watcher.error, 'PAYMENT_REFRESH_FAILED');
      source.failure = null;
      source.row = dto(version: '3', status: 'paid');
      await Future<void>.delayed(const Duration(milliseconds: 3100));
      await flush();
      expect(watcher.payment!.status, 'paid');
      expect(watcher.stale, isFalse);
      expect(watcher.error, isNull);
      expect(source.requests, hasLength(1));
    },
  );

  test(
    'background suspends reconnect and refetch retries until resume',
    () async {
      await watcher.watch('request');
      source.failure = TimeoutException('offline');
      source.emit(PaymentSignalKind.disconnected);
      await watcher.refresh();
      watcher.setForeground(false);
      final reads = source.reads;
      source.failure = null;
      source.row = dto(version: '3', status: 'paid');
      source.emit(PaymentSignalKind.changed);
      await Future<void>.delayed(const Duration(milliseconds: 3100));
      await flush();
      expect(source.reads, reads);
      expect(source.requests, hasLength(1));
      watcher.setForeground(true);
      await flush();
      expect(watcher.payment!.status, 'paid');
      source.emit(PaymentSignalKind.connected);
      await flush();
      expect(watcher.stale, isFalse);
    },
  );

  test('logout cancels pending reconnect and refetch timers', () async {
    await watcher.watch('request');
    source.failure = TimeoutException('offline');
    source.emit(PaymentSignalKind.disconnected);
    await watcher.refresh();
    source.login(null);
    final reads = source.reads;
    await Future<void>.delayed(const Duration(milliseconds: 3100));
    await flush();
    expect(source.reads, reads);
    expect(source.requests, hasLength(1));
    expect(source.active, 0);
    expect(watcher.payment, isNull);
    expect(watcher.loading, isFalse);
  });

  test('rapid request switches retain only the latest scope', () async {
    source.loader = (id) async => dto(request: id);
    await Future.wait([
      watcher.watch('first'),
      watcher.watch('second'),
      watcher.watch('third'),
    ]);
    expect(watcher.requestId, 'third');
    expect(watcher.payment!.requestId, 'third');
    expect(source.maximumActive, 1);
    expect(source.active, 1);
  });

  test('authoritative absence clears a previously cached payment', () async {
    await watcher.watch('request');
    source.row = null;
    await watcher.refresh();
    expect(watcher.payment, isNull);
    expect(watcher.error, isNull);
  });
  test('closed channel is removed before timed reconnect', () async {
    await watcher.watch('request');
    source.emit(PaymentSignalKind.disconnected);
    await flush();
    await Future<void>.delayed(const Duration(milliseconds: 3100));
    await flush();
    expect(source.requests, hasLength(2));
    expect(source.removed, 1);
    expect(source.maximumActive, 1);
    source.row = dto(version: '3', status: 'paid');
    source.emit(PaymentSignalKind.connected);
    await flush();
    expect(watcher.payment!.status, 'paid');
  });
  test('dispose cancels channel and ignores in-flight response', () async {
    final localSource = FakePayments();
    final local = PaymentWatcher(localSource);
    final gate = Completer<Map<String, dynamic>?>();
    localSource.loader = (_) => gate.future;
    final pending = local.watch('request');
    await flush();
    local.dispose();
    gate.complete(dto(status: 'paid', version: '3'));
    await pending;
    await flush();
    expect(local.payment, isNull);
    expect(localSource.active, 0);
    await localSource.close();
  });

  test(
    'RescuerController reads completed history offline with unavailable GPS',
    () async {
      final jobs = FinanceFake()
        ..state = 'completed'
        ..version = 5
        ..quoteId = 'quote'
        ..total = 100000;
      final c = RescuerController(
        jobs,
        FakeLocation()..failure = Exception('GPS offline'),
        paymentSource: source,
      );
      addTearDown(() async {
        c.dispose();
        await jobs.changes.close();
      });
      c.start();
      await flush();
      await c.loadHistoryDetail('assignment');
      await flush();
      expect(c.historyDetail!.assignment.state, 'completed');
      expect(c.payments.payment!.requestId, 'request');
      c.online = false;
      source.row = dto(version: '3', status: 'paid');
      c.setForeground(false);
      c.setForeground(true);
      await flush();
      expect(c.payments.payment!.status, 'paid');
      await c.signOut();
      expect(c.payments.payment, isNull);
    },
  );
}
