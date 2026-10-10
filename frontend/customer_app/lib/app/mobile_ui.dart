import 'package:flutter/material.dart';

// Customer app tokens measured from the five Xanh Tech Stitch screens.
abstract final class RescueColors {
  static const navy = Color(0xFF0037B0);
  static const navySoft = Color(0xFF2151DA);
  static const accent = Color(0xFF1D4ED8);
  static const accentPressed = Color(0xFF0037B0);
  static const accentSoft = Color(0xFFE9EFFF);
  static const background = Color(0xFFF8F9FF);
  static const surface = Colors.white;
  static const ink = Color(0xFF0B1C30);
  static const muted = Color(0xFF434655);
  static const border = Color(0xFFDCE3EA);
  static const selected = Color(0xFFEAF0F6);
  static const disabled = Color(0xFFE5EAF0);
  static const success = Color(0xFF006C49);
  static const successSoft = Color(0xFFE9F7F0);
  static const warning = Color(0xFF8A570B);
  static const warningSoft = Color(0xFFFFF5E5);
  static const danger = Color(0xFFBA1A1A);
  static const dangerSoft = Color(0xFFFFDAD6);
  static const info = Color(0xFF245B91);
  static const infoSoft = Color(0xFFEDF4FA);
  static const progress = Color(0xFF51428F);
  static const progressSoft = Color(0xFFF1EEFA);
}

abstract final class RescueSpace {
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0;
  static const xl = 24.0, xxl = 32.0;
  static const page = EdgeInsets.fromLTRB(20, 16, 20, 32);
}

abstract final class RescueRadius {
  static const small = 8.0, control = 12.0, card = 16.0, pill = 100.0;
}

abstract final class RescueType {
  static const page = TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 24,
      height: 32 / 24,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
      color: RescueColors.ink);
  static const section = TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 18,
      height: 24 / 18,
      fontWeight: FontWeight.w700,
      letterSpacing: 0,
      color: RescueColors.ink);
  static const title = TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 16,
      height: 20 / 16,
      fontWeight: FontWeight.w600,
      color: RescueColors.ink);
  static const body = TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 14,
      height: 20 / 14,
      color: RescueColors.ink);
  static const caption = TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 12,
      height: 16 / 12,
      color: RescueColors.muted);
  static const code = TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 13,
      height: 1.4,
      fontWeight: FontWeight.w600,
      letterSpacing: .2,
      color: RescueColors.muted);
  static const status = TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 12,
      height: 1.35,
      fontWeight: FontWeight.w600);
  static const button = TextStyle(
      fontFamily: 'Plus Jakarta Sans',
      fontSize: 16,
      height: 20 / 16,
      fontWeight: FontWeight.w700,
      letterSpacing: 0);
}

enum RescueButtonKind { primary, secondary, outline, quiet, danger }

abstract final class RescueButtons {
  static ButtonStyle style(RescueButtonKind kind) {
    final background = switch (kind) {
      RescueButtonKind.primary => RescueColors.accent,
      RescueButtonKind.secondary => RescueColors.selected,
      RescueButtonKind.danger => RescueColors.dangerSoft,
      _ => Colors.transparent,
    };
    final foreground = switch (kind) {
      RescueButtonKind.primary => Colors.white,
      RescueButtonKind.danger => RescueColors.danger,
      _ => RescueColors.navy,
    };
    return ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(48, 56)),
      padding: const WidgetStatePropertyAll(
          EdgeInsets.symmetric(horizontal: 16, vertical: 14)),
      textStyle: const WidgetStatePropertyAll(RescueType.button),
      elevation: const WidgetStatePropertyAll(0),
      shape: WidgetStatePropertyAll(RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(RescueRadius.control))),
      backgroundColor: WidgetStateProperty.resolveWith((states) {
        if (states.contains(WidgetState.disabled)) {
          return kind == RescueButtonKind.quiet ||
                  kind == RescueButtonKind.outline
              ? Colors.transparent
              : RescueColors.disabled;
        }
        if (kind == RescueButtonKind.primary &&
            states.contains(WidgetState.pressed)) {
          return RescueColors.accentPressed;
        }
        return background;
      }),
      foregroundColor: WidgetStateProperty.resolveWith((states) =>
          states.contains(WidgetState.disabled)
              ? RescueColors.muted
              : foreground),
      side: kind == RescueButtonKind.outline
          ? const WidgetStatePropertyAll(BorderSide(color: RescueColors.border))
          : null,
    );
  }
}

