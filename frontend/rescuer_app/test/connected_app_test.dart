import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:rescuer/app/connected_app.dart';
import 'package:rescuer/app/rescuer_controller.dart';
import 'package:rescuer/models/backend_models.dart';
import 'package:rescuer/services/location_service.dart';
import 'package:rescuer/services/rescuer_service.dart';
import 'package:rescuer/services/supabase_config.dart';
import 'package:rescuer/services/document_picker.dart';

class FakeLocation implements LocationService {
  Object? failure;
  @override
  Future<bool> openSettings({bool gps = false}) async => true;
  @override
  Future<LocationSample> current() async {
    if (failure != null) throw failure!;
    return LocationSample(10.77, 106.69, 10, DateTime.now().toUtc());
  }
}

class FakeService implements RescuerService {
  @override
  Future<HistoryPage> history({Json? cursor}) async =>
      const HistoryPage([], null);
  @override
  Future<HistoryJob> historyJob(String assignmentId) async =>
      throw const RescuerFailure('Chưa có lịch sử.');
  @override
  Future<ActiveJob?> getActiveJob() async => null;
  @override
  String? userId;
  final changes = StreamController<String?>.broadcast(sync: true);
  @override
  Stream<String?> get authChanges => changes.stream;
  RescuerSnapshot snapshot = const RescuerSnapshot();
  RequestPage page = const RequestPage([], null);
  Object? readFailure, feedFailure;
  Completer<RequestPage>? pendingFeed;
  final List<(String, Json)> calls = [];
  Object? mutationFailure;
  String? failedMutation;
  @override
  Future<void> uploadDocument(
    String type,
    String? vehicleId,
    Uint8List bytes,
    String mime,
  ) async {
    calls.add((
      'upload_document',
      {
        'type': type,
        'vehicle_id': vehicleId,
        'size': bytes.length,
        'mime': mime,
      },
    ));
  }

  @override
  Future<void> signIn(String email, String password) async {
    userId = 'rescuer';
    changes.add(userId);
  }

  @override
  Future<void> signOut() async {
    userId = null;
    changes.add(null);
  }

  @override
  Future<RescuerSnapshot> loadSnapshot() async {
    if (readFailure != null) throw readFailure!;
    return snapshot;
  }

  @override
  Future<Json> mutate(String name, Json params) async {
    calls.add((name, params));
    if (name == failedMutation && mutationFailure != null) {
      throw mutationFailure!;
    }
    if (name == 'rescuer_set_online') {
      return {'is_online': params['p_online'], 'session_id': 'session'};
    }
    if (name == 'rescuer_update_location') {
      return {'sequence': params['p_sequence']};
    }
    return {};
  }

  @override
  Future<RequestPage> available(String vehicleId, {Json? cursor}) async {
    calls.add((
      'rescuer_list_available_requests',
      {'vehicle_id': vehicleId, 'cursor': cursor},
    ));
    if (feedFailure != null) throw feedFailure!;
    if (pendingFeed != null) return pendingFeed!.future;
    return page;
  }
}

RescuerSnapshot approved() => const RescuerSnapshot(
  services: [
    {'code': 'tire', 'name': 'Vá lốp'},
    {'code': 'towing', 'name': 'Kéo xe'},
    {'code': 'battery', 'name': 'Kích bình'},
    {'code': 'fuel', 'name': 'Tiếp nhiên liệu'},
    {'code': 'other', 'name': 'Khác'},
  ],
  profile: {
    'full_name': 'Đối tác thử nghiệm',
    'contact_phone': '0900000001',
    'verification_status': 'approved',
    'version': 1,
  },
  vehicles: [
    {
      'id': 'vehicle',
      'display_name': 'Xe hỗ trợ',
      'license_plate': 'TEST01',
      'verification_status': 'approved',
      'is_active': true,
    },
  ],
  capabilities: [
    {
      'vehicle_id': 'vehicle',
      'verification_status': 'approved',
      'is_enabled': true,
    },
  ],
);

Future<void> mount(WidgetTester tester, RescuerController controller) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
  await tester.pumpWidget(ConnectedRescuerApp(controller: controller));
  await tester.pumpAndSettle();
}

