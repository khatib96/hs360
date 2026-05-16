import 'package:flutter/material.dart';

/// Brand colors from docs/DESIGN_SYSTEM.md
abstract final class AppColors {
  static const Color gold = Color(0xFFC9A961);
  static const Color goldSoft = Color(0xFFE8D9B0);
  static const Color goldDeep = Color(0xFF9C8240);
  static const Color charcoal = Color(0xFF1A1A1A);
  static const Color ink = Color(0xFF2C2C2C);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color offWhite = Color(0xFFFAF8F3);
  static const Color success = Color(0xFF2D7A4F);
  static const Color warning = Color(0xFFC8861A);
  static const Color error = Color(0xFFA8362F);
  static const Color info = Color(0xFF3A6F8F);
  static const Color neutral50 = Color(0xFFF7F5F0);
  static const Color neutral100 = Color(0xFFEEEBE2);
  static const Color neutral200 = Color(0xFFD9D4C5);
  static const Color neutral400 = Color(0xFFA8A293);
  static const Color neutral600 = Color(0xFF5E5A4F);
}

abstract final class AppTheme {
  static ThemeData light() {
    final colorScheme = ColorScheme.light(
      primary: AppColors.gold,
      onPrimary: AppColors.charcoal,
      primaryContainer: AppColors.goldSoft,
      onPrimaryContainer: AppColors.charcoal,
      secondary: AppColors.goldDeep,
      onSecondary: AppColors.pureWhite,
      surface: AppColors.pureWhite,
      onSurface: AppColors.ink,
      error: AppColors.error,
      onError: AppColors.pureWhite,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.pureWhite,
      cardColor: AppColors.offWhite,
      dividerColor: AppColors.neutral200,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.pureWhite,
        foregroundColor: AppColors.charcoal,
        elevation: 0,
        centerTitle: false,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.gold,
        foregroundColor: AppColors.charcoal,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.gold,
          foregroundColor: AppColors.charcoal,
          disabledBackgroundColor: AppColors.neutral100,
          disabledForegroundColor: AppColors.neutral400,
        ),
      ),
      textTheme: _textTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.offWhite,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.neutral200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.neutral200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.gold, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }

  static const TextTheme _textTheme = TextTheme(
    displaySmall: TextStyle(
      fontSize: 32,
      fontWeight: FontWeight.w600,
      color: AppColors.charcoal,
      height: 1.2,
    ),
    headlineMedium: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: AppColors.charcoal,
      height: 1.3,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
      height: 1.35,
    ),
    bodyLarge: TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: AppColors.ink,
      height: 1.5,
    ),
    bodyMedium: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: AppColors.neutral600,
      height: 1.5,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.charcoal,
    ),
  );
}