class RescueButton extends StatelessWidget {
  const RescueButton(
      {super.key,
      required this.label,
      required this.onPressed,
      this.icon,
      this.kind = RescueButtonKind.primary,
      this.loading = false,
      this.expand = true});
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final RescueButtonKind kind;
  final bool loading, expand;

  @override
  Widget build(BuildContext context) {
    final child = Row(
        mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading) ...[
            const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: RescueColors.muted)),
            const SizedBox(width: RescueSpace.sm),
          ] else if (icon != null) ...[
            Icon(icon, size: 20),
            const SizedBox(width: RescueSpace.sm),
          ],
          Flexible(child: Text(label, textAlign: TextAlign.center)),
        ]);
    final callback = loading ? null : onPressed;
    final style = RescueButtons.style(kind);
    final Widget button = switch (kind) {
      RescueButtonKind.outline =>
        OutlinedButton(onPressed: callback, style: style, child: child),
      RescueButtonKind.quiet =>
        TextButton(onPressed: callback, style: style, child: child),
      _ => FilledButton(onPressed: callback, style: style, child: child),
    };
    return Semantics(liveRegion: loading, child: button);
  }
}

enum RescueCardKind { information, order, history, status, profile }

abstract final class RescueSurfaces {
  static const shadow = [
    BoxShadow(color: Color(0x080B2540), blurRadius: 8, offset: Offset(0, 2))
  ];
  static BoxDecoration decoration(
          [RescueCardKind kind = RescueCardKind.information]) =>
      BoxDecoration(
          color: RescueColors.surface,
          borderRadius: BorderRadius.circular(RescueRadius.card),
          border: Border.all(
              color: kind == RescueCardKind.status
                  ? RescueColors.navy.withValues(alpha: .24)
                  : RescueColors.border),
          boxShadow:
              kind == RescueCardKind.order || kind == RescueCardKind.status
                  ? shadow
                  : null);
}

class RescueCard extends StatelessWidget {
  const RescueCard(
      {super.key,
      required this.child,
      this.kind = RescueCardKind.information,
      this.padding = const EdgeInsets.all(RescueSpace.lg)});
  final Widget child;
  final RescueCardKind kind;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) => Container(
      width: double.infinity,
      decoration: RescueSurfaces.decoration(kind),
      child: Material(
          type: MaterialType.transparency,
          borderRadius: BorderRadius.circular(RescueRadius.card),
          clipBehavior: Clip.antiAlias,
          child: Padding(padding: padding, child: child)));
}

// Presentation mapping only: no state transitions or domain model conversion.
abstract final class RescueStatus {
  static (String, Color, Color, IconData) appearance(String? status) =>
      switch (status) {
        'searching' => (
            'Đang tìm',
            RescueColors.warning,
            RescueColors.warningSoft,
            Icons.search_rounded
          ),
        'accepted' => (
            'Đã nhận',
            RescueColors.info,
            RescueColors.infoSoft,
            Icons.task_alt_rounded
          ),
        'arriving' || 'en_route' => (
            'Đang đến',
            RescueColors.info,
            RescueColors.infoSoft,
            Icons.navigation_rounded
          ),
        'arrived' => (
            'Đã đến nơi',
            RescueColors.info,
            RescueColors.infoSoft,
            Icons.place_outlined
          ),
        'in_progress' => (
            'Đang hỗ trợ',
            RescueColors.progress,
            RescueColors.progressSoft,
            Icons.build_outlined
          ),
        'completed' => (
            'Hoàn tất',
            RescueColors.success,
            RescueColors.successSoft,
            Icons.check_circle_outline
          ),
        'cancelled' => (
            'Đã hủy',
            RescueColors.danger,
            RescueColors.dangerSoft,
            Icons.cancel_outlined
          ),
        'approved' => (
            'Đã được duyệt',
            RescueColors.success,
            RescueColors.successSoft,
            Icons.verified_outlined
          ),
        'pending' || 'submitted' => (
            'Đang chờ duyệt',
            RescueColors.warning,
            RescueColors.warningSoft,
            Icons.schedule
          ),
        'suspended' => (
            'Tạm ngưng hoạt động',
            RescueColors.danger,
            RescueColors.dangerSoft,
            Icons.pause_circle_outline
          ),
        'rejected' => (
            'Bị từ chối',
            RescueColors.danger,
            RescueColors.dangerSoft,
            Icons.cancel_outlined
          ),
        'expired' => (
            'Hết hạn',
            RescueColors.danger,
            RescueColors.dangerSoft,
            Icons.event_busy_outlined
          ),
        'draft' => (
            'Hồ sơ nháp',
            RescueColors.muted,
            RescueColors.selected,
            Icons.edit_outlined
          ),
        null => (
            'Chưa nộp',
            RescueColors.muted,
            RescueColors.selected,
            Icons.info_outline
          ),
        _ => (
            'Chưa xác định',
            RescueColors.muted,
            RescueColors.selected,
            Icons.info_outline
          ),
      };
}

