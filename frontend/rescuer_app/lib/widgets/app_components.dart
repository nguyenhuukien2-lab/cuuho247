import 'package:flutter/material.dart';

import '../app/app_theme.dart';

class AppCard extends StatelessWidget {
  const AppCard({super.key, required this.child, this.padding});
  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: padding ?? const EdgeInsets.all(AppSpace.lg),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadii.lg),
      border: Border.all(color: AppColors.line),
      boxShadow: const [
        BoxShadow(
          color: Color(0x0714263B),
          blurRadius: 18,
          offset: Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );
}

enum ButtonStyleKind { primary, secondary, outline, quiet, danger }

class AppButton extends StatelessWidget {
  const AppButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.kind = ButtonStyleKind.primary,
    this.loading = false,
    this.expand = true,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final ButtonStyleKind kind;
  final bool loading;
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final disabled = onPressed == null || loading;
    final child = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (loading)
          const SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else if (icon != null) ...[
          Icon(icon, size: 19),
          const SizedBox(width: 9),
        ],
        Text(label, textAlign: TextAlign.center),
      ],
    );

    final style = ButtonStyle(
      minimumSize: WidgetStateProperty.all(const Size(48, 52)),
      padding: WidgetStateProperty.all(
        const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
      ),
      shape: WidgetStateProperty.all(
        RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      textStyle: WidgetStateProperty.all(
        const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
      ),
    );

    final Widget button = switch (kind) {
      ButtonStyleKind.primary => FilledButton(
        onPressed: disabled ? null : onPressed,
        style: style.copyWith(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? AppColors.line
                : AppColors.orange,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.disabled)
                ? AppColors.muted
                : Colors.white,
          ),
        ),
        child: child,
      ),
      ButtonStyleKind.secondary => FilledButton.tonal(
        onPressed: disabled ? null : onPressed,
        style: style.copyWith(
          backgroundColor: WidgetStateProperty.all(AppColors.orangeSoft),
          foregroundColor: WidgetStateProperty.all(AppColors.navy),
        ),
        child: child,
      ),
      ButtonStyleKind.outline => OutlinedButton(
        onPressed: disabled ? null : onPressed,
        style: style.copyWith(
          foregroundColor: WidgetStateProperty.all(AppColors.navy),
          side: WidgetStateProperty.all(
            const BorderSide(color: AppColors.line),
          ),
        ),
        child: child,
      ),
      ButtonStyleKind.quiet => TextButton(
        onPressed: disabled ? null : onPressed,
        style: style.copyWith(
          foregroundColor: WidgetStateProperty.all(AppColors.navy),
        ),
        child: child,
      ),
      ButtonStyleKind.danger => FilledButton.tonal(
        onPressed: disabled ? null : onPressed,
        style: style.copyWith(
          backgroundColor: WidgetStateProperty.all(AppColors.dangerSoft),
          foregroundColor: WidgetStateProperty.all(AppColors.danger),
        ),
        child: child,
      ),
    };

    return button;
  }
}

enum BadgeTone { neutral, blue, orange, green, red }

