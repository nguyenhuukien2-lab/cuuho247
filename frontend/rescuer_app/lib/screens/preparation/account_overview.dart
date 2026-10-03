import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../app/rescuer_controller.dart';
import '../../widgets/app_components.dart';
import 'preparation_components.dart';
import 'ui_v2_components.dart';

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
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      PartnerHero(c: c, account: true, onEdit: () => onEdit('profile')),
      const SizedBox(height: 20),
      PreparationCard(
        title: 'Phương tiện cứu hộ',
        subtitle: 'Phương tiện liên kết với hồ sơ đối tác.',
        icon: Icons.local_shipping_outlined,
        children: [
          if (c.snapshot.vehicles.isEmpty)
            const Text('Chưa có phương tiện. Thêm xe để đăng ký dịch vụ.'),
          for (final v in c.snapshot.vehicles) ...[
            _tile(
              icon: Icons.local_shipping_outlined,
              title: v['license_plate'] as String? ?? 'Chưa có biển số',
              detail:
                  '${v['display_name'] ?? ''}\n${vehicleKinds[v['kind']] ?? 'Phương tiện cứu hộ'}',
            ),
            ReviewBadge(v['verification_status'] as String?),
            const SizedBox(height: 12),
          ],
          AppButton(
            label: 'Quản lý phương tiện cứu hộ',
            kind: ButtonStyleKind.secondary,
            icon: Icons.tune_rounded,
            onPressed: () => onEdit('vehicles'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      PreparationCard(
        title: 'Dịch vụ tác nghiệp',
        subtitle: 'Danh mục đăng ký theo xe và loại xe khách.',
        icon: Icons.handyman_outlined,
        children: [
          if (c.snapshot.capabilities.isEmpty)
            const Text('Chưa có dịch vụ đăng ký.'),
          for (final item in c.snapshot.capabilities) ...[
            _tile(
              icon: serviceIcon(item['service_code'] as String?),
              title: serviceLabels[item['service_code']] ?? 'Dịch vụ đăng ký',
              detail:
                  '${customerVehicles[item['customer_vehicle_kind']] ?? 'Loại xe theo hồ sơ'} · ${item['is_enabled'] == true ? 'Đang bật' : 'Đã tắt'}',
            ),
            ReviewBadge(item['verification_status'] as String?),
            const SizedBox(height: 10),
          ],
          AppButton(
            label: 'Cập nhật danh mục dịch vụ',
            kind: ButtonStyleKind.secondary,
            icon: Icons.tune_rounded,
            onPressed: () => onEdit('services'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      PreparationCard(
        title: 'Giấy tờ xác minh',
        subtitle: 'Hồ sơ pháp lý và trạng thái xét duyệt thật.',
        icon: Icons.folder_copy_outlined,
        children: [
          for (final type in const {
            'license': 'Giấy phép lái xe',
            'vehicle_registration': 'Đăng ký phương tiện',
            'identity': 'CCCD / Giấy tờ định danh',
          }.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _tile(
                    icon: Icons.fact_check_outlined,
                    title: type.value,
                    detail:
                        c.snapshot.documents.any(
                          (d) => d['document_type'] == type.key,
                        )
                        ? 'Xem trạng thái từng tệp trong hồ sơ giấy tờ'
                        : 'Chưa có giấy tờ',
                  ),
                  for (final d in c.snapshot.documents.where(
                    (d) => d['document_type'] == type.key,
                  ))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: ReviewBadge(d['verification_status'] as String?),
                    ),
                ],
              ),
            ),
          AppButton(
            label: 'Xem và bổ sung giấy tờ',
            kind: ButtonStyleKind.secondary,
            onPressed: () => onEdit('documents'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      PreparationCard(
        title: 'Trạng thái vận hành',
        subtitle: 'Quyền tiếp nhận theo hồ sơ, xe và dịch vụ.',
        icon: Icons.verified_user_outlined,
        children: [
          ReviewBadge(c.snapshot.profile?['verification_status'] as String?),
          const SizedBox(height: 12),
          Text(
            c.canOnline
                ? 'Có phương tiện và dịch vụ đủ điều kiện vận hành.'
                : 'Hoàn tất điều kiện và xét duyệt để bật online.',
            style: AppType.body,
          ),
          const SizedBox(height: 14),
          AppButton(
            label: 'Xem xét duyệt hồ sơ',
            kind: ButtonStyleKind.secondary,
            onPressed: () => onEdit('review'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      PreparationCard(
        title: 'Định vị & Phạm vi',
        subtitle: 'Vị trí chỉ cập nhật khi dùng ứng dụng ở foreground.',
        icon: Icons.my_location_rounded,
        children: [
          GpsSignalCard(c: c),
          const SizedBox(height: 12),
          const Text(
            'Phạm vi nhận đơn do hệ thống xác định theo GPS và dịch vụ đã duyệt.',
            style: AppType.caption,
          ),
          const SizedBox(height: 12),
          AppButton(
            label: 'Quản lý quyền vị trí',
            kind: ButtonStyleKind.secondary,
            onPressed: () => onEdit('gps'),
          ),
        ],
      ),
      const SizedBox(height: 16),
      AppCard(
        child: Column(
          children: [
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(
                Icons.security_outlined,
                color: AppColors.navy,
              ),
              title: const Text('Bảo mật tài khoản'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _help(
                context,
                'Bảo mật tài khoản',
                'Chưa có chức năng đổi mật khẩu trong ứng dụng. Sử dụng quy trình khôi phục tài khoản của hệ thống khi cần. Không chia sẻ mật khẩu với người khác.',
              ),
            ),
            const Divider(),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.support_agent, color: AppColors.orange),
              title: const Text('Hỗ trợ kỹ thuật'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _help(
                context,
                'Hỗ trợ kỹ thuật',
                'Chưa có kênh hỗ trợ được cấu hình trong ứng dụng. Khi gặp lỗi, ghi lại thông báo và mã đơn để gửi cho đơn vị quản lý tài khoản.',
              ),
            ),
          ],
        ),
      ),
      const SizedBox(height: 16),
      AppButton(
        label: 'Đăng xuất tài khoản đối tác',
        kind: ButtonStyleKind.danger,
        icon: Icons.logout,
        onPressed: onLogout,
      ),
      const SizedBox(height: 24),
      const SectionTitle(title: 'Cập nhật hồ sơ đối tác'),
      const SizedBox(height: 6),
      const Text(
        'Chọn mục bên dưới để xem hoặc chỉnh sửa. Thay đổi thông tin có thể cần xét duyệt lại.',
        style: AppType.caption,
      ),
    ],
  );
  static Widget _tile({
    required IconData icon,
    required String title,
    required String detail,
  }) => Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 10),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppColors.background,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.navy, size: 22),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppType.body.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 3),
              Text(detail, style: AppType.caption),
            ],
          ),
        ),
      ],
    ),
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
