import 'package:flutter/material.dart';

import '../app/app_controller.dart';
import '../app/app_theme.dart';

class PrimaryButton extends StatelessWidget {
  const PrimaryButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.icon,
      this.loading = false});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Semantics(
        button: true,
        liveRegion: loading,
        child: SizedBox(
          width: double.infinity,
          height: 54,
          child: FilledButton.icon(
            onPressed: loading ? null : onPressed,
            icon: loading
                ? const SizedBox.square(
                    dimension: 19,
                    child: CircularProgressIndicator(
                        strokeWidth: 2.3, color: AppColors.navy))
                : Icon(icon ?? Icons.arrow_forward_rounded, size: 24),
            label: Text(loading ? 'Đang xử lý...' : label),
            style: FilledButton.styleFrom(
                    disabledBackgroundColor: AppColors.orangeSoft,
                    disabledForegroundColor: AppColors.muted,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AppRadius.card)))
                .copyWith(
              backgroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.disabled)
                      ? AppColors.orangeSoft
                      : states.contains(WidgetState.pressed)
                          ? AppColors.orangePressed
                          : AppColors.orange),
              foregroundColor: WidgetStateProperty.resolveWith(
                  (states) => states.contains(WidgetState.disabled)
                      ? AppColors.muted
                      : states.contains(WidgetState.pressed)
                          ? Colors.white
                          : AppColors.text),
            ),
          ),
        ));
  }
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.subtitle, this.trailing});
  final String title;
  final String? subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(subtitle!, style: Theme.of(context).textTheme.bodySmall)
          ]
        ])),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class DemoBadge extends StatelessWidget {
  const DemoBadge({super.key});
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
            color: const Color(0xFFFFFAEB),
            border: Border.all(color: const Color(0xFFFEC84B)),
            borderRadius: BorderRadius.circular(20)),
        child: const Text('CHẾ ĐỘ DEMO',
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                color: AppColors.warning)),
      );
}

class ChoiceTile extends StatelessWidget {
  const ChoiceTile(
      {super.key,
      required this.icon,
      required this.label,
      required this.selected,
      required this.onTap});
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Semantics(
      selected: selected,
      button: true,
      enabled: onTap != null,
      child: AnimatedContainer(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 76),
          decoration: BoxDecoration(
              color: selected ? AppColors.selected : AppColors.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: selected ? AppColors.navy : AppColors.border,
                  width: selected ? 1.5 : 1)),
          child: Material(
              color: Colors.transparent,
              child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        Icon(icon,
                            size: 24,
                            color: selected ? AppColors.navy : AppColors.muted),
                        const SizedBox(width: 8),
                        Expanded(
                            child: Text(label,
                                style: TextStyle(
                                    fontSize: 15,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.w600,
                                    color: onTap == null
                                        ? AppColors.muted
                                        : selected
                                            ? AppColors.navy
                                            : AppColors.text))),
                      ]))))));
}

class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.stage});
  final RequestStage stage;
  @override
  Widget build(BuildContext context) {
    final (label, color, icon) = switch (stage) {
      RequestStage.searching => (
          'Đang tìm',
          AppColors.warning,
          Icons.search_rounded
        ),
      RequestStage.accepted => (
          'Đã nhận',
          AppColors.info,
          Icons.task_alt_rounded
        ),
      RequestStage.arriving => (
          'Đang đến',
          AppColors.info,
          Icons.navigation_rounded
        ),
      RequestStage.inProgress => (
          'Đang hỗ trợ',
          AppColors.progress,
          Icons.build_rounded
        ),
      RequestStage.completed => (
          'Hoàn tất',
          AppColors.success,
          Icons.check_circle_rounded
        ),
      RequestStage.cancelled => (
          'Đã hủy',
          AppColors.error,
          Icons.cancel_rounded
        ),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
          color: color.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(20)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 15, color: color),
        const SizedBox(width: 5),
        Text(label,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppColors.text))
      ]),
    );
  }
}

class MapPreview extends StatelessWidget {
  const MapPreview(
      {super.key,
      this.height = 220,
      this.showHelpers = true,
      this.onLocationPressed});
  final double height;
  final bool showHelpers;
  final VoidCallback? onLocationPressed;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: SizedBox(
          height: height,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CustomPaint(painter: _MapPainter()),
              Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 9, vertical: 5),
                      decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: .94),
                          borderRadius: BorderRadius.circular(8)),
                      child: const Text('Bản đồ minh họa',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: AppColors.muted)))),
              const Align(
                  alignment: Alignment(0, .05),
                  child: _MapPin(
                      icon: Icons.person_pin_circle_rounded,
                      color: AppColors.orange)),
              if (showHelpers)
                const Align(
                    alignment: Alignment(-.58, -.45),
                    child: _MapPin(
                        icon: Icons.local_shipping_rounded,
                        color: AppColors.navy)),
              if (showHelpers)
                const Align(
                    alignment: Alignment(.62, -.25),
                    child: _MapPin(
                        icon: Icons.handyman_rounded, color: AppColors.navy)),
              Positioned(
                  right: 12,
                  bottom: 12,
                  child: FloatingActionButton.small(
                      heroTag: null,
                      onPressed: onLocationPressed,
                      backgroundColor: Colors.white,
                      foregroundColor: AppColors.navy,
                      child: const Icon(Icons.my_location_rounded))),
            ],
          ),
        ),
      );
}

class _MapPin extends StatelessWidget {
  const _MapPin({required this.icon, required this.color});
  final IconData icon;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 3),
          boxShadow: const [
            BoxShadow(
                color: Color(0x33000000), blurRadius: 8, offset: Offset(0, 3))
          ]),
      child: Icon(icon, size: 21, color: Colors.white));
}

class _MapPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
        Offset.zero & size, Paint()..color = const Color(0xFFE8EEF2));
    final minor = Paint()
      ..color = const Color(0xFFD6E0E6)
      ..strokeWidth = 1;
    for (double x = -size.height; x < size.width; x += 38)
      canvas.drawLine(
          Offset(x, 0), Offset(x + size.height, size.height), minor);
    for (double y = 18; y < size.height; y += 45)
      canvas.drawLine(Offset(0, y), Offset(size.width, y), minor);
    final road = Paint()
      ..color = Colors.white
      ..strokeWidth = 16
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(-20, size.height * .72),
        Offset(size.width + 20, size.height * .26), road);
    canvas.drawLine(Offset(size.width * .25, -20),
        Offset(size.width * .68, size.height + 20), road);
    final route = Paint()
      ..color = AppColors.navy.withValues(alpha: .7)
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(size.width * .18, size.height * .65),
        Offset(size.width * .78, size.height * .36), route);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

IconData serviceIcon(RescueService service) => switch (service) {
      RescueService.tire => Icons.tire_repair_rounded,
      RescueService.battery => Icons.battery_charging_full_rounded,
      RescueService.fuel => Icons.local_gas_station_rounded,
      RescueService.towing => Icons.local_shipping_rounded,
      RescueService.other => Icons.more_horiz_rounded,
    };

IconData vehicleIcon(VehicleKind kind) => switch (kind) {
      VehicleKind.motorbike => Icons.two_wheeler_rounded,
      VehicleKind.car => Icons.directions_car_rounded,
      VehicleKind.truck => Icons.local_shipping_outlined,
      VehicleKind.other => Icons.commute_rounded,
    };

String money(int? value) {
  if (value == null) return 'Chờ báo giá';
  final digits = value.toString();
  final result = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) result.write('.');
    result.write(digits[i]);
  }
  return '${result}đ';
}
