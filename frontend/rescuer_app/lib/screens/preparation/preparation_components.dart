import '../../app/mobile_ui.dart';

import 'package:flutter/material.dart';

import '../../app/app_theme.dart';
import '../../widgets/app_components.dart';

const reviewLabels = {
  'draft': 'Hồ sơ nháp',
  'submitted': 'Đang chờ duyệt',
  'pending': 'Đang chờ duyệt',
  'approved': 'Đã được duyệt',
  'rejected': 'Bị từ chối',
  'suspended': 'Tạm ngưng hoạt động',
  'expired': 'Hết hạn',
};
const vehicleKinds = {
  'service_motorbike': 'Xe máy hỗ trợ',
  'service_car': 'Ô tô hỗ trợ',
  'tow_truck': 'Xe kéo',
  'recovery_truck': 'Xe cứu hộ chuyên dụng',
  'other': 'Phương tiện khác',
};
const customerVehicles = {
  'motorbike': 'Xe máy',
  'car': 'Ô tô',
  'truck': 'Xe tải',
  'other': 'Xe khác',
};
const serviceLabels = {
  'tire': 'Vá/thay lốp',
  'battery': 'Kích bình',
  'fuel': 'Đổ xăng',
  'towing': 'Kéo xe',
  'other': 'Hỗ trợ khác',
};

/// Leave vertical room for the chips' tap targets while scrolling horizontally.
class PreparationFilterBar extends StatelessWidget {
  const PreparationFilterBar({
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
    key: const ValueKey('new-orders-filters'),
    scrollDirection: Axis.horizontal,
    padding: const EdgeInsets.symmetric(vertical: 6),
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

/// Display public order/quote codes only; internal UUIDs stay out of the UI.
String preparationDisplayCode(String? code, {required String prefix}) {
  final value = code?.trim();
  return value != null && RegExp('^$prefix-[0-9]+\$').hasMatch(value)
      ? value
      : 'Chưa có mã';
}

const sectionLabels = {
  'profile': 'Thông tin cá nhân',
  'vehicles': 'Phương tiện cứu hộ',
  'services': 'Dịch vụ nhận đơn',
  'documents': 'Giấy tờ xác minh',
  'review': 'Trạng thái xét duyệt',
  'gps': 'Vị trí GPS',
};
const sectionIcons = {
  'profile': Icons.person_outline,
  'vehicles': Icons.local_shipping_outlined,
  'services': Icons.build_outlined,
  'documents': Icons.folder_outlined,
  'review': Icons.verified_user_outlined,
  'gps': Icons.my_location,
};

class PreparationCard extends StatelessWidget {
  const PreparationCard({
    super.key,
    required this.title,
    this.subtitle = '',
    required this.icon,
    required this.children,
    this.kind = RescueCardKind.information,
  });
  final String title, subtitle;
  final IconData icon;
  final List<Widget> children;
  final RescueCardKind kind;
  @override
  Widget build(BuildContext context) => AppCard(
    kind: kind,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: RescueColors.selected,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: AppColors.navy),
            ),
            const SizedBox(width: 12),
            Expanded(child: Text(title, style: AppType.section)),
          ],
        ),
        if (subtitle.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(subtitle, style: AppType.caption),
        ],
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  );
}

class ReviewBadge extends StatelessWidget {
  const ReviewBadge(this.status, {super.key});
  final String? status;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: RescueStatusBadge(status: status, label: reviewLabels[status]),
  );
}

class PreparationEmpty extends StatelessWidget {
  const PreparationEmpty({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.kind = RescueFeedbackKind.empty,
    this.action,
    this.embedded = false,
  });
  final String title, message;
  final IconData icon;
  final RescueFeedbackKind kind;
  final Widget? action;
  final bool embedded;
  @override
  Widget build(BuildContext context) {
    final content = RescueFeedback(
      title: title,
      message: message,
      icon: icon,
      kind: kind,
      action: action,
      compact: embedded,
    );
    return embedded
        ? content
        : AppCard(padding: EdgeInsets.zero, child: content);
  }
}

/// A single bright section groups related rows without nested cards.
class PartnerSection extends StatelessWidget {
  const PartnerSection({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.accent = AppColors.navy,
    this.background = AppColors.surface,
    this.trailing,
    this.compact = false,
  });
  final String title;
  final IconData icon;
  final Color accent;
  final Color background;
  final List<Widget> children;
  final Widget? trailing;
  final bool compact;

  @override
  Widget build(BuildContext context) => Material(
    color: background,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppRadii.lg),
      side: BorderSide(color: AppColors.line.withValues(alpha: .4)),
    ),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (!compact)
                Container(
                  padding: EdgeInsets.zero,
                  child: Icon(icon, color: accent, size: 21),
                ),
              if (!compact) const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: compact ? RescueType.title : AppType.section,
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          SizedBox(height: compact ? 8 : 14),
          ...children,
        ],
      ),
    ),
  );
}