class StatusBadge extends StatelessWidget {
  const StatusBadge({
    super.key,
    required this.label,
    this.tone = BadgeTone.neutral,
    this.icon,
  });
  final String label;
  final BadgeTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final (color, background) = switch (tone) {
      BadgeTone.neutral => (AppColors.muted, AppColors.background),
      BadgeTone.blue => (AppColors.blue, AppColors.blueSoft),
      BadgeTone.orange => (AppColors.warning, AppColors.warningSoft),
      BadgeTone.green => (AppColors.success, AppColors.successSoft),
      BadgeTone.red => (AppColors.danger, AppColors.dangerSoft),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 12,
              height: 1.1,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

enum PanelKind { loading, empty, unavailable, error, success }

class StatePanel extends StatelessWidget {
  const StatePanel({
    super.key,
    required this.kind,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.compact = false,
  });

  final PanelKind kind;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final (icon, color, background) = switch (kind) {
      PanelKind.loading => (
        Icons.more_horiz_rounded,
        AppColors.blue,
        AppColors.blueSoft,
      ),
      PanelKind.empty => (
        Icons.inbox_outlined,
        AppColors.muted,
        AppColors.background,
      ),
      PanelKind.unavailable => (
        Icons.cloud_off_outlined,
        AppColors.warning,
        AppColors.warningSoft,
      ),
      PanelKind.error => (
        Icons.error_outline_rounded,
        AppColors.danger,
        AppColors.dangerSoft,
      ),
      PanelKind.success => (
        Icons.check_circle_outline_rounded,
        AppColors.success,
        AppColors.successSoft,
      ),
    };
    return AppCard(
      padding: EdgeInsets.all(compact ? AppSpace.lg : AppSpace.xxl),
      child: Column(
        children: [
          if (kind == PanelKind.loading)
            const SizedBox.square(
              dimension: 34,
              child: CircularProgressIndicator(
                strokeWidth: 3,
                color: AppColors.navy,
              ),
            )
          else
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: background,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 25, color: color),
            ),
          const SizedBox(height: AppSpace.md),
          Text(title, textAlign: TextAlign.center, style: AppType.section),
          const SizedBox(height: AppSpace.xs),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppType.body.copyWith(color: AppColors.muted),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpace.lg),
            AppButton(
              label: actionLabel!,
              onPressed: onAction,
              kind: ButtonStyleKind.outline,
            ),
          ],
        ],
      ),
    );
  }
}

class InfoBanner extends StatelessWidget {
  const InfoBanner({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.info_outline_rounded,
    this.tone = BadgeTone.blue,
  });
  final String title;
  final String message;
  final IconData icon;
  final BadgeTone tone;

  @override
  Widget build(BuildContext context) {
    final (foreground, background) = switch (tone) {
      BadgeTone.neutral => (AppColors.navy, AppColors.background),
      BadgeTone.blue => (AppColors.blue, AppColors.blueSoft),
      BadgeTone.orange => (AppColors.warning, AppColors.warningSoft),
      BadgeTone.green => (AppColors.success, AppColors.successSoft),
      BadgeTone.red => (AppColors.danger, AppColors.dangerSoft),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSpace.md),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: foreground, size: 19),
          const SizedBox(width: AppSpace.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  message,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 12,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class PageHeading extends StatelessWidget {
  const PageHeading({
    super.key,
    required this.title,
    required this.subtitle,
    this.trailing,
  });
  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppType.pageTitle),
            const SizedBox(height: AppSpace.xs),
            Text(
              subtitle,
              style: AppType.body.copyWith(color: AppColors.muted),
            ),
          ],
        ),
      ),
      if (trailing != null) ...[const SizedBox(width: AppSpace.sm), trailing!],
    ],
  );
}

class LabeledValue extends StatelessWidget {
  const LabeledValue({
    super.key,
    required this.label,
    required this.value,
    this.icon,
  });
  final String label;
  final String value;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (icon != null) ...[
        Icon(icon, color: AppColors.muted, size: 18),
        const SizedBox(width: AppSpace.sm),
      ],
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: AppType.caption.copyWith(fontSize: 11)),
            const SizedBox(height: 2),
            Text(
              value,
              style: AppType.body.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    ],
  );
}

