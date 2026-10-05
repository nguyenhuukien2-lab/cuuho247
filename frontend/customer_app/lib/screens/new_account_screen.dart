import '../app/mobile_ui.dart';
import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../app/user_session.dart';
import '../widgets/customer_profile_card.dart';
import '../widgets/customer_ui.dart';
import '../widgets/booking_ui.dart';
import '../widgets/account_ui.dart';
import '../services/supabase_service.dart';
import '../services/customer_profile_service.dart';
import '../services/customer_vehicle_service.dart';
import '../services/customer_saved_address_service.dart';
import 'customer_vehicles_screen.dart';
import 'customer_saved_addresses_screen.dart';

class NewAccountScreen extends StatefulWidget {
  const NewAccountScreen(
      {super.key,
      required this.controller,
      this.profileRepository = const SupabaseCustomerProfileRepository(),
      this.vehicleRepository = const SupabaseCustomerVehicleRepository(),
      this.addressRepository = const SupabaseCustomerSavedAddressRepository()});
  final AppController controller;
  final CustomerProfileRepository profileRepository;
  final CustomerVehicleRepository vehicleRepository;
  final CustomerSavedAddressRepository addressRepository;
  @override
  State<NewAccountScreen> createState() => _NewAccountScreenState();
}

class _NewAccountScreenState extends State<NewAccountScreen> {
  bool signingOut = false;
  String? error;
  List<CustomerVehicle> vehicles = [];
  List<CustomerSavedAddress> addresses = [];
  bool loadingVehicles = false,
      loadingAddresses = false,
      vehiclesLoaded = false,
      addressesLoaded = false;
  String? vehicleError, addressError, owner;
  int vehicleGeneration = 0, addressGeneration = 0;
  late int vehiclesRevision;

  @override
  void initState() {
    super.initState();
    owner = UserSession.userId;
    vehiclesRevision = widget.controller.vehiclesRevision;
    widget.controller.addListener(_changed);
    if (owner != null) {
      _loadVehicles();
      _loadAddresses();
    }
  }