class RescueStatusBadge extends StatelessWidget {
  const RescueStatusBadge({super.key, required this.status, this.label});
  final String? status, label;
  @override
  Widget build(BuildContext context) {
    final (title, color, background, icon) = RescueStatus.appearance(status);
    return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(RescueRadius.pill)),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Flexible(
              child: Text(label ?? title,
                  style: RescueType.status.copyWith(color: color))),
        ]));
  }
}

enum RescueFeedbackKind { empty, loading, error, unavailable, success }

class RescueFeedback extends StatelessWidget {
  const RescueFeedback(
      {super.key,
      required this.title,
      required this.message,
      this.kind = RescueFeedbackKind.empty,
      this.icon,
      this.action,
      this.compact = false});
  final String title, message;
  final RescueFeedbackKind kind;
  final IconData? icon;
  final Widget? action;
  final bool compact;
  @override
  Widget build(BuildContext context) {
    final (color, background, fallback) = switch (kind) {
      RescueFeedbackKind.error => (
          RescueColors.danger,
          RescueColors.dangerSoft,
          Icons.error_outline
        ),
      RescueFeedbackKind.unavailable => (
          RescueColors.warning,
          RescueColors.warningSoft,
          Icons.cloud_off_outlined
        ),
      RescueFeedbackKind.success => (
          RescueColors.success,
          RescueColors.successSoft,
          Icons.check_circle_outline
        ),
      _ => (RescueColors.navy, RescueColors.selected, Icons.inbox_outlined),
    };
    return Semantics(
        liveRegion: kind != RescueFeedbackKind.empty,
        child: Padding(
            padding: EdgeInsets.all(compact ? RescueSpace.lg : RescueSpace.xl),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: background,
                      borderRadius:
                          BorderRadius.circular(RescueRadius.control)),
                  child: kind == RescueFeedbackKind.loading
                      ? const SizedBox.square(
                          dimension: 24,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Icon(icon ?? fallback, size: 26, color: color)),
              const SizedBox(height: RescueSpace.lg),
              Text(title,
                  textAlign: TextAlign.center, style: RescueType.section),
              const SizedBox(height: RescueSpace.sm),
              Text(message,
                  textAlign: TextAlign.center,
                  style: RescueType.body.copyWith(color: RescueColors.muted)),
              if (action != null) ...[
                const SizedBox(height: RescueSpace.lg),
                action!
              ],
            ])));
  }
}