class MapPlaceholder extends StatelessWidget {
  const MapPlaceholder({
    super.key,
    this.height = 210,
    this.showApproximateArea = false,
  });
  final double height;
  final bool showApproximateArea;

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(AppRadii.lg),
    child: SizedBox(
      height: height,
      width: double.infinity,
      child: Stack(
        fit: StackFit.expand,
        children: [
          const CustomPaint(painter: _NeutralMapPainter()),
          if (showApproximateArea)
            Center(
              child: Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  color: AppColors.blue.withValues(alpha: 0.10),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppColors.blue.withValues(alpha: 0.30),
                    width: 1.5,
                  ),
                ),
                alignment: Alignment.center,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(AppRadii.pill),
                  ),
                  child: const Text(
                    'Khu vực gần đúng',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: AppColors.navy,
                    ),
                  ),
                ),
              ),
            ),
          Positioned(
            left: 12,
            top: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(AppRadii.sm),
                border: Border.all(color: AppColors.line),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.layers_outlined, size: 14, color: AppColors.muted),
                  SizedBox(width: 5),
                  Text(
                    'Bản đồ khu vực',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.navy,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _NeutralMapPainter extends CustomPainter {
  const _NeutralMapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final background = Paint()..color = const Color(0xFFEAF0EC);
    canvas.drawRect(Offset.zero & size, background);

    final park = Paint()..color = const Color(0xFFDDEADF);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.05,
          size.height * 0.10,
          size.width * 0.29,
          size.height * 0.28,
        ),
        const Radius.circular(22),
      ),
      park,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(
          size.width * 0.72,
          size.height * 0.66,
          size.width * 0.20,
          size.height * 0.23,
        ),
        const Radius.circular(20),
      ),
      park,
    );

    final roadEdge = Paint()
      ..color = const Color(0xFFD3DCD7)
      ..strokeWidth = 13
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final roads = [
      <Offset>[
        Offset(-10, size.height * .72),
        Offset(size.width * .28, size.height * .60),
        Offset(size.width * .54, size.height * .62),
        Offset(size.width + 12, size.height * .44),
      ],
      <Offset>[
        Offset(size.width * .38, -10),
        Offset(size.width * .44, size.height * .34),
        Offset(size.width * .39, size.height * .63),
        Offset(size.width * .53, size.height + 10),
      ],
      <Offset>[
        Offset(-10, size.height * .25),
        Offset(size.width * .22, size.height * .39),
        Offset(size.width * .64, size.height * .33),
        Offset(size.width + 10, size.height * .62),
      ],
    ];
    for (final points in roads) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final point in points.skip(1)) {
        path.lineTo(point.dx, point.dy);
      }
      canvas.drawPath(path, roadEdge);
      canvas.drawPath(
        path,
        Paint()
          ..color = const Color(0xFFFFFEFA)
          ..strokeWidth = 9
          ..style = PaintingStyle.stroke
          ..strokeCap = StrokeCap.round,
      );
    }
    final block = Paint()..color = const Color(0xFFE2E9E5);
    for (final rect in [
      Rect.fromLTWH(
        size.width * .63,
        size.height * .10,
        size.width * .20,
        size.height * .12,
      ),
      Rect.fromLTWH(
        size.width * .08,
        size.height * .82,
        size.width * .23,
        size.height * .12,
      ),
      Rect.fromLTWH(
        size.width * .71,
        size.height * .27,
        size.width * .18,
        size.height * .12,
      ),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(8)),
        block,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.hint,
    this.keyboardType,
    this.obscureText = false,
    this.suffixIcon,
    this.validator,
    this.maxLines = 1,
    this.textCapitalization = TextCapitalization.sentences,
  });

  final TextEditingController controller;
  final String label;
  final String? hint;
  final IconData icon;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final int maxLines;
  final TextCapitalization textCapitalization;

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    obscureText: obscureText,
    validator: validator,
    maxLines: obscureText ? 1 : maxLines,
    textCapitalization: textCapitalization,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: Icon(icon),
      suffixIcon: suffixIcon,
    ),
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle({super.key, required this.title, this.trailing});
  final String title;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(child: Text(title, style: AppType.section)),
      if (trailing != null) trailing!,
    ],
  );
}

class ScreenContent extends StatelessWidget {
  const ScreenContent({
    super.key,
    required this.children,
    this.bottomAction,
    this.padding = const EdgeInsets.fromLTRB(20, 16, 20, 28),
  });
  final List<Widget> children;
  final Widget? bottomAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => Scaffold(
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: _withGaps(children),
              ),
            ),
          ),
          if (bottomAction != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
              decoration: const BoxDecoration(
                color: AppColors.surface,
                border: Border(top: BorderSide(color: AppColors.line)),
              ),
              child: SafeArea(top: false, child: bottomAction!),
            ),
        ],
      ),
    ),
  );

  List<Widget> _withGaps(List<Widget> items) {
    final result = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) result.add(const SizedBox(height: AppSpace.lg));
      result.add(items[i]);
    }
    return result;
  }
}

class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 58, this.light = false});
  final double size;
  final bool light;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: light ? Colors.white.withValues(alpha: 0.12) : AppColors.navy,
      borderRadius: BorderRadius.circular(size * .30),
    ),
    child: Icon(
      Icons.car_repair_rounded,
      color: light ? Colors.white : AppColors.orange,
      size: size * .52,
    ),
  );
}
