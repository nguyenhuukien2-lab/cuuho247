import '../app/mobile_ui.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app/app_controller.dart';
import '../services/customer_vehicle_service.dart';
import '../services/location_service.dart';
import '../services/request_photo_service.dart';
import 'rescue_widgets.dart';

// Compatibility adapter: booking screens now inherit the app-wide theme.
abstract final class BookingStyle {
  static const blue = RescueColors.navy, green = RescueColors.success;
  static const background = RescueColors.background,
      pale = RescueColors.selected;
  static const ink = RescueColors.ink, muted = RescueColors.muted;
  static ThemeData theme(BuildContext context) => Theme.of(context);
}

class CustomerAppHeader extends StatelessWidget {
  const CustomerAppHeader({super.key, required this.onAccount});
  final VoidCallback onAccount;

  Future<void> _call(BuildContext context) async {
    try {
      if (await launchUrl(Uri(scheme: 'tel', path: '19006868'))) return;
    } catch (_) {
      // The number remains visible when a dialer is unavailable.
    }
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Hotline SOS: 1900 6868')));
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: BookingStyle.pale,
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.verified_user_outlined,
                color: BookingStyle.blue,
              ),
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Cứu Hộ 24/7',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: BookingStyle.blue,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      )),
                  Text(
                    'Khách Hàng',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: BookingStyle.muted),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: () => _call(context),
              style: TextButton.styleFrom(
                backgroundColor: const Color(0xFFFEF2F2),
                foregroundColor: const Color(0xFFEF4444),
                padding: const EdgeInsets.symmetric(horizontal: 10),
              ),
              icon: const Icon(Icons.circle, size: 8),
              label: const Text('1900 6868',
                  maxLines: 1,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
            ),
            IconButton(
              tooltip: 'Mở tài khoản',
              onPressed: onAccount,
              icon: const CircleAvatar(
                radius: 16,
                backgroundColor: BookingStyle.blue,
                child:
                    Icon(Icons.person_outline, size: 20, color: Colors.white),
              ),
            ),
          ],
        ),
      );
}

class CustomerStepIndicator extends StatelessWidget {
  const CustomerStepIndicator({
    super.key,
    required this.step,
    required this.onStep,
  });
  final int step;
  final ValueChanged<int>? onStep;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Positioned(
                  top: 19,
                  left: constraints.maxWidth / 10,
                  right: constraints.maxWidth / 10,
                  child: SizedBox(
                    height: 3,
                    child: LinearProgressIndicator(
                      value: step / 4,
                      color: BookingStyle.green,
                      backgroundColor: const Color(0xFFE5EEFF),
                    ),
                  ),
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in const [
                      'Dịch vụ',
                      'Chọn xe',
                      'Vị trí',
                      'Mô tả',
                      'Xác nhận',
                    ].asMap().entries)
                      Expanded(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ChoiceChip(
                              key: ValueKey('request-step-${entry.key}'),
                              selected: step == entry.key,
                              showCheckmark: false,
                              padding: EdgeInsets.zero,
                              labelPadding: const EdgeInsets.all(7),
                              materialTapTargetSize:
                                  MaterialTapTargetSize.padded,
                              shape: const CircleBorder(),
                              side: BorderSide(
                                color: step == entry.key
                                    ? BookingStyle.blue.withValues(alpha: .2)
                                    : Colors.transparent,
                                width: 3,
                              ),
                              selectedColor: BookingStyle.blue,
                              backgroundColor: entry.key < step
                                  ? BookingStyle.green
                                  : const Color(0xFFE5EEFF),
                              label: entry.key < step
                                  ? const Icon(
                                      Icons.check,
                                      size: 16,
                                      color: Colors.white,
                                    )
                                  : SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: Center(
                                        child: Text(
                                          '${entry.key + 1}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w700,
                                            color: entry.key == step
                                                ? Colors.white
                                                : BookingStyle.muted,
                                          ),
                                        ),
                                      ),
                                    ),
                              onSelected: onStep == null
                                  ? null
                                  : (_) => onStep!(entry.key),
                            ),
                            Text(
                              entry.value,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: entry.key < step
                                    ? BookingStyle.green
                                    : entry.key == step
                                        ? BookingStyle.blue
                                        : BookingStyle.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
}

