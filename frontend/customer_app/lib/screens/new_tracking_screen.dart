import '../app/mobile_ui.dart';
import 'dart:async';

import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/app_theme.dart';
import '../app/navigation.dart';
import '../app/user_session.dart';
import '../widgets/booking_ui.dart';
import '../widgets/tracking_ui.dart';
import '../widgets/customer_ui.dart';
import '../services/supabase_service.dart';

import '../widgets/request_photos_card.dart';
import '../services/request_photo_service.dart';

class NewTrackingScreen extends StatefulWidget {
  const NewTrackingScreen(
      {super.key,
      required this.controller,
      this.isActive = true,
      this.photoRepository = const SupabaseRequestPhotoRepository()});
  final AppController controller;
  final bool isActive;
  final RequestPhotoRepository photoRepository;

  @override
  State<NewTrackingScreen> createState() => _NewTrackingScreenState();
}

class _NewTrackingScreenState extends State<NewTrackingScreen>
    with RouteAware, WidgetsBindingObserver {
  AppController get controller => widget.controller;
  StreamSubscription<RescueRequestData>? _subscription;
  String? _requestId;
  String? _customerId;
  String? _streamError;
  bool cancelling = false;
  String? cancelError;
  int _generation = 0;
  bool _routeVisible = true;
  bool _foreground = true;
  PageRoute<dynamic>? _route;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    controller.addListener(_onControllerChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute && route != _route) {
      customerRouteObserver.unsubscribe(this);
      _route = route;
      _routeVisible = route.isCurrent;
      customerRouteObserver.subscribe(this, route);
    }
    _syncSubscription();
  }

  @override
  void didUpdateWidget(covariant NewTrackingScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != controller) {
      oldWidget.controller.removeListener(_onControllerChanged);
      _stopSubscription();
      controller.addListener(_onControllerChanged);
    }
    _syncSubscription();
  }

  void _onControllerChanged() {
    _syncSubscription();
    if (mounted) setState(() {});
  }

  void _stopSubscription() {
    _generation++;
    final subscription = _subscription;
    _subscription = null;
    _requestId = null;
    _customerId = null;
    _streamError = null;
    if (subscription != null) unawaited(subscription.cancel());
  }

  void _syncSubscription() {
    final id = widget.isActive &&
            _routeVisible &&
            _foreground &&
            controller.isLoggedIn &&
            controller.backendConfigured
        ? controller.activeRequest?.id
        : null;
    final customer = UserSession.userId;
    if (id == _requestId && customer == _customerId) return;
    _stopSubscription();
    if (id == null) return;
    _requestId = id;
    _customerId = customer;
    final generation = _generation;
    try {
      _subscription = controller.watchRequest(id).listen((request) {
        if (!mounted ||
            generation != _generation ||
            customer != UserSession.userId) return;
        _streamError = null;
        controller.applyTrackingUpdate(request);
      }, onError: (Object error) {
        if (!mounted || generation != _generation) return;
        setState(() => _streamError = error is AppFailure
            ? error.message
            : 'Không thể cập nhật trạng thái. Vui lòng thử lại.');
      });
    } on AppFailure catch (error) {
      _streamError = error.message;
    }
  }

  @override
  void didPushNext() {
    _routeVisible = false;
    _syncSubscription();
  }

  @override
  void didPopNext() {
    _routeVisible = true;
    _syncSubscription();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncSubscription();
  }

  @override
  void dispose() {
    controller.removeListener(_onControllerChanged);
    customerRouteObserver.unsubscribe(this);
    WidgetsBinding.instance.removeObserver(this);
    _stopSubscription();
    super.dispose();
  }

  Future<void> confirmCancel(BuildContext context) async {
    if (cancelling) return;
    final accepted = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
              icon: const Icon(Icons.warning_amber_rounded,
                  color: AppColors.warning),
              title: const Text('Hủy yêu cầu cứu hộ?'),
              content: const Text(
                  'Yêu cầu sẽ được chuyển vào lịch sử. Thao tác này không thể hoàn tác.'),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Giữ yêu cầu')),
                FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                        backgroundColor: AppColors.error),
                    child: const Text('Xác nhận hủy'))
              ],
            ));
    if (!mounted) return;
    if (accepted == true) {
      setState(() {
        cancelling = true;
        cancelError = null;
      });
      try {
        await controller.cancelActiveRequest();
      } on AppFailure catch (error) {
        if (!context.mounted) return;
        setState(() => cancelError = error.message);
      } finally {
        if (mounted) setState(() => cancelling = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) => Theme(
        data: BookingStyle.theme(context),
        child: Material(
            color: BookingStyle.background,
            child: Column(children: [
              CustomerAppHeader(onAccount: () => controller.selectTab(4)),
              Expanded(child: Builder(builder: _buildContent)),
            ])),
      );

  Widget _buildContent(BuildContext context) {
    final request = controller.activeRequest;
    if (controller.loadingRequests && request == null) {
      return const Center(
          child: SingleChildScrollView(
              child: RescueFeedback(
                  kind: RescueFeedbackKind.loading,
                  title: 'Đang tải yêu cầu',
                  message: 'Vui lòng chờ trong khi tải yêu cầu cứu hộ.')));
    }
    if (controller.loadError != null && request == null) {
      return SingleChildScrollView(
          padding: AppSpacing.page,
          child: CustomerEmptyState(
              kind: RescueFeedbackKind.error,
              icon: Icons.cloud_off_rounded,
              title: 'Chưa tải được yêu cầu',
              message: controller.loadError!,
              action: OutlinedButton.icon(
                  onPressed: controller.refreshRequests,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Thử lại'))));
    }
    if (request == null) {
      return SingleChildScrollView(
          padding: AppSpacing.page,
          child: CustomerEmptyState(
              icon: Icons.route_outlined,
              title: 'Bạn chưa có yêu cầu cứu hộ đang xử lý',
              message: 'Tạo yêu cầu mới để được hỗ trợ',
              action: PrimaryActionButton(
                  label: 'Tạo yêu cầu cứu hộ',
                  loading: false,
                  onPressed: controller.startRequest)));
    }
    return ListView(
        key: const PageStorageKey('tracking-scroll'),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: [
          TrackingStatusCard(
              request: request,
              action: RescueButton(
                  label: request.stage.isTerminal
                      ? 'Xem lịch sử yêu cầu'
                      : 'Cập nhật trạng thái',
                  icon: request.stage.isTerminal
                      ? Icons.history_rounded
                      : Icons.refresh_rounded,
                  loading: controller.loadingRequests,
                  onPressed: request.stage.isTerminal
                      ? () => controller.selectTab(3)
                      : controller.refreshRequests)),
          const SizedBox(height: 16),
          if (controller.loadingRequests) const LinearProgressIndicator(),
          if (_streamError != null) ...[
            InlineNotice(_streamError!,
                retryLabel: 'Kết nối lại',
                onRetry: () => setState(() {
                      _stopSubscription();
                      _syncSubscription();
                    })),
            const SizedBox(height: 16),
          ],
          if (controller.loadError != null) ...[
            InlineNotice(controller.loadError!,
                onRetry: controller.refreshRequests),
            const SizedBox(height: 16),
          ],
          TrackingOrderCard(request: request),
          const SizedBox(height: 16),
          TrackingTimeline(request: request),
          const SizedBox(height: 16),
          TrackingMapCard(request: request),
          const SizedBox(height: 16),
          MoreDetails(title: 'Liên hệ, mô tả & ảnh yêu cầu', children: [
            const SizedBox(height: 8),
            if (request.contactName.isNotEmpty)
              InfoRow('Liên hệ', displayCustomerName(request.contactName),
                  icon: Icons.person_outline),
            if (request.contactPhone.isNotEmpty)
              InfoRow('Điện thoại', request.contactPhone,
                  icon: Icons.phone_outlined),
            if (request.description.isNotEmpty)
              InfoRow('Mô tả', request.description),
            const SizedBox(height: 16),
            RequestPhotosCard(
                requestId: request.id,
                customerId: UserSession.userId,
                isActive: widget.isActive && _routeVisible && _foreground,
                repository: widget.photoRepository),
            const SizedBox(height: 16),
          ]),
          const SizedBox(height: 16),
          const EmergencySupportCard(),
          if (request.stage == RequestStage.searching ||
              request.stage == RequestStage.accepted) ...[
            const SizedBox(height: 8),
            if (cancelError != null)
              InlineNotice(cancelError!,
                  onRetry: cancelling ? null : () => confirmCancel(context)),
            TextButton.icon(
                onPressed: cancelling ? null : () => confirmCancel(context),
                icon: cancelling
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.close_rounded),
                label: Text(cancelling ? 'Đang hủy…' : 'Hủy yêu cầu'),
                style: RescueButtons.style(RescueButtonKind.danger)),
          ],
        ]);
  }
}
