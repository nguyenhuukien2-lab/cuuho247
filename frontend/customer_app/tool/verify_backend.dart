// Explicit opt-in integration checks against a DEVELOPMENT Supabase project.
// No credentials or response bodies are logged. Requires two dedicated accounts.
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:http/http.dart' as http;

String uuid() {
  final random = Random.secure();
  final bytes = List.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final h = bytes.map((v) => v.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

void check(bool condition, String label) {
  if (!condition) {
    stdout.writeln('LOI: $label (response details redacted)');
    throw StateError(label);
  }
  stdout.writeln('DAT: $label');
}

Future<void> main(List<String> args) async {
  final client = http.Client();
  try {
    if (args.length != 2 ||
        !['--register-dev', '--verify-dev'].contains(args[0])) {
      stdout.writeln(
          'Usage: dart run tool/verify_backend.dart --register-dev|--verify-dev EXPECTED_PROJECT_REF');
      stdout.writeln(
          'Only run after development project identification and migration approval.');
      exitCode = 2;
      return;
    }
    final config =
        jsonDecode(await File('config/supabase.dev.json').readAsString())
            as Map;
    final accounts =
        jsonDecode(await File('config/backend-tests.dev.json').readAsString())
            as Map;
    final base = Uri.parse(config['SUPABASE_URL'] as String);
    final key = config['SUPABASE_PUBLISHABLE_KEY'] as String;
    check(
        base.scheme == 'https' &&
            base.host == '${args[1]}.supabase.co' &&
            key.isNotEmpty,
        'Development project matches explicit target');
    check(accounts['EMAIL_A'] != accounts['EMAIL_B'],
        'Separate test accounts A and B');

    Future<http.Response> api(String method, String path,
        {String? token, Object? body}) async {
      final request = http.Request(method, base.resolve(path));
      request.headers
          .addAll({'apikey': key, 'Content-Type': 'application/json'});
      if (path.contains('/rest/v1/rpc/')) {
        request.headers['Accept'] = 'application/vnd.pgrst.object+json';
      }
      if (token != null) request.headers['Authorization'] = 'Bearer $token';
      if (body != null) request.body = jsonEncode(body);
      return http.Response.fromStream(
              await client.send(request).timeout(const Duration(seconds: 30)))
          .timeout(const Duration(seconds: 30));
    }

    Map<String, dynamic> object(http.Response response) =>
        Map<String, dynamic>.from(jsonDecode(response.body) as Map);
    bool ok(http.Response response) =>
        response.statusCode >= 200 && response.statusCode < 300;
    bool denied(http.Response response) =>
        response.statusCode == 401 || response.statusCode == 403;

    if (args[0] == '--register-dev') {
      for (final name in ['A', 'B']) {
        final response = await api('POST', '/auth/v1/signup', body: {
          'email': accounts['EMAIL_$name'],
          'password': accounts['PASSWORD_$name'],
          'data': {
            'full_name': 'Dedicated development test $name',
            'phone': '0900000000'
          },
        });
        check(ok(response), 'Signup $name endpoint accepted');
        // A 2xx alone does not prove an existing email was newly registered.
        stdout.writeln(
            'CHUA XAC MINH: Confirm mailbox and new account creation for $name in dev Dashboard.');
      }
      return;
    }

    Future<Map<String, dynamic>> login(String name) async {
      final response =
          await api('POST', '/auth/v1/token?grant_type=password', body: {
        'email': accounts['EMAIL_$name'],
        'password': accounts['PASSWORD_$name'],
      });
      check(ok(response), 'Valid login $name');
      return object(response);
    }

    final a = await login('A');
    final b = await login('B');
    var tokenA = a['access_token'] as String;
    final tokenB = b['access_token'] as String;
    final wrong =
        await api('POST', '/auth/v1/token?grant_type=password', body: {
      'email': accounts['EMAIL_A'],
      'password': uuid(),
    });
    check(wrong.statusCode == 400 || wrong.statusCode == 401,
        'Wrong password rejected');

    final refresh = await api('POST', '/auth/v1/token?grant_type=refresh_token',
        body: {'refresh_token': a['refresh_token']});
    check(ok(refresh), 'Auth refresh token accepted (not an app restart test)');
    final refreshed = object(refresh);
    tokenA = refreshed['access_token'] as String;

    // Refuse to mutate accounts with existing requests, including old test runs.
    for (final entry in {'A': tokenA, 'B': tokenB}.entries) {
      final response = await api(
          'GET', '/rest/v1/rescue_requests?select=id&limit=1',
          token: entry.value);
      check(ok(response) && (jsonDecode(response.body) as List).isEmpty,
          'Account ${entry.key} has no existing requests');
    }
    Map<String, Object?> createBody(String requestKey,
            {double? latitude,
            double? longitude,
            bool sendCoordinates = true}) =>
        {
          'p_client_request_id': requestKey,
          'p_vehicle_kind': 'car',
          'p_service_code': 'tire',
          'p_location_text': 'DEVELOPMENT TEST - no dispatch',
          'p_description': 'Automated development test',
          'p_contact_name': 'Development test',
          'p_contact_phone': '0900000000',
          'p_vehicle_id': null,
          if (sendCoordinates) 'p_latitude': latitude,
          if (sendCoordinates) 'p_longitude': longitude,
        };

    Future<Map<String, dynamic>> create(String requestKey,
        {double? latitude,
        double? longitude,
        bool sendCoordinates = true}) async {
      final response = await api(
          'POST', '/rest/v1/rpc/create_customer_rescue_request',
          token: tokenA,
          body: createBody(requestKey,
              latitude: latitude,
              longitude: longitude,
              sendCoordinates: sendCoordinates));
      check(ok(response), 'Create RPC response');
      return object(response);
    }

    Future<http.Response> cancel(String id, String token) =>
        api('POST', '/rest/v1/rpc/cancel_own_rescue_request',
            token: token, body: {'request_id': id});

    final requestKey = uuid();
    final directInsert = await api('POST', '/rest/v1/rescue_requests',
        token: tokenA,
        body: {'customer_id': a['user']['id'], 'status': 'completed'});
    check(denied(directInsert), 'Direct insert cannot bypass create RPC');
    for (final coords in [(91.0, 106.0), (10.0, 181.0), (10.0, null)]) {
      final response = await api(
          'POST', '/rest/v1/rpc/create_customer_rescue_request',
          token: tokenA,
          body: createBody(uuid(), latitude: coords.$1, longitude: coords.$2));
      check(response.statusCode == 400 && object(response)['code'] == '22023',
          'Invalid/incomplete coordinates rejected');
    }
    final first =
        await create(requestKey, latitude: 10.7769, longitude: 106.7009);
    final id = first['id'] as String;
    check(
        first['customer_id'] == a['user']['id'] &&
            first['status'] == 'searching' &&
            first['provider_id'] == null,
        'Server owns identity and initial searching state');
    check(first['latitude'] == 10.7769 && first['longitude'] == 106.7009,
        'Coordinates persisted');
    final retried = await create(requestKey, latitude: 999, longitude: 999);
    check(retried['id'] == id, 'Same idempotency key returns same request');
    check(
        retried['latitude'] == first['latitude'] &&
            retried['longitude'] == first['longitude'],
        'Retry preserves original coordinates before validation');

    Future<List<dynamic>> timeline(String token) async {
      final response = await api('GET',
          '/rest/v1/request_status_events?request_id=eq.$id&select=status,previous_status&order=occurred_at.asc',
          token: token);
      check(ok(response), 'Timeline read accepted');
      return jsonDecode(response.body) as List;
    }

    final initialEvents = await timeline(tokenA);
    check(
        initialEvents.length == 1 &&
            initialEvents.single['status'] == 'searching',
        'Create and idempotent retry produce exactly one initial event');
    check((await timeline(tokenB)).isEmpty, 'B cannot read A timeline');
    final guestTimeline =
        await api('GET', '/rest/v1/request_status_events?select=id');
    check(denied(guestTimeline), 'Anonymous cannot read timeline');
    for (final method in ['POST', 'PATCH', 'DELETE']) {
      final response = await api(
          method, '/rest/v1/request_status_events?request_id=eq.$id',
          token: tokenA,
          body: method == 'DELETE'
              ? null
              : {'request_id': id, 'status': 'completed'});
      check(denied(response), 'Customer cannot $method timeline');
    }
    final reloaded = await api(
        'GET', '/rest/v1/rescue_requests?id=eq.$id&select=id,status',
        token: tokenA);
    check(ok(reloaded) && (jsonDecode(reloaded.body) as List).length == 1,
        'Owner reloads persisted request');

    final otherRead = await api(
        'GET', '/rest/v1/rescue_requests?id=eq.$id&select=id',
        token: tokenB);
    check(ok(otherRead) && (jsonDecode(otherRead.body) as List).isEmpty,
        'B cannot read A request via API');
    final otherWrite = await api('PATCH', '/rest/v1/rescue_requests?id=eq.$id',
        token: tokenB, body: {'description': 'unauthorized'});
    check(denied(otherWrite), 'B cannot edit A request via API');
    final otherCancel = await cancel(id, tokenB);
    check(!ok(otherCancel), 'B cannot cancel A request via RPC');
    for (final entry in <String, Object>{
      'status': 'completed',
      'customer_id': b['user']['id'],
      'provider_id': b['user']['id']
    }.entries) {
      final response = await api('PATCH', '/rest/v1/rescue_requests?id=eq.$id',
          token: tokenA, body: {entry.key: entry.value});
      check(denied(response), 'Customer cannot change ${entry.key} via API');
    }
    final cancelled = await cancel(id, tokenA);
    check(ok(cancelled) && object(cancelled)['status'] == 'cancelled',
        'Owner cancels searching request');
    check((await create(requestKey))['id'] == id,
        'Retry after cancellation still returns original request');
    check(!ok(await cancel(id, tokenA)),
        'Repeated cancellation of terminal request rejected');
    final events = await timeline(tokenA);
    check(
        events.length == 2 &&
            events.last['status'] == 'cancelled' &&
            events.last['previous_status'] == 'searching',
        'Cancellation records one transition; retries do not duplicate events');
    check((await timeline(tokenB)).isEmpty, 'B cannot read terminal timeline');

    final concurrent = await Future.wait(
        [create(uuid(), sendCoordinates: false), create(uuid())]);
    check(
        concurrent.every(
            (row) => row['latitude'] == null && row['longitude'] == null),
        'Omitted and null coordinates are backward compatible');
    check(
        concurrent[0]['id'] == concurrent[1]['id'] && concurrent[0]['id'] != id,
        'Concurrent submissions create one new active request');
    final count = await api('GET',
        '/rest/v1/rescue_requests?status=in.(searching,accepted,arriving,in_progress)&select=id',
        token: tokenA);
    check(ok(count) && (jsonDecode(count.body) as List).length == 1,
        'Exactly one active row in database');
    check(ok(await cancel(concurrent[0]['id'] as String, tokenA)),
        'Cancel only the new request created by this test');

    final logout = await api('POST', '/auth/v1/logout', token: tokenA);
    check(ok(logout), 'Logout accepted');
    final revoked = await api('POST', '/auth/v1/token?grant_type=refresh_token',
        body: {'refresh_token': refreshed['refresh_token']});
    check(!ok(revoked), 'Logged-out refresh token rejected');
    stdout.writeln(
        'Test rows retained for inspection; no remote records deleted.');
  } catch (_) {
    stderr.writeln(
        'Stopped: configuration, request or assertion failed. Sensitive details omitted.');
    exitCode = 1;
  } finally {
    client.close();
  }
}