class CustomerCard extends StatelessWidget {
  const CustomerCard({
    super.key,
    required this.title,
    required this.icon,
    required this.children,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 20, color: BookingStyle.blue),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                ],
              ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style:
                      const TextStyle(fontSize: 12, color: BookingStyle.muted),
                ),
              ],
              const SizedBox(height: 12),
              ...children,
            ],
          ),
        ),
      );
}

class SelectedServiceCard extends StatelessWidget {
  const SelectedServiceCard({
    super.key,
    required this.service,
    required this.onChange,
  });
  final RescueService service;
  final VoidCallback? onChange;
  @override
  Widget build(BuildContext context) => Card(
          child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const Expanded(
                    child: Text('Dịch vụ đã chọn',
                        style: TextStyle(
                            fontSize: 12, color: BookingStyle.muted))),
                TextButton(
                    onPressed: onChange, child: const Text('Đổi dịch vụ')),
              ]),
              Row(children: [
                Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                        color: BookingStyle.pale,
                        borderRadius: BorderRadius.circular(12)),
                    child: Icon(serviceIcon(service),
                        size: 28, color: BookingStyle.blue)),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(service.label,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: BookingStyle.ink))),
              ]),
            ]),
      ));
}

class VehicleSelectCard extends StatelessWidget {
  const VehicleSelectCard({
    super.key,
    required this.vehicle,
    required this.selected,
    required this.onTap,
  });
  final CustomerVehicle vehicle;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Semantics(
          selected: selected,
          button: true,
          child: Material(
            color: selected ? BookingStyle.pale : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(RescueRadius.card),
              side: BorderSide(
                color: selected ? BookingStyle.blue : const Color(0xFFE5EEFF),
                width: selected ? 2 : 1,
              ),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(RescueRadius.card),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: selected ? Colors.white : BookingStyle.pale,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        vehicleIcon(vehicle.kind),
                        color: BookingStyle.blue,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            vehicle.brandModel.isEmpty
                                ? vehicle.kind.label
                                : vehicle.brandModel,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          if (vehicle.licensePlate.isNotEmpty)
                            Text(
                              vehicle.licensePlate,
                              style: const TextStyle(
                                color: BookingStyle.blue,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          Text(
                            [
                              vehicle.kind.label,
                              if (vehicle.color.isNotEmpty)
                                'Màu ${vehicle.color}',
                            ].join(' • '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: BookingStyle.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      selected
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: selected
                          ? BookingStyle.green
                          : const Color(0xFFC4C5D7),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
}

class RouteCard extends StatelessWidget {
  const RouteCard({
    super.key,
    required this.address,
    required this.coordinates,
  });
  final String address;
  final RescueCoordinates? coordinates;
  @override
  Widget build(BuildContext context) => IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 24,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.radio_button_checked,
                    size: 20,
                    color: BookingStyle.blue,
                  ),
                  Expanded(
                    child: Container(width: 2, color: const Color(0xFFE5EEFF)),
                  ),
                  const Icon(
                    Icons.flag_outlined,
                    size: 20,
                    color: BookingStyle.green,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'ĐIỂM ĐÓN XE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: BookingStyle.blue,
                    ),
                  ),
                  Text(
                    address.isNotEmpty
                        ? address
                        : coordinates?.label ?? 'Chưa chọn vị trí',
                  ),
                  if (coordinates != null)
                    const Text(
                      'Đã có tọa độ',
                      style: TextStyle(fontSize: 12, color: BookingStyle.green),
                    ),
                  const SizedBox(height: 16),
                  const Text(
                    'KÉO XE VỀ GARAGE',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: BookingStyle.green,
                    ),
                  ),
                  const Text(
                    'Chưa chọn nơi kéo về',
                    style: TextStyle(color: BookingStyle.muted),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
}

class PhotoPickerGrid extends StatelessWidget {
  const PhotoPickerGrid({
    super.key,
    required this.photos,
    required this.uploaded,
    required this.onRemove,
    required this.onAdd,
  });
  final List<SelectedRequestPhoto> photos;
  final Set<String> uploaded;
  final ValueChanged<int>? onRemove;
  final VoidCallback? onAdd;
  @override
  Widget build(BuildContext context) => Row(
        children: [
          for (var slot = 0; slot < 3; slot++) ...[
            if (slot > 0) const SizedBox(width: 10),
            Expanded(
              child: AspectRatio(
                aspectRatio: 1,
                child: slot < photos.length
                    ? Stack(
                        fit: StackFit.expand,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.memory(
                              photos[slot].bytes,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                          if (uploaded.contains(photos[slot].id))
                            const Align(
                              alignment: Alignment.bottomLeft,
                              child: ColoredBox(
                                color: BookingStyle.pale,
                                child: Padding(
                                  padding: EdgeInsets.all(4),
                                  child: Text('Đã gửi'),
                                ),
                              ),
                            ),
                          Align(
                            alignment: Alignment.topRight,
                            child: IconButton.filled(
                              tooltip: 'Bỏ ảnh',
                              onPressed: onRemove == null
                                  ? null
                                  : () => onRemove!(slot),
                              style: IconButton.styleFrom(
                                backgroundColor: BookingStyle.ink.withValues(
                                  alpha: .7,
                                ),
                                foregroundColor: Colors.white,
                              ),
                              icon: const Icon(Icons.close, size: 18),
                            ),
                          ),
                        ],
                      )
                    : Material(
                        color: BookingStyle.pale,
                        borderRadius: BorderRadius.circular(14),
                        child: InkWell(
                          onTap: onAdd,
                          borderRadius: BorderRadius.circular(14),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.add_a_photo_outlined,
                                color: BookingStyle.blue,
                              ),
                              if (slot == photos.length)
                                const Text(
                                  'Thêm ảnh',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: BookingStyle.blue,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
              ),
            ),
          ],
        ],
      );
}

class QuoteSummaryCard extends StatelessWidget {
  const QuoteSummaryCard({super.key});
  @override
  Widget build(BuildContext context) => const CustomerCard(
        title: 'Minh bạch cước phí',
        icon: Icons.receipt_long_outlined,
        children: [
          Text(
            'Báo giá sẽ được đối tác gửi sau khi tiếp nhận.',
            style: TextStyle(color: BookingStyle.muted),
          ),
        ],
      );
}

class PrimaryActionButton extends StatelessWidget {
  const PrimaryActionButton({
    super.key,
    required this.label,
    required this.loading,
    required this.onPressed,
  });
  final String label;
  final bool loading;
  final VoidCallback? onPressed;
  @override
  Widget build(BuildContext context) => RescueButton(
      label: loading ? 'Đang xử lý...' : label,
      loading: loading,
      icon: Icons.crisis_alert,
      onPressed: onPressed);
}

class CustomerBottomNav extends StatelessWidget {
  const CustomerBottomNav({super.key, required this.controller});
  final AppController controller;
  @override
  Widget build(BuildContext context) => DecoratedBox(
        decoration: const BoxDecoration(
          color: RescueColors.surface,
          border: Border(top: BorderSide(color: RescueColors.border)),
          boxShadow: RescueSurfaces.shadow,
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Row(
              children: [
                for (final item in const [
                  (0, Icons.home_outlined, 'Trang chủ'),
                  (2, Icons.location_on_outlined, 'Theo dõi'),
                  (1, Icons.sos, 'Đặt cứu hộ'),
                  (3, Icons.receipt_long_outlined, 'Lịch sử'),
                  (4, Icons.person_outline, 'Tài khoản'),
                ])
                  Expanded(
                    child: Semantics(
                      selected: controller.tabIndex == item.$1,
                      button: true,
                      child: InkWell(
                        onTap: () => controller.selectTab(item.$1),
                        borderRadius: BorderRadius.circular(RescueRadius.card),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 48,
                                height: 32,
                                decoration: BoxDecoration(
                                  color: controller.tabIndex == item.$1
                                      ? RescueColors.selected
                                      : Colors.transparent,
                                  borderRadius:
                                      BorderRadius.circular(RescueRadius.pill),
                                ),
                                child: Icon(
                                  item.$2,
                                  color: controller.tabIndex == item.$1
                                      ? BookingStyle.blue
                                      : BookingStyle.muted,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                item.$3,
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: controller.tabIndex == item.$1
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: controller.tabIndex == item.$1
                                      ? BookingStyle.blue
                                      : BookingStyle.muted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
}
