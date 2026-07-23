import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// Brand colors from docs/DESIGN_SYSTEM.md
abstract final class AppColors {
  static const Color brandGold = Color(0xFFC9A961);
  static const Color actionGold = Color(0xFFA86010);
  static const Color actionGoldHover = Color(0xFF874A0C);

  /// Compatibility alias. New code should choose [brandGold] or [actionGold].
  static const Color gold = actionGold;
  static const Color goldSoft = Color(0xFFE8D9B0);
  static const Color goldDeep = Color(0xFF9C8240);
  static const Color charcoal = Color(0xFF1A1A1A);
  static const Color ink = Color(0xFF2C2C2C);
  static const Color pureWhite = Color(0xFFFFFFFF);
  static const Color warmCanvas = Color(0xFFF5F1E8);
  static const Color offWhite = Color(0xFFFAF8F3);
  static const Color success = Color(0xFF276B45);
  static const Color successContainer = Color(0xFFDDEDE4);
  static const Color warning = Color(0xFF875307);
  static const Color warningContainer = Color(0xFFFFEBC8);
  static const Color error = Color(0xFFA8362F);
  static const Color errorContainer = Color(0xFFF7E2DF);
  static const Color info = Color(0xFF32627F);
  static const Color infoContainer = Color(0xFFDCEAF2);
  static const Color neutral50 = Color(0xFFF7F5F0);
  static const Color neutral100 = Color(0xFFEEEBE2);
  static const Color neutral200 = Color(0xFFD9D4C5);
  static const Color neutral400 = Color(0xFFA8A293);
  static const Color neutral600 = Color(0xFF5E5A4F);
  static const Color neutral800 = Color(0xFF2C2C2C);
}

