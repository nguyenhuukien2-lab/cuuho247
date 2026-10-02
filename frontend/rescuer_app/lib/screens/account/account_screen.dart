import 'package:flutter/material.dart';

import '../../app/app_state.dart';
import '../../app/app_theme.dart';
import '../../models/rescuer_status.dart';
import '../../widgets/app_components.dart';
import '../auth/auth_screens.dart';
import '../onboarding/onboarding_screens.dart';

class AccountScreen extends StatelessWidget {
  const AccountScreen({super.key, required this.state});
  final AppState state;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) => Scaffold(
      appBar: AppBar(title: const Text('Tài khoản')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 26),
          children: [
            AppCard(
              child: Row(
                children: [
                  const BrandMark(size: 54),
                  const SizedBox(width: AppSpace.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          state.fullName?.isNotEmpty == true
                              ? state.fullName!
                              : 'Hồ sơ đối tác',
                          style: AppType.section,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          state.contactPhone?.isNotEmpty == true
                              ? state.contactPhone!
                              : 'Chưa cập nhật thông tin liên hệ',
                          style: AppType.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpace.lg),
            _AccountSection(
              title: 'Xác minh đối tác',
              status: state.partnerStatus.label,
              children: [
                _AccountRow(
                  icon: Icons.person_outline,
                  label: 'Thông tin hồ sơ',
                  value: state.contactEmail ?? 'Chưa cập nhật',
                  onTap: () =>
                      _open(context, PartnerProfileScreen(state: state)),
                ),
                _AccountRow(
                  icon: Icons.badge_outlined,
                  label: 'Giấy tờ',
                  value:
                      '${state.identityStatus.label} · ${state.licenseStatus.label}',
                  onTap: () =>
                      _open(context, DocumentVerificationScreen(state: state)),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            _AccountSection(
              title: 'Phương tiện và dịch vụ',
              status: state.vehicleStatus.label,
              children: [
                _AccountRow(
                  icon: Icons.directions_car_outlined,
                  label: state.vehicleDisplayName ?? 'Phương tiện',
                  value: state.vehiclePlate?.isNotEmpty == true
                      ? state.vehiclePlate!
                      : state.vehicleServiceType,
                  onTap: () =>
                      _open(context, VehicleRegistrationScreen(state: state)),
                ),
                _AccountRow(
                  icon: Icons.build_outlined,
                  label: 'Dịch vụ hỗ trợ',
                  value: state.serviceCapabilities.isEmpty
                      ? 'Chưa chọn dịch vụ'
                      : state.serviceCapabilities.join(' · '),
                  onTap: () =>
                      _open(context, VehicleRegistrationScreen(state: state)),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.md),
            _AccountSection(
              title: 'Cài đặt thiết bị',
              children: [
                _AccountRow(
                  icon: Icons.notifications_outlined,
                  label: 'Thông báo',
                  value: 'Chưa khả dụng',
                  onTap: () => _open(
                    context,
                    const DeviceStatusScreen(
                      kind: DeviceStatusKind.notifications,
                    ),
                  ),
                ),
                _AccountRow(
                  icon: Icons.location_on_outlined,
                  label: 'Quyền vị trí và GPS',
                  value: state.hasLocationPermission && state.isGpsEnabled
                      ? 'Sẵn sàng'
                      : 'Cần kiểm tra',
                  onTap: () => _open(
                    context,
                    const DeviceStatusScreen(kind: DeviceStatusKind.location),
                  ),
                ),
                _AccountRow(
                  icon: Icons.wifi_off_rounded,
                  label: 'Kết nối dịch vụ',
                  value: 'Chưa khả dụng',
                  onTap: () => _open(
                    context,
                    const DeviceStatusScreen(kind: DeviceStatusKind.connection),
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.lg),
            AppButton(
              label: state.isSignedIn ? 'Đăng xuất' : 'Đăng nhập',
              icon: state.isSignedIn
                  ? Icons.logout_rounded
                  : Icons.login_rounded,
              kind: ButtonStyleKind.outline,
              onPressed: () {
                if (state.isSignedIn) {
                  state.signOutLocally();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Bạn đã đăng xuất khỏi trạng thái trên thiết bị này.',
                      ),
                    ),
                  );
                } else {
                  Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => LoginScreen(state: state),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: AppSpace.sm),
            AppButton(
              label: 'Tiến độ đăng ký',
              kind: ButtonStyleKind.quiet,
              onPressed: () =>
                  _open(context, RegistrationProgressScreen(state: state)),
            ),
          ],
        ),
      ),
    ),
  );

  void _open(BuildContext context, Widget page) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({
    required this.title,
    required this.children,
    this.status,
  });
  final String title;
  final String? status;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.fromLTRB(
      AppSpace.lg,
      AppSpace.md,
      AppSpace.lg,
      AppSpace.sm,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text(title, style: AppType.section)),
            if (status != null) StatusBadge(label: status!),
          ],
        ),
        const SizedBox(height: AppSpace.sm),
        ...children,
      ],
    ),
  );
}

class _AccountRow extends StatelessWidget {
  const _AccountRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      minTileHeight: 56,
      leading: Icon(icon, color: AppColors.navy),
      title: Text(
        label,
        style: AppType.body.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        value,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: AppType.caption,
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppColors.muted),
      onTap: onTap,
    ),
  );
}

enum DeviceStatusKind { notifications, location, connection }

class DeviceStatusScreen extends StatelessWidget {
  const DeviceStatusScreen({super.key, required this.kind});
  final DeviceStatusKind kind;

  @override
  Widget build(BuildContext context) {
    final (title, icon, message) = switch (kind) {
      DeviceStatusKind.notifications => (
        'Thông báo',
        Icons.notifications_outlined,
        'Quản lý quyền thông báo trong cài đặt thiết bị. Tích hợp yêu cầu quyền sẽ được bổ sung sau.',
      ),
      DeviceStatusKind.location => (
        'Vị trí và GPS',
        Icons.location_on_outlined,
        'Ứng dụng cần quyền vị trí và GPS khả dụng để nhận đơn. Chưa có quyền hệ thống nào được yêu cầu.',
      ),
      DeviceStatusKind.connection => (
        'Kết nối',
        Icons.cloud_off_outlined,
        'Dữ liệu đơn và dịch vụ chưa khả dụng khi kết nối backend chưa được cấu hình.',
      ),
    };
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SafeArea(
        child: ScreenContent(
          children: [
            PageHeading(
              title: title,
              subtitle: 'Trạng thái quyền và kết nối thiết bị.',
            ),
            StatePanel(
              kind: PanelKind.unavailable,
              title: title,
              message: message,
              compact: true,
            ),
            const InfoBanner(
              title: 'Trạng thái',
              message: 'Màn hình này chưa thay đổi quyền hệ thống hoặc kết nối trên thiết bị.',
              tone: BadgeTone.neutral,
            ),
          ],
        ),
      ),
    );
  }
}
