import 'package:flutter/material.dart';
import 'mobile_ui.dart';

// Compatibility names for existing widgets; all values come from the UI foundation.
abstract final class AppColors {
  static const background = RescueColors.background,
      surface = RescueColors.surface;
  static const navy = RescueColors.navy, selected = RescueColors.selected;
  static const orange = RescueColors.accent,
      orangePressed = RescueColors.accentPressed;
  static const orangeSoft = RescueColors.accentSoft;
  static const text = RescueColors.ink,
      muted = RescueColors.muted,
      border = RescueColors.border;
  static const success = RescueColors.success, warning = RescueColors.warning;
  static const error = RescueColors.danger,
      info = RescueColors.info,
      progress = RescueColors.progress;
}

abstract final class AppSpacing {
  static const xs = RescueSpace.xs,
      sm = RescueSpace.sm,
      md = RescueSpace.md,
      lg = RescueSpace.lg;
  static const xl = RescueSpace.xl, xxl = RescueSpace.xxl;
  static const page = RescueSpace.page;
}

abstract final class AppRadius {
  static const small = RescueRadius.small,
      card = RescueRadius.card,
      featured = RescueRadius.card;
}

abstract final class AppTheme {
  static ThemeData get light => RescueTheme.light;
}
