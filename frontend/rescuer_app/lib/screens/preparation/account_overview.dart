import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../app/rescuer_controller.dart';
import '../../models/backend_models.dart';
import '../../widgets/app_components.dart';
import 'partner_accordion.dart';
import 'gps_status_detail.dart';
import 'preparation_components.dart';
import 'ui_v2_components.dart';

class AccountOverview extends StatefulWidget {
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
  State<AccountOverview> createState() => _AccountOverviewState();
}

class _AccountOverviewState extends State<AccountOverview> {
  String? _expanded;

  Widget _group(
    String id,
    String title,
    IconData icon,
    String? subtitle,
    List<Widget> children,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: PartnerAccordion(
      id: id,
      title: title,
      icon: icon,
      subtitle: subtitle,
      expanded: _expanded == id,
      onToggle: () => setState(() => _expanded = _expanded == id ? null : id),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    ),
  );

  Widget _edit(String section, String label) => Padding(
    padding: const EdgeInsets.only(top: 12),
    child: AppButton(
      label: label,
      kind: ButtonStyleKind.outline,
      icon: Icons.edit_outlined,
      onPressed: widget.c.working ? null : () => widget.onEdit(section),
    ),
  );

  static Widget _value(String label, Object? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: LabeledValue(
      label: label,
      value: value is String && value.trim().isNotEmpty
          ? value
          : 'Chưa cung cấp',
    ),
  );

