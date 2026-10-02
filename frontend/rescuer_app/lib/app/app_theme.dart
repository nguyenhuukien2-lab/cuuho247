import 'package:flutter/material.dart';

abstract final class AppColors {
  static const navy = Color(0xFF142A42);
  static const navySoft = Color(0xFF213D5B);
  static const orange = Color(0xFFED7A22);
  static const orangeSoft = Color(0xFFFFF1E6);
  static const background = Color(0xFFF5F7FA);
  static const surface = Colors.white;
  static const ink = Color(0xFF17283C);
  static const muted = Color(0xFF738197);
  static const line = Color(0xFFE5EAF0);
  static const success = Color(0xFF17865B);
  static const successSoft = Color(0xFFE9F7F0);
  static const warning = Color(0xFF9B6418);
  static const warningSoft = Color(0xFFFFF5E5);
  static const danger = Color(0xFFC4463D);
  static const dangerSoft = Color(0xFFFFEFED);
  static const blue = Color(0xFF376C9C);
  static const blueSoft = Color(0xFFEDF4FA);
}

abstract final class AppSpace {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const section = 28.0;
}

abstract final class AppRadii {
  static const sm = 10.0;
  static const md = 16.0;
  static const lg = 22.0;
  static const pill = 100.0;
}

abstract final class AppType {
  static const pageTitle = TextStyle(
    fontSize: 26,
    height: 1.18,
    fontWeight: FontWeight.w800,
    letterSpacing: -0.5,
    color: AppColors.ink,
  );
  static const section = TextStyle(
    fontSize: 17,
    height: 1.3,
    fontWeight: FontWeight.w700,
    color: AppColors.ink,
  );
  static const body = TextStyle(
    fontSize: 14,
    height: 1.5,
    color: AppColors.ink,
  );
  static const caption = TextStyle(
    fontSize: 12,
    height: 1.45,
    color: AppColors.muted,
  );
}

abstract final class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      primary: AppColors.navy,
      secondary: AppColors.orange,
      surface: AppColors.surface,
      error: AppColors.danger,
      brightness: Brightness.light,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontSize: 19,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        hintStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
        labelStyle: const TextStyle(color: AppColors.muted, fontSize: 14),
        prefixIconColor: AppColors.muted,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.navy, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.md),
        ),
      ),
      dividerColor: AppColors.line,
    );
  }
}