abstract final class RescueTheme {
  static ThemeData get light {
    final outline = OutlineInputBorder(
        borderRadius: BorderRadius.circular(RescueRadius.control),
        borderSide: const BorderSide(color: RescueColors.border));
    return ThemeData(
        useMaterial3: true,
        fontFamily: 'Plus Jakarta Sans',
        scaffoldBackgroundColor: RescueColors.background,
        colorScheme: ColorScheme.fromSeed(
            seedColor: RescueColors.navy,
            primary: RescueColors.navy,
            onPrimary: Colors.white,
            primaryContainer: RescueColors.selected,
            onPrimaryContainer: RescueColors.navy,
            secondary: RescueColors.accent,
            onSecondary: Colors.white,
            secondaryContainer: RescueColors.selected,
            onSecondaryContainer: RescueColors.navy,
            surface: RescueColors.surface,
            onSurface: RescueColors.ink,
            onSurfaceVariant: RescueColors.muted,
            outline: RescueColors.border,
            error: RescueColors.danger),
        textTheme: const TextTheme(
            headlineSmall: RescueType.page,
            titleLarge: RescueType.section,
            titleMedium: RescueType.title,
            bodyLarge:
                TextStyle(fontSize: 16, height: 1.5, color: RescueColors.ink),
            bodyMedium: RescueType.body,
            bodySmall: RescueType.caption,
            labelLarge: RescueType.button,
            labelMedium: RescueType.status,
            labelSmall: RescueType.caption),
        appBarTheme: const AppBarTheme(
            backgroundColor: RescueColors.background,
            foregroundColor: RescueColors.ink,
            surfaceTintColor: Colors.transparent,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            titleTextStyle: TextStyle(
                fontFamily: 'Plus Jakarta Sans',
                fontSize: 20,
                height: 1.3,
                fontWeight: FontWeight.w700,
                color: RescueColors.ink)),
        cardTheme: CardThemeData(
            color: RescueColors.surface,
            elevation: 0,
            surfaceTintColor: Colors.transparent,
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(RescueRadius.card),
                side: const BorderSide(color: RescueColors.border))),
        filledButtonTheme: FilledButtonThemeData(
            style: RescueButtons.style(RescueButtonKind.primary)),
        elevatedButtonTheme: ElevatedButtonThemeData(
            style: RescueButtons.style(RescueButtonKind.primary)),
        outlinedButtonTheme: OutlinedButtonThemeData(
            style: RescueButtons.style(RescueButtonKind.outline)),
        textButtonTheme: TextButtonThemeData(
            style: RescueButtons.style(RescueButtonKind.quiet)),
        iconTheme: const IconThemeData(size: 24, color: RescueColors.navy),
        iconButtonTheme: IconButtonThemeData(
            style: IconButton.styleFrom(minimumSize: const Size(48, 48))),
        listTileTheme: const ListTileThemeData(
            minTileHeight: 64,
            iconColor: RescueColors.navy,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4)),
        navigationBarTheme: NavigationBarThemeData(
            height: 72,
            elevation: 0,
            backgroundColor: RescueColors.surface,
            surfaceTintColor: Colors.transparent,
            indicatorColor: RescueColors.selected,
            labelTextStyle: WidgetStateProperty.resolveWith((states) =>
                RescueType.caption.copyWith(
                    color: states.contains(WidgetState.selected)
                        ? RescueColors.navy
                        : RescueColors.muted,
                    fontWeight: states.contains(WidgetState.selected)
                        ? FontWeight.w700
                        : FontWeight.w500)),
            iconTheme: const WidgetStatePropertyAll(
                IconThemeData(size: 24, color: RescueColors.navy))),
        chipTheme: ChipThemeData(
            backgroundColor: RescueColors.surface,
            selectedColor: RescueColors.selected,
            checkmarkColor: RescueColors.navy,
            labelStyle: RescueType.status.copyWith(color: RescueColors.navy),
            side: const BorderSide(color: RescueColors.border),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(RescueRadius.control))),
        segmentedButtonTheme: SegmentedButtonThemeData(
            style: ButtonStyle(minimumSize: const WidgetStatePropertyAll(Size(48, 48)), textStyle: const WidgetStatePropertyAll(RescueType.button), foregroundColor: const WidgetStatePropertyAll(RescueColors.navy), backgroundColor: WidgetStateProperty.resolveWith((states) => states.contains(WidgetState.selected) ? RescueColors.selected : RescueColors.surface))),
        inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: RescueColors.surface, contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16), border: outline, enabledBorder: outline, focusedBorder: outline.copyWith(borderSide: const BorderSide(color: RescueColors.navy, width: 1.5)), errorBorder: outline.copyWith(borderSide: const BorderSide(color: RescueColors.danger)), focusedErrorBorder: outline.copyWith(borderSide: const BorderSide(color: RescueColors.danger, width: 1.5)), labelStyle: RescueType.body.copyWith(color: RescueColors.muted), hintStyle: RescueType.body.copyWith(color: RescueColors.muted), errorMaxLines: 3, helperMaxLines: 3),
        dialogTheme: DialogThemeData(backgroundColor: RescueColors.surface, surfaceTintColor: Colors.transparent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(RescueRadius.card))),
        progressIndicatorTheme: const ProgressIndicatorThemeData(color: RescueColors.navy, linearTrackColor: RescueColors.selected),
        snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating, backgroundColor: RescueColors.navy, contentTextStyle: TextStyle(color: Colors.white)),
        dividerColor: RescueColors.border);
  }
}
