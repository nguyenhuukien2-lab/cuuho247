import 'stitch_customer_header.dart';
import '../app/mobile_ui.dart';
import '../core/utils/display_code.dart';
import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../services/customer_vehicle_service.dart';
import '../services/location_service.dart';
import '../services/request_photo_service.dart';
import 'rescue_widgets.dart';
import 'booking_form_ui.dart';

// Compatibility adapter: booking screens now inherit the app-wide theme.
abstract final class BookingStyle {
  static const blue = RescueColors.navy, green = RescueColors.success;
  static const background = RescueColors.background,
      pale = RescueColors.selected;
  static const ink = RescueColors.ink, muted = RescueColors.muted;
  static ThemeData theme(BuildContext context) => Theme.of(context);
}

class CustomerAppHeader extends StatelessWidget {
  const CustomerAppHeader(
      {super.key, required this.onAccount, this.customerCode});
  final VoidCallback onAccount;
  final String? customerCode;
  @override
  Widget build(BuildContext context) => StitchCustomerHeader(
      onAccount: onAccount,
      subtitle:
          customerCode == null ? 'Khách Hàng' : displayCode(customerCode));
}

class CustomerStepIndicator extends StatelessWidget {
  const CustomerStepIndicator({
    super.key,
    required this.step,
    required this.onStep,
    this.serviceSelected = false,
  });
  final int step;
  final ValueChanged<int>? onStep;
  final bool serviceSelected;
  int get visualStep => step == 0 && serviceSelected ? 1 : step;
  @override
  Widget build(BuildContext context) => Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: LayoutBuilder(
            builder: (context, constraints) => Stack(
              children: [
                Positioned(
                  top: 19,
                  left: constraints.maxWidth / 10,
                  right: constraints.maxWidth / 10,
                  child: SizedBox(
                    height: 3,
                    child: Row(
                      children: [
                        for (var connector = 0; connector < 4; connector++)
                          Expanded(
                            child: ColoredBox(
                              key: ValueKey('request-connector-$connector'),
                              color: connector < visualStep
                                  ? BookingFormStyle.green
                                  : BookingFormStyle.border,
                              child: const SizedBox(height: 3),
                            ),
                          ),
                      ],
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
                            DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: entry.key == visualStep
                                    ? BookingFormStyle.blue
                                        .withValues(alpha: .10)
                                    : Colors.transparent,
                              ),
                              child: ChoiceChip(
                                key: ValueKey('request-step-${entry.key}'),
                                selected: visualStep == entry.key,
                                showCheckmark: false,
                                padding: EdgeInsets.zero,
                                labelPadding: const EdgeInsets.all(7),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.padded,
                                shape: const CircleBorder(),
                                side: BorderSide(
                                  color: visualStep == entry.key
                                      ? BookingFormStyle.blue
                                          .withValues(alpha: .2)
                                      : Colors.transparent,
                                  width: 3,
                                ),
                                selectedColor: BookingFormStyle.blue,
                                backgroundColor: entry.key < visualStep
                                    ? BookingFormStyle.green
                                    : const Color(0xFFE7ECF5),
                                label: entry.key < visualStep
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
                                              color: entry.key == visualStep
                                                  ? Colors.white
                                                  : BookingFormStyle.muted,
                                            ),
                                          ),
                                        ),
                                      ),
                                onSelected: onStep == null
                                    ? null
                                    : (_) => onStep!(entry.key),
                              ),
                            ),
                            Text(
                              entry.value,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: entry.key < visualStep
                                    ? BookingFormStyle.green
                                    : entry.key == visualStep
                                        ? BookingFormStyle.blue
                                        : BookingFormStyle.muted,
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
    this.trailing,
  });
  final String title;
  final String? subtitle;
  final Widget? trailing;
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
              if (title.isNotEmpty)
                Row(
                  children: [
                    Icon(icon, size: 20, color: BookingFormStyle.blue),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: BookingFormStyle.navy),
                      ),
                    ),
                    if (trailing != null) trailing!,
                  ],
                ),
              if (subtitle != null) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle!,
                  style: const TextStyle(
                      fontSize: 12, color: BookingFormStyle.muted),
                ),
              ],
              if (title.isNotEmpty) const SizedBox(height: 12),
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
      key: const ValueKey('booking-selected-service'),
      elevation: 1,
      shadowColor: BookingFormStyle.navy.withValues(alpha: .08),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: BookingFormStyle.border)),
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(
                  child: Align(
                      alignment: Alignment.centerLeft,
                      child: BookingFormBadge('Đã chọn',
                          color: Color(0xFF15803D),
                          background: Color(0xFFDCFCE7)))),
              const SizedBox(width: 8),
              Flexible(
                  child: TextButton(
                      onPressed: onChange,
                      style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF1D4ED8),
                          textStyle: const TextStyle(
                              fontFamily: 'Plus Jakarta Sans',
                              fontSize: 12,
                              fontWeight: FontWeight.w600)),
                      child: const Text('Đổi dịch vụ',
                          textAlign: TextAlign.center))),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                      color: BookingFormStyle.pale,
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(serviceIcon(service),
                      size: 28, color: const Color(0xFF1D4ED8))),
              const SizedBox(width: 12),
              Expanded(
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                    Text(service.label,
                        style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: BookingFormStyle.ink)),
                    const SizedBox(height: 4),
                    Text(
                        switch (service) {
                          RescueService.tire => 'Sự cố lốp xe',
                          RescueService.battery => 'Sự cố bình ắc quy',
                          RescueService.towing => 'Phương tiện cần di chuyển',
                          RescueService.fuel => 'Xe cần bổ sung nhiên liệu',
                          RescueService.other => 'Các tình huống cứu hộ khác',
                        },
                        style: const TextStyle(
                            fontSize: 12, color: BookingFormStyle.muted)),
                    const SizedBox(height: 4),
                    const Text('Báo giá sau khi tiếp nhận',
                        style: TextStyle(
                            fontSize: 12, color: BookingFormStyle.muted)),
                  ])),
            ]),
          ])));
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
            color: selected ? BookingFormStyle.pale : Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: selected
                    ? const Color(0xFFC7D9FF)
                    : BookingFormStyle.border,
                width: 1,
              ),
            ),
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(16),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 52,
                      height: 52,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEAF2FF),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        vehicleIcon(vehicle.kind),
                        size: 28,
                        color: const Color(0xFF1D4ED8),
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
                              color: BookingFormStyle.ink,
                            ),
                          ),
                          if (vehicle.licensePlate.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(
                              vehicle.licensePlate,
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF1D4ED8),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                          const SizedBox(height: 3),
                          Text(
                            [
                              vehicle.kind.label,
                              if (vehicle.color.isNotEmpty)
                                'Màu ${vehicle.color}',
                            ].join(' • '),
                            style: const TextStyle(
                              fontSize: 12,
                              color: BookingFormStyle.muted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      key: ValueKey(selected
                          ? 'booking-vehicle-selected'
                          : 'booking-vehicle-unselected'),
                      width: selected ? 28 : 26,
                      height: selected ? 28 : 26,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: selected ? BookingFormStyle.green : Colors.white,
                        border: selected
                            ? null
                            : Border.all(color: const Color(0xFFCBD5E1)),
                      ),
                      child: selected
                          ? const Icon(Icons.check,
                              color: Colors.white, size: 18)
                          : null,
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
  const RouteCard(
      {super.key, required this.address, required this.coordinates});
  final String address;
  final RescueCoordinates? coordinates;
  @override
  Widget build(BuildContext context) =>
      BookingPickupPoint(address: address, coordinates: coordinates);
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
  Widget build(BuildContext context) => LayoutBuilder(
      builder: (context, constraints) => Row(children: [
            for (var slot = 0; slot < 3; slot++) ...[
              if (slot > 0) const SizedBox(width: 10),
              SizedBox(
                  width: (constraints.maxWidth - 20) / 3,
                  height: (constraints.maxWidth - 20) / 3,
                  child: slot < photos.length
                      ? Stack(fit: StackFit.expand, children: [
                          ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.memory(photos[slot].bytes,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.broken_image_outlined))),
                          if (uploaded.contains(photos[slot].id))
                            const Align(
                                alignment: Alignment.bottomLeft,
                                child: ColoredBox(
                                    color: BookingFormStyle.pale,
                                    child: Padding(
                                        padding: EdgeInsets.all(4),
                                        child: Text('Đã gửi',
                                            style: TextStyle(fontSize: 11))))),
                          Align(
                              alignment: Alignment.topRight,
                              child: IconButton.filled(
                                  tooltip: 'Bỏ ảnh',
                                  onPressed: onRemove == null
                                      ? null
                                      : () => onRemove!(slot),
                                  style: IconButton.styleFrom(
                                      backgroundColor: BookingFormStyle.ink
                                          .withValues(alpha: .7),
                                      foregroundColor: Colors.white,
                                      fixedSize: const Size(30, 30)),
                                  icon: const Icon(Icons.close, size: 16))),
                        ])
                      : slot > photos.length
                          ? DecoratedBox(
                              decoration: BoxDecoration(
                                  color: BookingFormStyle.pale,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                      color: BookingFormStyle.border)),
                              child: const Icon(Icons.photo_outlined,
                                  color: BookingFormStyle.muted))
                          : Material(
                              color: BookingFormStyle.pale,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: const BorderSide(
                                      color: BookingFormStyle.border)),
                              child: InkWell(
                                  onTap: onAdd,
                                  borderRadius: BorderRadius.circular(12),
                                  child: const Column(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.add_a_photo_outlined,
                                            color: BookingFormStyle.blue,
                                            size: 26),
                                        SizedBox(height: 6),
                                        Text('Thêm ảnh',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                                fontSize: 11,
                                                height: 1.2,
                                                color: BookingFormStyle.blue)),
                                      ])))),
            ],
          ]));
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
  Widget build(BuildContext context) => Stack(children: [
        Positioned.fill(
            top: 24,
            child: DecoratedBox(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(20)),
                    boxShadow: [
                  BoxShadow(
                      color: RescueColors.navy.withValues(alpha: .08),
                      blurRadius: 20,
                      offset: const Offset(0, -4))
                ]))),
        SafeArea(
            top: false,
            child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 104),
                child: IntrinsicHeight(
                    child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                      for (final item in const [
                        (
                          0,
                          Icons.home_outlined,
                          Icons.home_rounded,
                          'Trang chủ'
                        ),
                        (
                          2,
                          Icons.location_on_outlined,
                          Icons.location_on_rounded,
                          'Theo dõi'
                        ),
                        (1, Icons.sos_rounded, Icons.sos_rounded, 'Đặt cứu hộ'),
                        (
                          3,
                          Icons.receipt_long_outlined,
                          Icons.receipt_long_rounded,
                          'Lịch sử'
                        ),
                        (
                          4,
                          Icons.person_outline,
                          Icons.person_rounded,
                          'Tài khoản'
                        ),
                      ])
                        Expanded(
                            child: Semantics(
                                selected: controller.tabIndex == item.$1,
                                button: true,
                                child: Material(
                                    color: Colors.transparent,
                                    child: InkWell(
                                      onTap: () =>
                                          controller.selectTab(item.$1),
                                      borderRadius: BorderRadius.circular(20),
                                      child: Padding(
                                          padding: EdgeInsets.fromLTRB(
                                              2, item.$1 == 1 ? 0 : 40, 2, 12),
                                          child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Container(
                                                    key: item.$1 == 1
                                                        ? const ValueKey(
                                                            'customer-booking-nav-circle')
                                                        : null,
                                                    width:
                                                        item.$1 == 1 ? 56 : 24,
                                                    height:
                                                        item.$1 == 1 ? 56 : 24,
                                                    decoration: item.$1 == 1
                                                        ? const BoxDecoration(
                                                            shape: BoxShape.circle,
                                                            color: Color(0xFF1D4ED8),
                                                            boxShadow: [
                                                                BoxShadow(
                                                                    color: Color(
                                                                        0x331D4ED8),
                                                                    blurRadius:
                                                                        12,
                                                                    offset:
                                                                        Offset(
                                                                            0,
                                                                            4))
                                                              ])
                                                        : null,
                                                    child: item.$1 == 1
                                                        ? const Center(
                                                            child: SizedBox.square(
                                                                dimension: 30,
                                                                child: CustomPaint(
                                                                    painter:
                                                                        _RescueSirenPainter())))
                                                        : Icon(
                                                            controller.tabIndex ==
                                                                    item.$1
                                                                ? item.$3
                                                                : item.$2,
                                                            size: item.$1 == 1
                                                                ? 28
                                                                : 24,
                                                            color: item.$1 == 1
                                                                ? Colors.white
                                                                : controller.tabIndex == item.$1
                                                                    ? RescueColors.navy
                                                                    : RescueColors.muted)),
                                                SizedBox(
                                                    height:
                                                        item.$1 == 1 ? 16 : 8),
                                                ConstrainedBox(
                                                    constraints:
                                                        const BoxConstraints(
                                                            minHeight: 20),
                                                    child: Text(item.$4,
                                                        textAlign: TextAlign
                                                            .center,
                                                        style: TextStyle(
                                                            fontSize: 11,
                                                            height: 14 / 11,
                                                            fontWeight:
                                                                controller.tabIndex ==
                                                                        item.$1
                                                                    ? FontWeight
                                                                        .w800
                                                                    : FontWeight
                                                                        .w500,
                                                            color: controller
                                                                        .tabIndex ==
                                                                    item.$1
                                                                ? RescueColors
                                                                    .navy
                                                                : RescueColors
                                                                    .muted))),
                                              ])),
                                    )))),
                    ])))),
      ]);
}

class _RescueSirenPainter extends CustomPainter {
  const _RescueSirenPainter();
  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 28, size.height / 28);
    final stroke = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(
        Path()
          ..moveTo(8, 21)
          ..lineTo(9.5, 12)
          ..quadraticBezierTo(14, 6, 18.5, 12)
          ..lineTo(20, 21)
          ..close(),
        stroke);
    canvas.drawLine(const Offset(6, 24), const Offset(22, 24), stroke);
    for (final ray in const [
      (Offset(14, 1), Offset(14, 5)),
      (Offset(4, 5), Offset(7, 8)),
      (Offset(24, 5), Offset(21, 8)),
      (Offset(1, 14), Offset(5, 14)),
      (Offset(23, 14), Offset(27, 14)),
    ]) {
      canvas.drawLine(ray.$1, ray.$2, stroke);
    }
    canvas.drawLine(const Offset(12, 13), const Offset(11.5, 17), stroke);
  }

  @override
  bool shouldRepaint(covariant _RescueSirenPainter oldDelegate) => false;
}
