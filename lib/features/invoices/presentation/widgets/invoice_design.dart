import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';

/// Shared visual constants for the invoice (Odoo-structured) UI.
///
/// Kept local to the invoices feature for now; promotable to a shared finance
/// design module once vouchers/journal adopt the same accounting-sheet look.
abstract final class InvoiceDesign {
  /// Desktop breakpoint used across list/form/detail.
  static const double desktopBreakpoint = 768;

  /// Width above which the form/detail switch to a multi-column document grid.
  static const double wideDocumentBreakpoint = 1080;

  /// Max width of the centered document sheet (form/detail only).
  static const double sheetMaxWidth = 1180;

  /// Outer page padding (denser than the old 24).
  static const EdgeInsetsGeometry pagePadding = EdgeInsetsDirectional.all(16);

  /// Inner padding for sheet sections.
  static const EdgeInsetsGeometry sectionPadding = EdgeInsetsDirectional.all(16);

  /// Dense padding for table cells / compact rows.
  static const EdgeInsetsGeometry cellPadding = EdgeInsetsDirectional.symmetric(
    horizontal: 10,
    vertical: 6,
  );

  static const double gap = 12;
  static const double gapSmall = 8;
  static const double gapLarge = 20;

  static const Color borderColor = AppColors.neutral200;
  static const Color headerFill = AppColors.neutral50;
  static const Color sheetFill = AppColors.pureWhite;
  static const Color pageFill = AppColors.offWhite;

  static const BorderRadius radius = BorderRadius.all(Radius.circular(10));
  static const BorderRadius radiusSmall = BorderRadius.all(Radius.circular(6));

  static BorderSide get hairline =>
      const BorderSide(color: borderColor, width: 1);

  static Border get box => Border.fromBorderSide(hairline);

  static BoxDecoration get panel => BoxDecoration(
    color: sheetFill,
    border: box,
    borderRadius: radius,
  );

  static BoxDecoration get headerStrip => BoxDecoration(
    color: headerFill,
    border: box,
    borderRadius: radius,
  );

  static bool isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width > desktopBreakpoint;

  static bool isWideDocument(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= wideDocumentBreakpoint;

  /// Compact input decoration for in-sheet fields and table cells.
  static InputDecoration denseField(
    BuildContext context, {
    String? label,
    String? hint,
    Widget? prefixIcon,
    Widget? suffixIcon,
    bool filled = true,
  }) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      isDense: true,
      filled: filled,
      fillColor: AppColors.pureWhite,
      contentPadding: const EdgeInsetsDirectional.symmetric(
        horizontal: 10,
        vertical: 10,
      ),
      border: const OutlineInputBorder(
        borderRadius: radiusSmall,
        borderSide: BorderSide(color: borderColor),
      ),
      enabledBorder: const OutlineInputBorder(
        borderRadius: radiusSmall,
        borderSide: BorderSide(color: borderColor),
      ),
    );
  }

  /// Bare cell editor decoration used inside the lines grid (no heavy border).
  static InputDecoration cellField(BuildContext context, {String? hint}) {
    return InputDecoration(
      hintText: hint,
      isDense: true,
      filled: false,
      contentPadding: const EdgeInsetsDirectional.symmetric(
        horizontal: 8,
        vertical: 8,
      ),
      border: InputBorder.none,
      enabledBorder: InputBorder.none,
      focusedBorder: const UnderlineInputBorder(
        borderSide: BorderSide(color: AppColors.gold, width: 1.5),
      ),
    );
  }

  static TextStyle? columnHeaderStyle(BuildContext context) {
    return Theme.of(context).textTheme.labelMedium?.copyWith(
      color: AppColors.neutral600,
      fontWeight: FontWeight.w600,
    );
  }

  static TextStyle? fieldLabelStyle(BuildContext context) {
    return Theme.of(context).textTheme.labelSmall?.copyWith(
      color: AppColors.neutral600,
      fontWeight: FontWeight.w600,
    );
  }
}