abstract final class AppTheme {
  static ThemeData light({Locale locale = const Locale('en')}) {
    final isArabic = locale.languageCode == 'ar';
    final fontFamily = isArabic ? 'NotoSansArabic' : 'NotoSans';
    final fontFallback = isArabic
        ? const ['NotoSans']
        : const ['NotoSansArabic'];

    final colorScheme = ColorScheme.light(
      primary: AppColors.actionGold,
      onPrimary: AppColors.pureWhite,
      primaryContainer: AppColors.goldSoft,
      onPrimaryContainer: AppColors.charcoal,
      secondary: AppColors.goldDeep,
      onSecondary: AppColors.pureWhite,
      surface: AppColors.pureWhite,
      onSurface: AppColors.ink,
      surfaceContainerLowest: AppColors.pureWhite,
      surfaceContainerLow: AppColors.offWhite,
      surfaceContainer: AppColors.neutral50,
      surfaceContainerHigh: AppColors.neutral100,
      onSurfaceVariant: AppColors.neutral600,
      outline: AppColors.neutral200,
      outlineVariant: AppColors.neutral100,
      error: AppColors.error,
      onError: AppColors.pureWhite,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.error,
    );

    final textTheme = _textTheme.apply(
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      fontFamily: fontFamily,
      fontFamilyFallback: fontFallback,
      scaffoldBackgroundColor: AppColors.warmCanvas,
      cardColor: AppColors.pureWhite,
      dividerColor: AppColors.neutral200,
      disabledColor: AppColors.neutral400,
      extensions: const [
        AppSemanticColors(
          brandAccent: AppColors.brandGold,
          onBrandAccent: AppColors.charcoal,
          success: AppColors.success,
          successContainer: AppColors.successContainer,
          warning: AppColors.warning,
          warningContainer: AppColors.warningContainer,
          info: AppColors.info,
          infoContainer: AppColors.infoContainer,
        ),
      ],
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.pureWhite,
        foregroundColor: AppColors.charcoal,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: textTheme.titleLarge,
        surfaceTintColor: Colors.transparent,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.actionGold,
        foregroundColor: AppColors.pureWhite,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.controlRadius),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(
            Size(0, AppSizes.controlHeight),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsetsDirectional.symmetric(horizontal: AppSpacing.md),
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: AppRadii.controlRadius),
          ),
          foregroundColor: const WidgetStatePropertyAll(AppColors.pureWhite),
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.neutral100;
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed)) {
              return AppColors.actionGoldHover;
            }
            return AppColors.actionGold;
          }),
          iconColor: WidgetStateProperty.resolveWith((states) {
            return states.contains(WidgetState.disabled)
                ? AppColors.neutral400
                : AppColors.pureWhite;
          }),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(0, AppSizes.controlHeight),
          backgroundColor: AppColors.actionGold,
          foregroundColor: AppColors.pureWhite,
          disabledBackgroundColor: AppColors.neutral100,
          disabledForegroundColor: AppColors.neutral400,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.controlRadius,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(0, AppSizes.controlHeight),
          foregroundColor: AppColors.actionGold,
          side: const BorderSide(color: AppColors.actionGold),
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.controlRadius,
          ),
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          minimumSize: const Size(0, AppSizes.controlHeight),
          foregroundColor: AppColors.actionGold,
          shape: const RoundedRectangleBorder(
            borderRadius: AppRadii.controlRadius,
          ),
        ),
      ),
      cardTheme: const CardThemeData(
        color: AppColors.pureWhite,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.surfaceRadius,
          side: BorderSide(color: AppColors.neutral100),
        ),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: AppColors.pureWhite,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: AppRadii.dialogRadius),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.neutral50,
        selectedColor: AppColors.goldSoft,
        disabledColor: AppColors.neutral100,
        side: const BorderSide(color: AppColors.neutral200),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.pillRadius),
        labelStyle: textTheme.labelMedium,
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: AppSpacing.xs,
        ),
      ),
      dataTableTheme: DataTableThemeData(
        headingRowColor: const WidgetStatePropertyAll(AppColors.neutral50),
        headingTextStyle: textTheme.labelMedium?.copyWith(
          color: AppColors.neutral600,
          fontWeight: FontWeight.w700,
        ),
        dataTextStyle: textTheme.bodyMedium?.copyWith(color: AppColors.ink),
        dividerThickness: 1,
        dataRowMinHeight: AppSizes.compactRowHeight,
        headingRowHeight: AppSizes.compactRowHeight,
      ),
      focusColor: AppColors.actionGold.withValues(alpha: 0.14),
      hoverColor: AppColors.neutral50,
      splashColor: AppColors.actionGold.withValues(alpha: 0.10),
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: AppColors.actionGold,
        selectionColor: AppColors.goldSoft,
        selectionHandleColor: AppColors.actionGold,
      ),
      textTheme: textTheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.pureWhite,
        isDense: true,
        // Extra vertical padding keeps floating labels fully visible.
        contentPadding: const EdgeInsetsDirectional.fromSTEB(12, 16, 12, 12),
        floatingLabelBehavior: FloatingLabelBehavior.auto,
        border: const OutlineInputBorder(
          borderRadius: AppRadii.controlRadius,
          borderSide: BorderSide(color: AppColors.neutral200),
        ),
        enabledBorder: const OutlineInputBorder(
          borderRadius: AppRadii.controlRadius,
          borderSide: BorderSide(color: AppColors.neutral200),
        ),
        focusedBorder: const OutlineInputBorder(
          borderRadius: AppRadii.controlRadius,
          borderSide: BorderSide(color: AppColors.actionGold, width: 2),
        ),
        errorBorder: const OutlineInputBorder(
          borderRadius: AppRadii.controlRadius,
          borderSide: BorderSide(color: AppColors.error),
        ),
        focusedErrorBorder: const OutlineInputBorder(
          borderRadius: AppRadii.controlRadius,
          borderSide: BorderSide(color: AppColors.error, width: 2),
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
    headlineSmall: TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      color: AppColors.charcoal,
      height: 1.35,
    ),
    titleLarge: TextStyle(
      fontSize: 20,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
      height: 1.35,
    ),
    titleMedium: TextStyle(
      fontSize: 17,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
      height: 1.4,
    ),
    titleSmall: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
      height: 1.45,
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
    bodySmall: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: AppColors.neutral600,
      height: 1.5,
    ),
    labelLarge: TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.charcoal,
    ),
    labelMedium: TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: AppColors.ink,
      height: 1.4,
    ),
    labelSmall: TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: AppColors.neutral600,
      height: 1.45,
    ),
  );
}
