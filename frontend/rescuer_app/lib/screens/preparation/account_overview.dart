import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../app/rescuer_controller.dart';
import '../../core/utils/display_code.dart';
import 'preparation_components.dart';

class AccountOverview extends StatelessWidget {
  const AccountOverview({
    super.key,
    required this.c,
    required this.onEdit,
    this.onLogout,
  });
  final RescuerController c;
  final VoidCallback? onLogout;
  final ValueChanged<String> onEdit;

  @override
  Widget build(BuildContext context) {
    final profile = c.snapshot.profile;
    final vehicles = c.snapshot.vehicles;
    final services = c.snapshot.capabilities;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PartnerSection(
          key: const ValueKey('account-identity'),
          title: 'Tài khoản đối tác',
          icon: Icons.person_outline,
          children: [
            Text(
              profile?['full_name'] as String? ??
                  'Hoàn thiện thông tin cá nhân',
              style: AppType.section,
            ),
            const SizedBox(height: 6),
            if (profile != null)
              Text(
                'Mã đối tác: ${displayCode(profile['rescuer_code'] as String?)}',
                style: AppType.code,
              ),
            if (profile?['contact_phone'] is String)
              Text(profile!['contact_phone'] as String, style: AppType.body),
            const SizedBox(height: 10),
            ReviewBadge(profile?['verification_status'] as String?),
            const SizedBox(height: 6),
            _row(
              'Thông tin cá nhân',
              Icons.edit_outlined,
              profile == null
                  ? 'Thêm họ tên và số điện thoại'
                  : 'Chỉnh sửa thông tin',
              () => onEdit('profile'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        PartnerSection(
          key: const ValueKey('account-operation'),
          title: 'Hồ sơ hoạt động',
          icon: Icons.fact_check_outlined,
          accent: c.canOnline ? AppColors.success : AppColors.warning,
          children: [
            _row(
              'Hồ sơ xác minh',
              Icons.folder_outlined,
              '${c.snapshot.documents.length} giấy tờ đã tải',
              () => onEdit('documents'),
            ),
            const Divider(height: 1),
            _row(
              'Xe của tôi',
              Icons.local_shipping_outlined,
              '${vehicles.length} xe · ${vehicles.where((v) => v['verification_status'] == 'approved' && v['is_active'] == true).length} xe đã duyệt, đang dùng',
              () => onEdit('vehicles'),
            ),
            const Divider(height: 1),
            _row(
              'Dịch vụ cứu hộ',
              Icons.handyman_outlined,
              '${services.length} dịch vụ · ${services.where((s) => s['verification_status'] == 'approved' && s['is_enabled'] == true).length} đã duyệt, đang bật',
              () => onEdit('services'),
            ),
            const Divider(height: 1),
            _row(
              'Trạng thái duyệt',
              Icons.verified_user_outlined,
              'Xem điều kiện và gửi hồ sơ',
              () => onEdit('review'),
            ),
          ],
        ),
        const SizedBox(height: 16),
        PartnerSection(
          key: const ValueKey('account-settings'),
          title: 'Thiết lập',
          icon: Icons.settings_outlined,
          children: [
            _row(
              'GPS & quyền vị trí',
              Icons.my_location,
              c.gpsReady ? 'GPS thiết bị sẵn sàng' : 'Kiểm tra định vị',
              () => onEdit('gps'),
            ),
            const Divider(height: 1),
            _row(
              'Bảo mật tài khoản',
              Icons.security_outlined,
              null,
              () => _help(
                context,
                'Bảo mật tài khoản',
                'Chưa hỗ trợ đổi mật khẩu trong app. Dùng quy trình khôi phục tài khoản của hệ thống. Không chia sẻ mật khẩu.',
              ),
            ),
            const Divider(height: 1),
            _row(
              'Hỗ trợ kỹ thuật',
              Icons.support_agent,
              null,
              () => _help(
                context,
                'Hỗ trợ kỹ thuật',
                'Chưa cấu hình kênh hỗ trợ. Gửi thông báo lỗi và mã đơn cho đơn vị quản lý tài khoản.',
              ),
            ),
            const Divider(height: 1),
            _row(
              'Đăng xuất',
              Icons.logout,
              null,
              onLogout,
              color: AppColors.danger,
            ),
          ],
        ),
      ],
    );
  }

  static Widget _row(
    String title,
    IconData icon,
    String? detail,
    VoidCallback? onTap, {
    Color color = AppColors.navy,
  }) => ListTile(
    contentPadding: EdgeInsets.zero,
    leading: Icon(icon, color: color, size: 22),
    title: Text(
      title,
      style: AppType.body.copyWith(color: color, fontWeight: FontWeight.w600),
    ),
    subtitle: detail == null ? null : Text(detail, style: AppType.caption),
    trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
    onTap: onTap,
  );

  static void _help(BuildContext context, String title, String message) =>
      showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Đã hiểu'),
            ),
          ],
        ),
      );
}
