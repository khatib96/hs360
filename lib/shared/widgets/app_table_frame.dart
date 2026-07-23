import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';

/// Visual frame only. Columns, sorting, pagination, and row actions stay owned
/// by the feature.
class AppTableFrame extends StatelessWidget {
  const AppTableFrame({
    required this.child,
    this.header,
    this.footer,
    super.key,
  });

  final Widget child;
  final Widget? header;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.pureWhite,
        border: Border.all(color: AppColors.neutral100),
        borderRadius: AppRadii.surfaceRadius,
      ),
      child: ClipRRect(
        borderRadius: AppRadii.surfaceRadius,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (header != null)
              ColoredBox(
                color: AppColors.neutral50,
                child: Padding(
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: header!,
                ),
              ),
            Expanded(child: child),
            if (footer != null) ...[
              const Divider(height: 1),
              Padding(padding: AppSpacing.cardCompact, child: footer!),
            ],
          ],
        ),
      ),
    );
  }
}
