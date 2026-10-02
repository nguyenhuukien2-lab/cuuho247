import 'package:flutter/material.dart';
import '../app/app_controller.dart';
import '../app/app_theme.dart';
import '../app/user_session.dart';
import '../widgets/customer_profile_card.dart';
import '../widgets/customer_ui.dart';
import '../services/supabase_service.dart';
import '../services/customer_profile_service.dart';
import 'customer_vehicles_screen.dart';
import 'customer_saved_addresses_screen.dart';

class NewAccountScreen extends StatefulWidget {
  const NewAccountScreen(
      {super.key,
      required this.controller,
      this.profileRepository = const SupabaseCustomerProfileRepository()});
  final AppController controller;
  final CustomerProfileRepository profileRepository;
  @override
  State<NewAccountScreen> createState() => _NewAccountScreenState();
}

class _NewAccountScreenState extends State<NewAccountScreen> {
  bool signingOut = false;
  String? error;

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
    return ListView(
        key: const PageStorageKey('account-scroll'),
        padding: AppSpacing.page,
        children: [
          const ScreenHeader('Tài khoản'),
          CustomerProfileCard(
              controller: widget.controller,
              repository: widget.profileRepository),
          const SizedBox(height: 24),
          Text('Thông tin đã lưu',
              style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          Material(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              clipBehavior: Clip.antiAlias,
              child: Column(children: [
                SettingsRow(
                    icon: Icons.directions_car_outlined,
                    title: 'Phương tiện của tôi',
                    subtitle: 'Thêm xe để chọn nhanh khi cứu hộ',
                    onTap: () => loggedIn
                        ? Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => CustomerVehiclesScreen(
                                controller: widget.controller)))
                        : Navigator.pushNamed(context, '/login')),
                const Divider(height: 1, indent: 56),
                SettingsRow(
                    icon: Icons.bookmark_border_rounded,
                    title: 'Địa chỉ đã lưu',
                    subtitle: 'Quản lý địa chỉ thường sử dụng',
                    onTap: () => loggedIn
                        ? Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => CustomerSavedAddressesScreen(
                                controller: widget.controller)))
                        : Navigator.pushNamed(context, '/login')),
              ])),
          if (loggedIn) ...[
            const SizedBox(height: 32),
            if (error != null)
              InlineNotice(error!, onRetry: signingOut ? null : signOut),
            OutlinedButton.icon(
                onPressed: signingOut ? null : signOut,
                icon: signingOut
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.logout_rounded),
                label: Text(signingOut ? 'Đang đăng xuất…' : 'Đăng xuất'),
                style:
                    OutlinedButton.styleFrom(foregroundColor: AppColors.error)),
          ],
        ]);
  }
}
