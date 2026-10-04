import 'dart:async';

import 'package:cuu_ho_247/app/app_controller.dart';
import 'package:cuu_ho_247/app/app_shell.dart';
import 'package:cuu_ho_247/app/app_theme.dart';
import 'package:cuu_ho_247/app/navigation.dart';
import 'package:cuu_ho_247/app/user_session.dart';
import 'package:cuu_ho_247/screens/new_tracking_screen.dart';
import 'package:cuu_ho_247/services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

RescueRequestData request(RequestStage stage,
        {String id = 'request-a',
        int tick = 0,
        double? latitude,
        double? longitude}) =>
    RescueRequestData(
        id: id,
        service: RescueService.tire,
        vehicle: VehicleKind.car,
        address: 'Địa chỉ kiểm thử',
        createdAt: DateTime.utc(2026, 10, 1),
        updatedAt: DateTime.utc(2026, 10, 1, 0, 0, tick),
        latitude: latitude,
        longitude: longitude,
        stage: stage);

class TrackingController extends AppController {
  final streams = <StreamController<RescueRequestData>>[];
  final watchedIds = <String>[];
  int cancellations = 0;
  @override
  bool get backendConfigured => true;

  @override
  Stream<RescueRequestData> watchRequest(String requestId) {
    watchedIds.add(requestId);
    final stream =
        StreamController<RescueRequestData>(onCancel: () => cancellations++);
    streams.add(stream);
    return stream.stream;
  }

  void replaceRequest(RescueRequestData value) {
    activeRequest = value;
    notifyListeners();
  }

  void simulateLogout() {
    UserSession.clear();
    activeRequest = null;
    history = [];
    notifyListeners();
  }

  @override
  void dispose() {
    for (final stream in streams) {
      unawaited(stream.close());
    }
    super.dispose();
  }
}

