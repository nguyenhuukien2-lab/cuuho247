import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../app/user_session.dart';
import '../services/location_service.dart';
import '../widgets/booking_ui.dart';
import '../widgets/customer_ui.dart';
import '../widgets/home_ui.dart';

class NewHomeScreen extends StatefulWidget {
  const NewHomeScreen(
      {super.key,
      required this.controller,
      this.locationService = const GeolocatorLocationService()});
  final AppController controller;
  final CustomerLocationService locationService;
  @override
  State<NewHomeScreen> createState() => _NewHomeScreenState();
}

class _NewHomeScreenState extends State<NewHomeScreen> {
  LocationResult? _location;
  bool _locating = false;
  Future<void> _refreshLocation() async {
    if (_locating) return;
    final userId = UserSession.userId;
    setState(() => _locating = true);
    LocationResult result;
    try {
      result = await widget.locationService.getCurrentLocation();
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
            color: BookingStyle.background,
            child: Column(children: [
              CustomerAppHeader(onAccount: () => controller.selectTab(4)),
              Expanded(
                  child: ListView(
                      key: const PageStorageKey('home-scroll'),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                      children: [
                    HomeGreetingLocation(
                        name: displayCustomerName(UserSession.fullName),
                        location: _location,
                        loading: _locating,
                        onRefresh: _refreshLocation),
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
                    if (active != null && !active.stage.isTerminal) ...[
                      const SizedBox(height: 16),
                      ActiveOrderBanner(
                          request: active,
                          onTrack: () => controller.selectTab(2))
                    ],
                    const SizedBox(height: 16),
                    EmergencyHeroCard(onRequest: controller.startRequest),
                    const SizedBox(height: 24),
                    HomeServiceGrid(
                        onSelected: (service) =>
                            controller.startRequest(service: service)),
                    const SizedBox(height: 24),
                    const TrustCommitmentCard(),
                    const SizedBox(height: 24),
                    const SafetyTipsCarousel(),
                  ])),
            ])));
  }
}
