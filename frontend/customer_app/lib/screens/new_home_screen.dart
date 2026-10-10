import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../app/user_session.dart';
import '../services/location_service.dart';
import '../widgets/booking_ui.dart';
import '../widgets/customer_ui.dart';
import '../widgets/home_ui.dart';

class NewHomeScreen extends StatefulWidget {
  const NewHomeScreen(
      {super.key, required this.controller, this.locationService});
  final AppController controller;
  final CustomerLocationService? locationService;
  @override
  State<NewHomeScreen> createState() => _NewHomeScreenState();
}

class _NewHomeScreenState extends State<NewHomeScreen> {
  LocationResult? _location;
  bool _locating = false;
  @override
  void initState() {
    super.initState();
    widget.controller.gps.addListener(_gpsChanged);
  }

  void _gpsChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.controller.gps.removeListener(_gpsChanged);
    super.dispose();
  }

  Future<void> _refreshLocation() async {
    if (_locating) return;
    final userId = UserSession.userId;
    setState(() => _locating = true);
    LocationResult result;
    try {
      result = await (widget.locationService?.getCurrentLocation() ??
          widget.controller.gps.refresh());
    } catch (_) {
      result = const LocationResult(LocationStatus.unavailable,
          'Không thể lấy vị trí. Vui lòng thử lại.');
    }
    if (!mounted || userId != UserSession.userId) return;
    setState(() {
      _location = result;
      _locating = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    final active = controller.activeRequest;
    return Theme(
        data: BookingStyle.theme(context),
        child: Material(
            color: HomeVisual.background,
            child: Column(children: [
              HomeAppHeader(
                  onAccount: () => controller.selectTab(4),
                  onRefresh: controller.loadingRequests
                      ? null
                      : controller.refreshRequests),
              Expanded(
                  child: ListView(
                      key: const PageStorageKey('home-scroll'),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 40),
                      children: [
                    if (controller.loadingRequests) ...[
                      const SizedBox(height: 16),
                      const LinearProgressIndicator()
                    ],
                    if (controller.loadError != null) ...[
                      const SizedBox(height: 16),
                      InlineNotice(controller.loadError!,
                          onRetry: controller.loadingRequests
                              ? null
                              : controller.refreshRequests)
                    ],
                    HomeGreetingLocation(
                        name: displayCustomerName(UserSession.fullName),
                        location: widget.locationService == null
                            ? controller.gps.result
                            : _location,
                        loading: _locating ||
                            (widget.locationService == null &&
                                controller.gps.loading),
                        selectedAddress:
                            active != null && !active.stage.isTerminal
                                ? active.address
                                : null,
                        selectedCoordinates: active != null &&
                                !active.stage.isTerminal &&
                                active.latitude != null &&
                                active.longitude != null
                            ? RescueCoordinates(
                                active.latitude!, active.longitude!)
                            : null,
                        onRefresh: _refreshLocation),
                    const SizedBox(height: 12),
                    if (active != null && !active.stage.isTerminal) ...[
                      ActiveOrderBanner(
                          request: active,
                          onTrack: () => controller.selectTab(2)),
                      const SizedBox(height: 18),
                    ],
                    EmergencyHeroCard(
                        hasActiveRequest:
                            active != null && !active.stage.isTerminal,
                        onRequest: controller.startRequest),
                    const SizedBox(height: 18),
                    HomeServiceGrid(
                        onSelected: (service) =>
                            controller.startRequest(service: service)),
                    const SizedBox(height: 18),
                    const TrustCommitmentCard(),
                    const SizedBox(height: 18),
                    const SafetyTipsCarousel(),
                  ])),
            ])));
  }
}
