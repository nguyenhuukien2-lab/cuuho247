import 'package:flutter/material.dart';

abstract final class AppColors {
  static const background = Color(0xFFF7F9FC);
  static const surface = Color(0xFFFFFFFF);
  static const navy = Color(0xFF123B66);
  static const selected = Color(0xFFE6EFF8);
  static const orange = Color(0xFFE85D04);
  static const orangePressed = Color(0xFFC94D0A);
  static const orangeSoft = Color(0xFFFFF0E6);
  static const text = Color(0xFF17202A);
  static const muted = Color(0xFF667085);
  static const border = Color(0xFFDCE3EA);
  static const success = Color(0xFF16835D);
  static const warning = Color(0xFFB76E00);
  static const error = Color(0xFFC62828);
  static const info = Color(0xFF175CD3);
  static const progress = Color(0xFF3646A0);
}

abstract final class AppSpacing {
  static const xs = 4.0, sm = 8.0, md = 12.0, lg = 16.0;
  static const xl = 24.0, xxl = 32.0;
  static const page = EdgeInsets.fromLTRB(lg, lg, lg, xxl);
}

abstract final class AppRadius {
  static const small = 8.0, card = 12.0, featured = 12.0;
}

abstract final class AppTheme {
  static ThemeData get light {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.navy,
      brightness: Brightness.light,
      primary: AppColors.navy,
      primaryContainer: AppColors.selected,
      onPrimaryContainer: AppColors.navy,
      secondary: AppColors.orange,
      surface: AppColors.surface,
      onSurface: AppColors.text,
      onSurfaceVariant: AppColors.muted,
      onSecondary: AppColors.text,
      outline: AppColors.border,
      error: AppColors.error,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: 'Roboto',
      iconTheme: const IconThemeData(size: 24),
      iconButtonTheme: IconButtonThemeData(
          style: IconButton.styleFrom(minimumSize: const Size(48, 48))),
      listTileTheme: const ListTileThemeData(
          minTileHeight: 64,
          iconColor: AppColors.navy,
          contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 4)),
      segmentedButtonTheme: SegmentedButtonThemeData(
          style: ButtonStyle(
        minimumSize: const WidgetStatePropertyAll(Size(48, 48)),
        backgroundColor: WidgetStateProperty.resolveWith((states) =>
            states.contains(WidgetState.selected)
                ? AppColors.selected
                : AppColors.surface),
        foregroundColor: const WidgetStatePropertyAll(AppColors.navy),
        textStyle: const WidgetStatePropertyAll(TextStyle(
            fontSize: 14,
            fontFamily: 'Roboto',
            fontWeight: FontWeight.w600,
            letterSpacing: 0)),
      )),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.text,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleTextStyle: TextStyle(
            fontFamily: 'Roboto',
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.text,
            letterSpacing: 0),
      ),
      filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card)),
      )),
      outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 48),
        foregroundColor: AppColors.navy,
        side: const BorderSide(color: AppColors.border),
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card)),
      )),
      textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(minimumSize: const Size(48, 48))),
      navigationBarTheme: NavigationBarThemeData(
        height: 72,
        elevation: 0,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        indicatorColor: AppColors.selected,
        labelTextStyle: WidgetStateProperty.resolveWith((states) => TextStyle(
              fontFamily: 'Roboto',
              fontSize: 11,
              letterSpacing: 0,
              fontWeight: states.contains(WidgetState.selected)
                  ? FontWeight.w700
                  : FontWeight.w500,
              color: states.contains(WidgetState.selected)
                  ? AppColors.navy
                  : AppColors.muted,
            )),
        iconTheme: WidgetStateProperty.resolveWith((states) => IconThemeData(
              size: 24,
              color: states.contains(WidgetState.selected)
                  ? AppColors.navy
                  : AppColors.muted,
            )),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.featured)),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
          color: AppColors.navy, linearTrackColor: AppColors.selected),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
            fontSize: 28,
            letterSpacing: 0,
            height: 1.2,
            fontWeight: FontWeight.w700,
            color: AppColors.text),
        titleLarge: TextStyle(
            fontSize: 20,
            letterSpacing: 0,
            height: 1.25,
            fontWeight: FontWeight.w700,
            color: AppColors.text),
        titleMedium: TextStyle(
            fontSize: 16,
            letterSpacing: 0,
            height: 1.3,
            fontWeight: FontWeight.w600,
            color: AppColors.text),
        bodyLarge: TextStyle(
            fontSize: 16,
            height: 1.45,
            letterSpacing: 0,
            color: AppColors.text),
        bodyMedium: TextStyle(
            fontSize: 14, height: 1.4, letterSpacing: 0, color: AppColors.text),
        bodySmall: TextStyle(
            fontSize: 13,
            height: 1.35,
            letterSpacing: 0,
            color: AppColors.muted),
        labelLarge: TextStyle(
            fontSize: 15, fontWeight: FontWeight.w700, letterSpacing: 0),
        labelMedium: TextStyle(fontSize: 13, letterSpacing: 0),
        labelSmall: TextStyle(fontSize: 12, letterSpacing: 0),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            side: const BorderSide(color: AppColors.border)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            borderSide: const BorderSide(color: AppColors.border)),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            borderSide: const BorderSide(color: AppColors.border)),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            borderSide: const BorderSide(color: AppColors.navy, width: 1.5)),
        errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            borderSide: const BorderSide(color: AppColors.error)),
        focusedErrorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.card),
            borderSide: const BorderSide(color: AppColors.error, width: 1.5)),
        labelStyle: const TextStyle(color: AppColors.muted),
        hintStyle: const TextStyle(color: AppColors.muted),
        errorMaxLines: 3,
        helperMaxLines: 3,
      ),
      snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppColors.navy,
          contentTextStyle: TextStyle(color: Colors.white)),
      dividerColor: AppColors.border,
    );
  }
}