void main() {
  setUp(() => UserSession.userId = 'customer-a');
  tearDown(UserSession.clear);

  testWidgets('tracking displays saved coordinates and manual-only fallback',
      (tester) async {
    final controller = TrackingController()
      ..activeRequest =
          request(RequestStage.searching, latitude: 0, longitude: 106.7);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: NewTrackingScreen(controller: controller))));
    await tester.scrollUntilVisible(
        find.text('Tọa độ: 0.000000, 106.700000'), 250,
        scrollable: find.byType(Scrollable).first, continuous: true);
    expect(find.text('Tọa độ: 0.000000, 106.700000'), findsOneWidget);
    controller.replaceRequest(request(RequestStage.searching, id: 'manual'));
    await tester.pump();
    expect(find.text('Yêu cầu sử dụng địa chỉ nhập tay, chưa có tọa độ.'),
        findsOneWidget);
    expect(find.textContaining('Tọa độ:'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  test('maps all six database statuses and nullable coordinates', () {
    for (final stage in RequestStage.values) {
      final data = RescueRequestData.fromJson({
        'id': 'request-a',
        'service_code': 'tire',
        'vehicle_kind': 'car',
        'location_text': 'Test',
        'created_at': '2026-10-01T00:00:00Z',
        'updated_at': '2026-10-01T00:01:00Z',
        'status': stage.databaseValue,
        'latitude': stage == RequestStage.searching ? null : 10,
        'longitude': stage == RequestStage.searching ? null : 106.5,
      });
      expect(data.stage, stage);
      expect(data.latitude, stage == RequestStage.searching ? null : 10.0);
      expect(data.longitude, stage == RequestStage.searching ? null : 106.5);
      expect(data.updatedAt.isAfter(data.createdAt), isTrue);
    }
  });

  test('ignores stale or unrelated updates and deduplicates terminal history',
      () {
    final controller = TrackingController()
      ..activeRequest = request(RequestStage.arriving, tick: 3)
      ..tabIndex = 2;
    controller.applyTrackingUpdate(request(RequestStage.accepted, tick: 2));
    controller.applyTrackingUpdate(
        request(RequestStage.completed, id: 'other', tick: 4));
    expect(controller.activeRequest!.stage, RequestStage.arriving);
    controller.applyTrackingUpdate(request(RequestStage.completed, tick: 5));
    controller.applyTrackingUpdate(request(RequestStage.completed, tick: 5));
    expect(controller.activeRequest, isNull);
    expect(controller.history, hasLength(1));
    expect(controller.tabIndex, 3);
    controller.dispose();
  });

  testWidgets(
      'Realtime updates UI, swaps requests, and stops at terminal state',
      (tester) async {
    tester.view.physicalSize = const Size(520, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final controller = TrackingController()
      ..activeRequest = request(RequestStage.searching);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: NewTrackingScreen(controller: controller))));
    expect(controller.watchedIds, ['request-a']);
    controller.streams.last.add(request(RequestStage.inProgress, tick: 2));
    await tester.pump();
    expect(find.text('Đối tác đang hỗ trợ'), findsWidgets);
    controller.replaceRequest(request(RequestStage.accepted, id: 'request-b'));
    await tester.pump();
    expect(controller.watchedIds, ['request-a', 'request-b']);
    expect(controller.cancellations, 1);
    controller.streams.last
        .add(request(RequestStage.cancelled, id: 'request-b', tick: 3));
    await tester.pump();
    expect(controller.activeRequest, isNull);
    expect(controller.history.single.stage, RequestStage.cancelled);
    expect(controller.cancellations, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('IndexedStack cancels on tab exit and resubscribes on return',
      (tester) async {
    final controller = TrackingController()
      ..restoringSession = false
      ..tabIndex = 2
      ..activeRequest = request(RequestStage.searching);
    await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light, home: AppShell(controller: controller)));
    expect(controller.streams, hasLength(1));
    controller.selectTab(0);
    await tester.pump();
    expect(controller.cancellations, 1);
    controller.selectTab(2);
    await tester.pump();
    expect(controller.streams, hasLength(2));
    controller.simulateLogout();
    await tester.pump();
    expect(controller.cancellations, 2);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('route coverage and disposal remove subscriptions',
      (tester) async {
    final controller = TrackingController()
      ..activeRequest = request(RequestStage.searching);
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [customerRouteObserver],
        home: Scaffold(body: NewTrackingScreen(controller: controller))));
    navigator.currentState!.push(MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('Other page'))));
    await tester.pump();
    expect(controller.cancellations, 1);
    navigator.currentState!.pop();
    await tester.pump();
    expect(controller.streams, hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(controller.cancellations, 2);
    controller.dispose();
  });

  testWidgets('background stops tracking and resume opens a fresh subscription',
      (tester) async {
    final controller = TrackingController()
      ..activeRequest = request(RequestStage.searching);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: NewTrackingScreen(controller: controller))));
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(controller.cancellations, 1);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(controller.streams, hasLength(2));
    controller.streams.first.add(request(RequestStage.completed, tick: 3));
    await tester.pump();
    expect(controller.activeRequest!.stage, RequestStage.searching);
    controller.streams.last.add(request(RequestStage.arriving, tick: 2));
    await tester.pump();
    expect(controller.activeRequest!.stage, RequestStage.arriving);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets('connection errors are visible and retry replaces the stream',
      (tester) async {
    final controller = TrackingController()
      ..activeRequest = request(RequestStage.searching);
    await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: NewTrackingScreen(controller: controller))));
    controller.streams.last
        .addError(const AppFailure('Mất kết nối thử nghiệm'));
    await tester.pump();
    expect(find.text('Mất kết nối thử nghiệm'), findsOneWidget);
    await tester.tap(find.text('Kết nối lại'));
    await tester.pump();
    expect(controller.cancellations, 1);
    expect(controller.streams, hasLength(2));
    expect(find.text('Mất kết nối thử nghiệm'), findsNothing);
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });
}
