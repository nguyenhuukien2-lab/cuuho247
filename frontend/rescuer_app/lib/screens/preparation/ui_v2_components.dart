import '../../app/mobile_ui.dart';
import '../../core/utils/display_code.dart';

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../app/rescuer_controller.dart';
import '../../widgets/app_components.dart';
import 'preparation_components.dart';

class PartnerHeader extends StatelessWidget implements PreferredSizeWidget {
  const PartnerHeader({
    super.key,
    required this.page,
    required this.onRefresh,
    required this.online,
    this.onBack,
  });
  final String page;
  final bool online;
  final VoidCallback? onRefresh, onBack;
  @override
  Size get preferredSize => const Size.fromHeight(64);
  @override
  Widget build(BuildContext context) => AppBar(
    automaticallyImplyLeading: false,
    toolbarHeight: 64,
    leading: onBack == null ? null : BackButton(onPressed: onBack),
    titleSpacing: 16,
    title: Row(
      children: [
        const BrandMark(size: 30),
        const SizedBox(width: 9),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cứu Hộ 24/7',
                maxLines: 2,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: RescueColors.ink,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 7,
                    color: online ? AppColors.success : AppColors.warning,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    online ? 'Online' : 'Offline',
                    style: const TextStyle(
                      fontSize: 12,
                      color: RescueColors.muted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    ),
    actions: [
      IconButton(
        tooltip: 'Tải lại',
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh_rounded, size: 22),
      ),
      const SizedBox(width: 4),
    ],
  );
}

class NavyPanel extends StatelessWidget {
  const NavyPanel({
    super.key,
    required this.child,
    this.kind = RescueCardKind.status,
  });
  final Widget child;
  final RescueCardKind kind;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(RescueSpace.lg),
    decoration: RescueSurfaces.decoration(kind),
    child: DefaultTextStyle(style: RescueType.body, child: child),
  );
}

class PartnerHero extends StatelessWidget {
  const PartnerHero({
    super.key,
    required this.c,
    this.account = false,
    this.onEdit,
  });
  final RescuerController c;
  final bool account;
  final VoidCallback? onEdit;
  @override
  Widget build(BuildContext context) {
    final profile = c.snapshot.profile;
    return NavyPanel(
      kind: RescueCardKind.profile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: RescueColors.selected,
                  borderRadius: BorderRadius.circular(RescueRadius.control),
                  border: Border.all(color: RescueColors.border),
                ),
                child: const Icon(
                  Icons.person_rounded,
                  color: RescueColors.ink,
                  size: 32,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile?['full_name'] as String? ?? 'Đối tác mới',
                      style: RescueType.section,
                    ),
                    const SizedBox(height: 5),
                    if (profile != null)
                      Text(
                        'Mã đối tác: ${displayCode(profile['rescuer_code'] as String?)}',
                        style: RescueType.code,
                      ),
                    if (account && profile?['contact_phone'] is String)
                      Text(
                        profile!['contact_phone'] as String,
                        style: const TextStyle(color: RescueColors.muted),
                      ),
                    if (!account)
                      const Text(
                        'Đồng hành trên mọi hành trình',
                        style: TextStyle(
                          color: RescueColors.muted,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(
                Icons.local_shipping_rounded,
                color: AppColors.orange,
                size: 30,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: RescueColors.background,
              borderRadius: BorderRadius.circular(RescueRadius.control),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.circle,
                  size: 9,
                  color: c.online ? AppColors.success : AppColors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    account
                        ? reviewLabels[profile?['verification_status']] ??
                              'Hồ sơ chưa nộp'
                        : c.hasActiveJob
                        ? 'Đang hỗ trợ một chuyến'
                        : c.online
                        ? 'Sẵn sàng ứng cứu'
                        : 'Đang offline',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
          ),
          if (account) ...[
            const SizedBox(height: 12),
            AppButton(
              label: 'Chỉnh sửa thông tin cá nhân',
              icon: Icons.edit_outlined,
              kind: ButtonStyleKind.secondary,
              onPressed: onEdit ?? () => c.openSection('profile'),
            ),
          ],
        ],
      ),
    );
  }
}

class GpsSignalCard extends StatelessWidget {
  const GpsSignalCard({super.key, required this.c});
  final RescuerController c;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.blueSoft,
      borderRadius: BorderRadius.circular(RescueRadius.card),
    ),
    child: Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: const BoxDecoration(
            color: AppColors.orangeSoft,
            shape: BoxShape.circle,
          ),
          child: Icon(
            c.locationReady && c.online ? Icons.radar : Icons.gps_not_fixed,
            color: AppColors.orange,
            size: 26,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                c.online && c.locationReady
                    ? 'Radar cứu hộ hoạt động'
                    : 'Radar đang chờ tín hiệu',
                style: AppType.body.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                c.locationReady && c.online
                    ? 'GPS đã đồng bộ cho phiên online'
                    : c.gpsReady
                    ? 'GPS thiết bị sẵn sàng · chưa phát vị trí'
                    : 'Bật GPS và cấp quyền vị trí chính xác',
                style: AppType.caption,
              ),
            ],
          ),
        ),
        if (c.locationReady && c.online)
          const Padding(
            padding: EdgeInsets.only(left: 6),
            child: StatusBadge(label: 'LIVE', tone: BadgeTone.green),
          ),
      ],
    ),
  );
}

class LocalFilterBar extends StatelessWidget {
  const LocalFilterBar({
    super.key,
    required this.labels,
    required this.selected,
    required this.onSelect,
  });
  final Map<String, String> labels;
  final String selected;
  final ValueChanged<String> onSelect;
  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (final entry in labels.entries)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              key: ValueKey('filter-${entry.key}'),
              label: Text(entry.value),
              selected: selected == entry.key,
              labelStyle: TextStyle(
                fontFamily: 'Roboto',
                color: selected == entry.key ? AppColors.navy : AppColors.muted,
                fontWeight: FontWeight.w700,
              ),
              onSelected: (_) => onSelect(entry.key),
            ),
          ),
      ],
    ),
  );
}

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label, value;
  final IconData icon;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.orange, size: 24),
        const SizedBox(height: 12),
        Text(value, style: AppType.pageTitle),
        const SizedBox(height: 4),
        Text(label, style: AppType.caption),
      ],
    ),
  );
}

IconData serviceIcon(String? code) => switch (code) {
  'towing' => Icons.local_shipping_outlined,
  'battery' => Icons.bolt_rounded,
  'tire' => Icons.tire_repair_rounded,
  'fuel' => Icons.local_gas_station_outlined,
  _ => Icons.car_repair_rounded,
};
