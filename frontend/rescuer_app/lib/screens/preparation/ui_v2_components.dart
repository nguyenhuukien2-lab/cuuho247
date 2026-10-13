import '../../app/mobile_ui.dart';

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
                'CỨU HỘ 24/7 · ĐỐI TÁC',
                maxLines: 2,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  fontFamily: 'PlusJakartaSans',
                  color: RescueColors.navy,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(
                    Icons.circle,
                    size: 7,
                    color: online
                        ? AppColors.success
                        : RescueColors.secondaryText,
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

class PartnerNavigationBar extends StatelessWidget {
  const PartnerNavigationBar({super.key, required this.selectedIndex, required this.onSelected});
  final int selectedIndex;
  final ValueChanged<int>? onSelected;
  @override
  Widget build(BuildContext context) => NavigationBar(
    selectedIndex: selectedIndex,
    height: MediaQuery.textScalerOf(context).scale(11) > 14 ? 88 : 64,
    labelTextStyle: WidgetStateProperty.resolveWith((states) => AppType.status.copyWith(
      fontSize: 11, height: 1.3,
      color: states.contains(WidgetState.selected) ? AppColors.orange : AppColors.muted)),
    onDestinationSelected: onSelected,
    destinations: const [
      NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Trang chủ'),
      NavigationDestination(icon: Icon(Icons.notifications_active_outlined), selectedIcon: Icon(Icons.assignment), label: 'Đơn mới'),
      NavigationDestination(icon: Icon(Icons.local_shipping_outlined), selectedIcon: Icon(Icons.local_shipping), label: 'Đang xử lý'),
      NavigationDestination(icon: Icon(Icons.history_outlined), selectedIcon: Icon(Icons.history), label: 'Lịch sử'),
      NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Tài khoản'),
    ]);
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
    final code = profile?['rescuer_code'] as String?;
    final vehicle = c.snapshot.vehicles
        .where((v) => v['id'] == c.selectedVehicle)
        .firstOrNull;
    return AppCard(
      kind: RescueCardKind.profile,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: account ? 28 : 24,
                backgroundColor: RescueColors.container,
                child: Icon(
                  Icons.person_outline,
                  size: account ? 32 : 28,
                  color: AppColors.navy,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      profile?['full_name'] as String? ??
                          'Hoàn thiện hồ sơ đối tác',
                      style: RescueType.section,
                    ),
                    if (code != null && RegExp(r'^DT-\d+$').hasMatch(code)) ...[
                      const SizedBox(height: 4),
                      Text(code, style: AppType.code),
                    ],
                    const SizedBox(height: 6),
                    Text(
                      reviewLabels[profile?['verification_status']] ??
                          'Chưa nộp hồ sơ',
                      style: RescueType.caption.copyWith(
                        color: c.snapshot.approved
                            ? RescueColors.successText
                            : RescueColors.warningText,
                      ),
                    ),
                  ],
                ),
              ),
              if (account)
                IconButton(
                  tooltip: 'Chỉnh sửa thông tin cá nhân',
                  onPressed: c.working ? null : onEdit,
                  icon: const Icon(Icons.edit_outlined, size: 20),
                ),
            ],
          ),
          if (account) ...[
            const SizedBox(height: 14),
            ReviewBadge(profile?['verification_status'] as String?),
          ] else ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: RescueColors.selected,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  const Icon(Icons.local_shipping_outlined, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      vehicle == null
                          ? 'Chưa chọn phương tiện hoạt động'
                          : [vehicle['display_name'], vehicle['license_plate']]
                                .whereType<String>()
                                .where((s) => s.trim().isNotEmpty)
                                .join(' · '),
                      style: RescueType.body,
                    ),
                  ),
                ],
              ),
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
                fontFamily: 'Inter',
                color: selected == entry.key ? Colors.white : AppColors.muted,
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
