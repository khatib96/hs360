import 'package:flutter/material.dart';

/// Phase 7.5 spacing scale. Feature layouts may choose a token, but should not
/// invent near-duplicate values for the same visual relationship.
abstract final class AppSpacing {
  static const double xxs = 4;
  static const double xs = 8;
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;

  static const EdgeInsetsGeometry page = EdgeInsetsDirectional.all(md);
  static const EdgeInsetsGeometry pageWide = EdgeInsetsDirectional.all(lg);
  static const EdgeInsetsGeometry card = EdgeInsetsDirectional.all(lg);
  static const EdgeInsetsGeometry cardCompact = EdgeInsetsDirectional.all(md);
  static const EdgeInsetsGeometry tableCell = EdgeInsetsDirectional.symmetric(
    horizontal: 10,
    vertical: 6,
  );
}

abstract final class AppRadii {
  static const double control = 8;
  static const double surface = 12;
  static const double dialog = 16;
  static const double pill = 999;

  static const BorderRadius controlRadius = BorderRadius.all(
    Radius.circular(control),
  );
  static const BorderRadius surfaceRadius = BorderRadius.all(
    Radius.circular(surface),
  );
  static const BorderRadius dialogRadius = BorderRadius.all(
    Radius.circular(dialog),
  );
  static const BorderRadius pillRadius = BorderRadius.all(
    Radius.circular(pill),
  );
}

abstract final class AppSizes {
  static const double controlHeight = 44;
  static const double compactRowHeight = 40;
  static const double icon = 20;
  static const double stateIcon = 44;
  static const double contentMaxWidth = 1280;
}

/// Semantic colors that Material's ColorScheme does not name directly.
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.brandAccent,
    required this.onBrandAccent,
    required this.success,
    required this.successContainer,
    required this.warning,
    required this.warningContainer,
    required this.info,
    required this.infoContainer,
  });

  final Color brandAccent;
  final Color onBrandAccent;
  final Color success;
  final Color successContainer;
  final Color warning;
  final Color warningContainer;
  final Color info;
  final Color infoContainer;

  @override
  AppSemanticColors copyWith({
    Color? brandAccent,
    Color? onBrandAccent,
    Color? success,
    Color? successContainer,
    Color? warning,
    Color? warningContainer,
    Color? info,
    Color? infoContainer,
  }) {
    return AppSemanticColors(
      brandAccent: brandAccent ?? this.brandAccent,
      onBrandAccent: onBrandAccent ?? this.onBrandAccent,
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      info: info ?? this.info,
      infoContainer: infoContainer ?? this.infoContainer,
    );
  }

  @override
  AppSemanticColors lerp(
    covariant ThemeExtension<AppSemanticColors>? other,
    double t,
  ) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      brandAccent: Color.lerp(brandAccent, other.brandAccent, t)!,
      onBrandAccent: Color.lerp(onBrandAccent, other.onBrandAccent, t)!,
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      info: Color.lerp(info, other.info, t)!,
      infoContainer: Color.lerp(infoContainer, other.infoContainer, t)!,
    );
  }
}

extension AppThemeTokens on ThemeData {
  AppSemanticColors get semanticColors =>
      extension<AppSemanticColors>() ??
      const AppSemanticColors(
        brandAccent: Color(0xFFC9A961),
        onBrandAccent: Color(0xFF1A1A1A),
        success: Color(0xFF276B45),
        successContainer: Color(0xFFDDEDE4),
        warning: Color(0xFF875307),
        warningContainer: Color(0xFFFFEBC8),
        info: Color(0xFF32627F),
        infoContainer: Color(0xFFDCEAF2),
      );
}
