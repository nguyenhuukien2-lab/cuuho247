import 'package:flutter/material.dart';

import 'mobile_ui.dart';

abstract final class AppColors {
  static const navy = RescueColors.navy, navySoft = RescueColors.navySoft;
  static const orange = RescueColors.accent,
      orangeSoft = RescueColors.accentSoft;
  static const background = RescueColors.background,
      surface = RescueColors.surface;
  static const ink = RescueColors.ink,
      muted = RescueColors.muted,
      line = RescueColors.border;
  static const success = RescueColors.success,
      successSoft = RescueColors.successSoft;
  static const warning = RescueColors.warning,
      warningSoft = RescueColors.warningSoft;
  static const danger = RescueColors.danger,
      dangerSoft = RescueColors.dangerSoft;
  static const blue = RescueColors.info, blueSoft = RescueColors.infoSoft;
}

abstract final class AppSpace {
  static const xs = RescueSpace.xs,
      sm = RescueSpace.sm,
      md = RescueSpace.md,
      lg = RescueSpace.lg;
  static const xl = RescueSpace.lg,
      xxl = RescueSpace.xl,
      section = RescueSpace.xxl;
}

abstract final class AppRadii {
  static const sm = RescueRadius.small,
      md = RescueRadius.control,
      lg = RescueRadius.card;
  static const pill = RescueRadius.pill;
}

abstract final class AppType {
  static const pageTitle = RescueType.page, section = RescueType.section;
  static const body = RescueType.body, caption = RescueType.caption;
  static const code = RescueType.code, status = RescueType.status;
}

abstract final class AppTheme {
  static ThemeData get light => RescueTheme.light;
}