  static Widget _record(
    String title,
    String? subtitle,
    String? status, {
    String? activity,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: AppType.body.copyWith(fontWeight: FontWeight.w600)),
        if (subtitle?.isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Text(subtitle!, style: AppType.caption),
        ],
        const SizedBox(height: 6),
        ReviewBadge(status),
        if (activity != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(activity, style: AppType.caption),
          ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = widget.c, profile = c.snapshot.profile;
    final vehicles = c.snapshot.vehicles,
        capabilities = c.snapshot.capabilities;
    final review =
        reviewLabels[profile?['verification_status']] ?? 'Chưa nộp hồ sơ';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        PartnerHero(
          key: const ValueKey('account-identity'),
          c: c,
          account: true,
          onEdit: () => widget.onEdit('profile'),
        ),
        const SizedBox(height: 20),
        _group('profile', 'Hồ sơ đối tác', Icons.badge_outlined, review, [
          _value('Họ tên', profile?['full_name']),
          const Divider(height: 1),
          _value('Số điện thoại', profile?['contact_phone']),
          if (profile?['email'] is String) _value('Email', profile?['email']),
          if (profile?['rescuer_code'] case final String code
              when RegExp(r'^DT-\d+$').hasMatch(code))
            _value('Mã đối tác', code),
          ReviewBadge(profile?['verification_status'] as String?),
          _edit('profile', 'Chỉnh sửa hồ sơ'),
        ]),
        _group(
          'vehicles',
          'Phương tiện cứu hộ',
          Icons.local_shipping_outlined,
          '${vehicles.length} phương tiện đăng ký',
          [
            if (vehicles.isEmpty)
              const Text('Chưa có phương tiện cứu hộ.', style: AppType.body),
            for (final v in vehicles) ...[
              _record(
                v['display_name'] as String? ?? 'Phương tiện chưa có tên',
                [
                  vehicleKinds[v['kind']],
                  v['license_plate'] as String?,
                ].whereType<String>().join(' · '),
                v['verification_status'] as String?,
                activity: v['is_active'] == true
                    ? 'Đang hoạt động'
                    : 'Đã tắt hoạt động',
              ),
              const Divider(height: 1),
            ],
            _edit('vehicles', 'Thêm / sửa phương tiện'),
          ],
        ),
        _group(
          'services',
          'Dịch vụ đang cung cấp',
          Icons.handyman_outlined,
          '${capabilities.where((s) => s['is_enabled'] == true).length} đăng ký đang bật',
          [
            if (capabilities.isEmpty)
              const Text('Chưa đăng ký dịch vụ.', style: AppType.body),
            for (final s in capabilities) ...[
              _record(
                serviceLabels[s['service_code']] ??
                    (c.snapshot.services
                            .where((r) => r['code'] == s['service_code'])
                            .firstOrNull?['name']
                        as String?) ??
                    'Dịch vụ cứu hộ',
                [
                  customerVehicles[s['customer_vehicle_kind']],
                  vehicles
                          .where((v) => v['id'] == s['vehicle_id'])
                          .firstOrNull?['license_plate']
                      as String?,
                ].whereType<String>().join(' · '),
                s['verification_status'] as String?,
                activity: s['is_enabled'] == true ? 'Đã bật' : 'Đã tắt',
              ),
              const Divider(height: 1),
            ],
            _edit('services', 'Quản lý dịch vụ'),
          ],
        ),
        _group(
          'documents',
          'Giấy tờ & xác minh',
          Icons.verified_user_outlined,
          review,
          [
            if (c.snapshot.documents.isEmpty)
              const Text('Chưa tải giấy tờ xác minh.', style: AppType.body),
            for (final d in c.snapshot.documents) ...[
              _record(
                const {
                      'identity': 'Căn cước / giấy tờ định danh',
                      'license': 'Giấy phép lái xe',
                      'vehicle_registration': 'Đăng ký phương tiện',
                    }[d['document_type']] ??
                    'Giấy tờ liên quan',
                d['uploaded_at'] == null ? 'Tệp chưa tải hoàn tất' : null,
                d['uploaded_at'] == null
                    ? null
                    : d['verification_status'] as String?,
              ),
              const Divider(height: 1),
            ],
            _edit('documents', 'Tải / bổ sung giấy tờ'),
            _edit('review', 'Xem trạng thái / gửi xác minh'),
          ],
        ),
        _group(
          'gps',
          'GPS & hoạt động',
          Icons.gps_fixed,
          '${c.online ? 'Online' : 'Offline'} · ${c.gpsReady ? 'GPS sẵn sàng' : 'GPS chưa sẵn sàng'}',
          [
            _value(
              'Vị trí thiết bị',
              c.gpsReady
                  ? 'Đã có vị trí chính xác'
                  : 'Cần kiểm tra quyền vị trí và GPS',
            ),
            GpsStatusDetail(c: c, coordinates: true),
            _value(
              'Đồng bộ vị trí',
              c.locationReady && (c.online || c.hasActiveJob)
                  ? 'Đã đồng bộ cho phiên online'
                  : 'Chưa đồng bộ cho phiên online',
            ),
            _value(
              'Điều kiện hoạt động',
              c.canOnline
                  ? 'Đủ điều kiện bật online'
                  : 'Chưa đủ điều kiện bật online',
            ),
            for (final reason in c.onlineBlockers)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(reason, style: AppType.caption),
              ),
            AppButton(
              label: 'Kiểm tra GPS',
              icon: Icons.gps_fixed,
              kind: ButtonStyleKind.outline,
              onPressed: c.working ? null : c.checkGps,
            ),
            TextButton(
              onPressed: () => c.openLocationSettings(LocationHelp.permission),
              child: const Text('Mở Cài đặt quyền vị trí'),
            ),
            TextButton(
              onPressed: () => c.openLocationSettings(LocationHelp.disabled),
              child: const Text('Mở Cài đặt GPS'),
            ),
            const Text(
              'Ứng dụng dùng vị trí khi bạn đang sử dụng, không yêu cầu quyền vị trí nền.',
              style: AppType.caption,
            ),
          ],
        ),
        _group('security', 'Bảo mật', Icons.lock_outline, null, const [
          Text('Bảo mật tài khoản', style: AppType.body),
          SizedBox(height: 8),
          Text(
            'Chưa hỗ trợ đổi mật khẩu hoặc quản lý thiết bị trong ứng dụng. Không chia sẻ mật khẩu tài khoản.',
            style: AppType.caption,
          ),
        ]),
        _group('support', 'Hỗ trợ', Icons.support_agent, null, const [
          Text('Hỗ trợ kỹ thuật', style: AppType.body),
          SizedBox(height: 8),
          Text(
            'Chưa cấu hình kênh hỗ trợ. Gửi thông báo lỗi và mã đơn cho đơn vị quản lý tài khoản.',
            style: AppType.caption,
          ),
        ]),
        const SizedBox(height: 8),
        AppButton(
          key: const ValueKey('account-logout'),
          label: 'Đăng xuất',
          icon: Icons.logout,
          kind: ButtonStyleKind.danger,
          onPressed: widget.onLogout,
        ),
      ],
    );
  }
}