  @override
  void dispose() {
    vehicleGeneration++;
    addressGeneration++;
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() {
    if (!mounted) return;
    if (owner != UserSession.userId) {
      vehicleGeneration++;
      addressGeneration++;
      setState(() {
        owner = UserSession.userId;
        vehicles = [];
        addresses = [];
        vehiclesLoaded = false;
        addressesLoaded = false;
        loadingVehicles = false;
        loadingAddresses = false;
        vehicleError = null;
        addressError = null;
        error = null;
      });
      if (owner != null) {
        _loadVehicles();
        _loadAddresses();
      }
    } else if (vehiclesRevision != widget.controller.vehiclesRevision &&
        owner != null) {
      _loadVehicles();
    }
    vehiclesRevision = widget.controller.vehiclesRevision;
    setState(() {});
  }

  Future<void> _loadVehicles() async {
    final version = ++vehicleGeneration;
    final customer = owner;
    if (customer == null) return;
    setState(() {
      loadingVehicles = true;
      vehicleError = null;
    });
    try {
      final result = await widget.vehicleRepository.list();
      if (!mounted ||
          version != vehicleGeneration ||
          customer != UserSession.userId) return;
      setState(() {
        vehicles = result.where((v) => v.customerId == customer).toList();
        vehiclesLoaded = true;
      });
    } catch (failure) {
      if (mounted &&
          version == vehicleGeneration &&
          customer == UserSession.userId)
        setState(() => vehicleError = failure is AppFailure
            ? failure.message
            : 'Không tải được danh sách xe.');
    } finally {
      if (mounted &&
          version == vehicleGeneration &&
          customer == UserSession.userId)
        setState(() => loadingVehicles = false);
    }
  }

  Future<void> _loadAddresses() async {
    final version = ++addressGeneration;
    final customer = owner;
    if (customer == null) return;
    setState(() {
      loadingAddresses = true;
      addressError = null;
    });
    try {
      final result = await widget.addressRepository.list();
      if (!mounted ||
          version != addressGeneration ||
          customer != UserSession.userId) return;
      setState(() {
        addresses = result.where((a) => a.customerId == customer).toList();
        addressesLoaded = true;
      });
    } catch (failure) {
      if (mounted &&
          version == addressGeneration &&
          customer == UserSession.userId)
        setState(() => addressError = failure is AppFailure
            ? failure.message
            : 'Không tải được danh sách địa chỉ.');
    } finally {
      if (mounted &&
          version == addressGeneration &&
          customer == UserSession.userId)
        setState(() => loadingAddresses = false);
    }
  }

  Future<void> _manageVehicles() async {
    if (!UserSession.isLoggedIn) {
      Navigator.pushNamed(context, '/login');
      return;
    }
    final customer = owner;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => CustomerVehiclesScreen(
            controller: widget.controller,
            repository: widget.vehicleRepository)));
    if (mounted && owner == customer && customer == UserSession.userId)
      await _loadVehicles();
  }

  Future<void> _manageAddresses() async {
    if (!UserSession.isLoggedIn) {
      Navigator.pushNamed(context, '/login');
      return;
    }
    final customer = owner;
    await Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => CustomerSavedAddressesScreen(
            controller: widget.controller,
            repository: widget.addressRepository)));
    if (mounted && owner == customer && customer == UserSession.userId)
      await _loadAddresses();
  }

  Future<void> _confirmSignOut() async {
    if (signingOut) return;
    final customer = UserSession.userId;
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
                title: const Text('Đăng xuất tài khoản?'),
                content: const Text('Bạn có chắc chắn muốn đăng xuất?'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Ở lại')),
                  FilledButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Đăng xuất'))
                ]));
    if (mounted && confirmed == true && customer == UserSession.userId)
      await signOut();
  }

  Future<void> signOut() async {
    if (signingOut) return;
    setState(() {
      signingOut = true;
      error = null;
    });
    try {
      await widget.controller.signOut();
      if (!mounted) return;
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } on AppFailure catch (failure) {
      if (mounted) setState(() => error = failure.message);
    } finally {
      if (mounted) setState(() => signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loggedIn = UserSession.isLoggedIn;
    final controller = widget.controller;
    final completedCount =
        loggedIn && !controller.loadingRequests && controller.loadError == null
            ? controller.history
                .where((r) => r.stage == RequestStage.completed)
                .length
            : null;
    return Theme(
        data: BookingStyle.theme(context),
        child: Material(
            color: BookingStyle.background,
            child: Column(children: [
              CustomerAppHeader(onAccount: () {}),
              Expanded(
                  child: ListView(
                      key: const PageStorageKey('account-scroll'),
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                      children: [
                    CustomerProfileCard(
                        controller: controller,
                        repository: widget.profileRepository,
                        royal: true,
                        vehicleCount: vehiclesLoaded ? vehicles.length : null,
                        completedCount: completedCount),
                    const SizedBox(height: 24),
                    const Text('Xe của tôi', style: accountTitle),
                    const SizedBox(height: 12),
                    if (loadingVehicles) const LinearProgressIndicator(),
                    if (vehicleError != null)
                      InlineNotice(vehicleError!, onRetry: _loadVehicles),
                    if (!loggedIn)
                      const Text('Đăng nhập để xem xe đã lưu.',
                          style: accountCaption),
                    if (vehiclesLoaded &&
                        vehicles.isEmpty &&
                        vehicleError == null)
                      const AccountSurface(
                          child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('Chưa có xe đã lưu',
                                  style: accountCaption))),
                    for (final vehicle in vehicles) ...[
                      AccountVehicleCard(
                          vehicle: vehicle, onManage: _manageVehicles),
                      const SizedBox(height: 12)
                    ],
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                        onPressed: _manageVehicles,
                        style: RescueButtons.style(RescueButtonKind.secondary),
                        icon: const Icon(Icons.add_circle_outline),
                        label: const Text('Thêm phương tiện mới')),
                    TextButton(
                        onPressed: _manageVehicles,
                        child: const Text('Quản lý xe đã lưu')),
                    const SizedBox(height: 24),
                    const Text('Địa chỉ thường dùng', style: accountTitle),
                    const SizedBox(height: 12),
                    if (loadingAddresses) const LinearProgressIndicator(),
                    if (addressError != null)
                      InlineNotice(addressError!, onRetry: _loadAddresses),
                    if (!loggedIn)
                      const Text('Đăng nhập để xem địa chỉ đã lưu.',
                          style: accountCaption),
                    if (addressesLoaded)
                      AccountAddressSection(
                          addresses: addresses, onManage: _manageAddresses),
                    TextButton(
                        onPressed: _manageAddresses,
                        child: const Text('Quản lý địa chỉ')),
                    const SizedBox(height: 24),
                    const Text('Cài đặt & Hỗ trợ', style: accountTitle),
                    const SizedBox(height: 12),
                    const AccountSettingsSection(),
                    if (loggedIn) ...[
                      const SizedBox(height: 24),
                      if (error != null)
                        InlineNotice(error!,
                            onRetry: signingOut ? null : _confirmSignOut),
                      LogoutButton(
                          loading: signingOut, onPressed: _confirmSignOut)
                    ],
                  ])),
            ])));
  }
}