void main() {
  test(
    'vehicle edit sends owner vehicle version and forces no approval fields',
    () async {
      final service = FakeService()
        ..userId = 'rescuer'
        ..snapshot = approved();
      final c = RescuerController(service, FakeLocation())..start();
      await Future<void>.delayed(Duration.zero);
      await c.updateVehicle(
        {'id': 'vehicle', 'version': 9},
        'tow_truck',
        ' Xe kéo ',
        '51-C 123.45',
        true,
      );
      expect(service.calls.single.$1, 'rescuer_update_vehicle');
      expect(service.calls.single.$2, {
        'p_vehicle_id': 'vehicle',
        'p_kind': 'tow_truck',
        'p_display_name': 'Xe kéo',
        'p_license_plate': '51C12345',
        'p_is_active': true,
        'p_expected_version': 9,
      });
      c.dispose();
      await service.changes.close();
    },
  );
  test('service selection preserves unchanged approval and writes only changed capability pairs', () async {
    final service = FakeService()
      ..userId = 'rescuer'
      ..snapshot = RescuerSnapshot(
        profile: approved().profile,
        vehicles: approved().vehicles,
        services: approved().services,
        capabilities: const [
          {
            'vehicle_id': 'vehicle',
            'service_code': 'tire',
            'customer_vehicle_kind': 'motorbike',
            'is_enabled': true,
            'verification_status': 'approved',
          },
          {
            'vehicle_id': 'vehicle',
            'service_code': 'fuel',
            'customer_vehicle_kind': 'motorbike',
            'is_enabled': true,
            'verification_status': 'approved',
          },
        ],
      );
    final c = RescuerController(service, FakeLocation())..start();
    await Future<void>.delayed(Duration.zero);
    await c.saveCapabilities('vehicle', 'motorbike', {'tire', 'battery'});
    expect(service.calls.length, 2);
    expect(
      service.calls.every((r) => r.$1 == 'rescuer_set_capability'),
      isTrue,
    );
    expect(service.calls.any((r) => r.$2['p_service_code'] == 'tire'), isFalse);
    expect(service.calls.first.$2, {
      'p_vehicle_id': 'vehicle',
      'p_service_code': 'battery',
      'p_customer_vehicle_kind': 'motorbike',
      'p_enabled': true,
    });
    expect(service.calls.last.$2['p_enabled'], false);
    await c.saveCapabilities('vehicle', 'motorbike', {'locksmith'});
    expect(c.error, contains('chưa được hỗ trợ'));
    expect(service.calls.length, 2);
    c.dispose();
    await service.changes.close();
  });
  test('failed GPS mutation compensates by turning session offline', () async {
    final service = FakeService()
      ..userId = 'rescuer'
      ..snapshot = approved()
      ..failedMutation = 'rescuer_update_location'
      ..mutationFailure = const PostgrestException(
        message: 'LOCATION_NOT_FRESH',
        code: 'P0001',
      );
    final c = RescuerController(service, FakeLocation())..start();
    await Future<void>.delayed(Duration.zero);
    await c.setOnline(true);
    expect(service.calls.map((r) => r.$1).toList(), [
      'rescuer_set_online',
      'rescuer_update_location',
      'rescuer_set_online',
    ]);
    expect(service.calls.last.$2['p_online'], false);
    expect(c.online, false);
    expect(c.locationReady, false);
    expect(c.requests, isEmpty);
    expect(c.error, contains('Vị trí'));
    expect(c.onlineRecoveryRequired, false);
    c.dispose();
    await service.changes.close();
  });
  test(
    'document picker verifies file signatures instead of trusting extension',
    () {
      expect(
        detectDocumentMime(Uint8List.fromList([0xff, 0xd8, 0xff, 1])),
        'image/jpeg',
      );
      expect(
        detectDocumentMime(Uint8List.fromList([0x25, 0x50, 0x44, 0x46, 0x2d])),
        'application/pdf',
      );
      expect(
        () => detectDocumentMime(Uint8List.fromList([1, 2, 3])),
        throwsA(isA<RescuerFailure>()),
      );
    },
  );
  testWidgets('GPS refusal offers settings dialog and no online mutation', (
    tester,
  ) async {
    final service = FakeService()
      ..userId = 'rescuer'
      ..snapshot = approved();
    final gps = FakeLocation()
      ..failure = const LocationFailure(
        'Chưa có quyền vị trí.',
        LocationHelp.permission,
      );
    final c = RescuerController(service, gps);
    await mount(tester, c);
    await c.setOnline(true);
    await tester.pumpAndSettle();
    expect(find.text('Cho phép vị trí'), findsOneWidget);
    expect(find.text('Mở Cài đặt'), findsOneWidget);
    expect(service.calls, isEmpty);
    await tester.tap(find.text('Để sau'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(const SizedBox());
    await service.changes.close();
  });
  testWidgets(
    'services UI shows requested services and disables catalog entries not supported',
    (tester) async {
      final service = FakeService()
        ..userId = 'rescuer'
        ..snapshot = approved();
      final c = RescuerController(service, FakeLocation());
      await mount(tester, c);
      c.openSection('services');
      await tester.pumpAndSettle();
      for (final label in [
        'Kéo xe',
        'Sửa tại chỗ',
        'Kích bình',
        'Vá/thay lốp',
        'Đổ xăng',
        'Mở khóa xe',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      final repair = find.ancestor(
        of: find.text('Sửa tại chỗ'),
        matching: find.byType(CheckboxListTile),
      );
      expect(tester.widget<CheckboxListTile>(repair).onChanged, isNull);
      expect(find.text('Lưu dịch vụ'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await service.changes.close();
    },
  );
  test('profile, vehicle and submission use server versions and allowlisted fields', () async {
    final service = FakeService()..userId = 'rescuer';
    final c = RescuerController(service, FakeLocation())..start();
    await Future<void>.delayed(Duration.zero);
    await c.saveProfile(' New Partner ', '0900000001');
    expect(service.calls.single.$1, 'rescuer_register_profile');
    expect(service.calls.single.$2, {
      'p_full_name': 'New Partner',
      'p_contact_phone': '0900000001',
    });
    service.snapshot = const RescuerSnapshot(
      profile: {
        'full_name': 'Partner',
        'contact_phone': '0900000001',
        'verification_status': 'draft',
        'version': 7,
      },
      vehicles: [
        {'id': 'vehicle', 'verification_status': 'draft', 'is_active': true},
      ],
      documents: [
        {
          'document_type': 'identity',
          'uploaded_at': '2026-01-01',
          'verification_status': 'submitted',
        },
        {
          'document_type': 'license',
          'uploaded_at': '2026-01-01',
          'verification_status': 'submitted',
        },
        {
          'document_type': 'vehicle_registration',
          'vehicle_id': 'vehicle',
          'uploaded_at': '2026-01-01',
          'verification_status': 'submitted',
        },
      ],
    );
    await c.refreshProfile();
    await c.saveProfile('Partner', '0900000001');
    expect(service.calls.last.$1, 'rescuer_update_profile');
    expect(service.calls.last.$2['p_expected_version'], 7);
    expect(service.calls.last.$2.containsKey('verification_status'), isFalse);
    await c.registerVehicle('service_motorbike', ' Test Bike ', '59-A1 123.45');
    expect(service.calls.last.$1, 'rescuer_register_vehicle');
    expect(service.calls.last.$2, {
      'p_kind': 'service_motorbike',
      'p_display_name': 'Test Bike',
      'p_license_plate': '59A112345',
    });
    await c.submitProfile();
    expect(service.calls.last.$1, 'rescuer_submit_profile');
    expect(service.calls.last.$2, {'p_expected_version': 7});
    c.dispose();
    await service.changes.close();
  });
  test('configuration rejects privileged JWT and server secret', () {
    String jwt(String role) =>
        'header.${base64Url.encode(utf8.encode(jsonEncode({'role': role})))}.signature';
    expect(
      SupabaseConfig('https://example.supabase.co', jwt('service_role')).error,
      isNotNull,
    );
    expect(
      const SupabaseConfig(
        'https://example.supabase.co',
        'sb_secret_abc',
      ).error,
      isNotNull,
    );
    expect(
      SupabaseConfig('https://example.supabase.co', jwt('anon')).error,
      isNull,
    );
  });
  testWidgets(
    'signed out users see login; signed in users without profile can create it',
    (tester) async {
      final service = FakeService();
      final c = RescuerController(service, FakeLocation());
      await mount(tester, c);
      expect(find.text('Đăng nhập đối tác'), findsOneWidget);
      expect(find.text('Đơn mới'), findsNothing);
      await c.signIn('test@example.invalid', 'password');
      await tester.pumpAndSettle();
      expect(find.text('Tạo hồ sơ người cứu hộ'), findsOneWidget);
      expect(find.text('Tạo hồ sơ'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await service.changes.close();
    },
  );
  testWidgets('pending profile cannot turn online', (tester) async {
    final service = FakeService()
      ..userId = 'rescuer'
      ..snapshot = const RescuerSnapshot(
        profile: {
          'full_name': 'Test',
          'verification_status': 'submitted',
          'version': 1,
        },
      );
    final c = RescuerController(service, FakeLocation());
    await mount(tester, c);
    expect(find.text('Đang chờ duyệt'), findsOneWidget);
    await tester.scrollUntilVisible(find.byType(SwitchListTile), 400);
    expect(
      tester.widget<SwitchListTile>(find.byType(SwitchListTile)).onChanged,
      isNull,
    );
    await c.setOnline(true);
    expect(service.calls, isEmpty);
    await tester.pumpWidget(const SizedBox());
    await service.changes.close();
  });
  testWidgets(
    'RLS load failure shows retry instead of treating error as missing profile',
    (tester) async {
      final service = FakeService()
        ..userId = 'rescuer'
        ..readFailure = const PostgrestException(
          message: 'permission denied',
          code: '42501',
        );
      final c = RescuerController(service, FakeLocation());
      await mount(tester, c);
      expect(find.textContaining('RLS/quyền RPC'), findsOneWidget);
      expect(find.text('Thử tải lại hồ sơ'), findsOneWidget);
      expect(find.text('Tạo hồ sơ'), findsNothing);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await service.changes.close();
    },
  );
  testWidgets(
    'online sends GPS before discovery and empty RPC shows empty state',
    (tester) async {
      final service = FakeService()
        ..userId = 'rescuer'
        ..snapshot = approved();
      final c = RescuerController(service, FakeLocation());
      await mount(tester, c);
      await c.setOnline(true);
      await tester.pumpAndSettle();
      expect(service.calls.map((e) => e.$1).toList(), [
        'rescuer_set_online',
        'rescuer_update_location',
        'rescuer_list_available_requests',
      ]);
      expect(service.calls[1].$2['p_session_id'], 'session');
      c.selectTab(1);
      await tester.pumpAndSettle();
      expect(find.text('Chưa có đơn mới phù hợp'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await service.changes.close();
    },
  );
  testWidgets('denied GPS does not turn online or fetch requests', (
    tester,
  ) async {
    final service = FakeService()
      ..userId = 'rescuer'
      ..snapshot = approved();
    final gps = FakeLocation()
      ..failure = const RescuerFailure('Chưa có quyền vị trí.');
    final c = RescuerController(service, gps);
    await mount(tester, c);
    await c.setOnline(true);
    await tester.pumpAndSettle();
    expect(c.online, isFalse);
    expect(service.calls, isEmpty);
    expect(find.text('Chưa có quyền vị trí.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await service.changes.close();
  });
  testWidgets('feed errors clear stale cards; preclaim ignores all extra PII', (
    tester,
  ) async {
    final safe = AvailableRequest.fromJson({
      'request_id': 'r',
      'service_type': 'tire',
      'vehicle_type': 'motorbike',
      'approximate_location': {
        'latitude': 10.775,
        'longitude': 106.695,
        'cell_size_degrees': 0.01,
        'precision': 'coarse',
      },
      'estimated_distance_km': 2,
      'contact_name': 'SECRET CUSTOMER',
      'contact_phone': 'SECRET PHONE',
      'location_text': 'SECRET ADDRESS',
      'description': 'SECRET DESCRIPTION',
    });
    final service = FakeService()
      ..userId = 'rescuer'
      ..snapshot = approved()
      ..page = RequestPage([safe], null);
    final c = RescuerController(service, FakeLocation());
    await mount(tester, c);
    await c.setOnline(true);
    c.selectTab(1);
    await tester.pumpAndSettle();
    expect(find.text('Vá/thay lốp'), findsOneWidget);
    expect(find.textContaining('SECRET'), findsNothing);
    expect(find.text('Nhận đơn'), findsOneWidget);
    service.feedFailure = const PostgrestException(
      message: 'permission denied',
      code: '42501',
    );
    await c.refreshRequests();
    await tester.pumpAndSettle();
    expect(c.feedStatus, FeedStatus.error);
    expect(c.requests, isEmpty);
    expect(find.text('Vá/thay lốp'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await service.changes.close();
  });
  testWidgets('late response cannot restore data after sign out event', (
    tester,
  ) async {
    final service = FakeService()
      ..userId = 'rescuer'
      ..snapshot = approved();
    final c = RescuerController(service, FakeLocation());
    await mount(tester, c);
    await c.setOnline(true);
    service.pendingFeed = Completer<RequestPage>();
    final pending = c.refreshRequests();
    await tester.pump();
    service.userId = null;
    service.changes.add(null);
    await tester.pump();
    service.pendingFeed!.complete(
      const RequestPage([
        AvailableRequest(
          id: 'late',
          service: 'tire',
          vehicle: 'car',
          latitude: 10,
          longitude: 106,
          distanceKm: 1,
        ),
      ], null),
    );
    await pending;
    await tester.pumpAndSettle();
    expect(c.requests, isEmpty);
    expect(c.signedIn, isFalse);
    expect(find.text('Đăng nhập đối tác'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await service.changes.close();
  });
}
