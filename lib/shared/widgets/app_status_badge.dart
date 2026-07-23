import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';

enum AppStatusTone { neutral, brand, success, warning, error, info }

class AppStatusBadge extends StatelessWidget {
  const AppStatusBadge({
    required this.label,
    this.tone = AppStatusTone.neutral,
    this.icon,
    super.key,
  });

  final String label;
  final AppStatusTone tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantic = theme.semanticColors;
    final (foreground, background) = switch (tone) {
      AppStatusTone.neutral => (AppColors.neutral600, AppColors.neutral100),
      AppStatusTone.brand => (AppColors.goldDeep, AppColors.goldSoft),
      AppStatusTone.success => (semantic.success, semantic.successContainer),
      AppStatusTone.warning => (semantic.warning, semantic.warningContainer),
      AppStatusTone.error => (
        theme.colorScheme.error,
        theme.colorScheme.errorContainer,
      ),
      AppStatusTone.info => (semantic.info, semantic.infoContainer),
    };

    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 10,
            vertical: AppSpacing.xxs,
          ),
          decoration: BoxDecoration(
            color: background,
            borderRadius: AppRadii.pillRadius,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 14, color: foreground),
                const SizedBox(width: AppSpacing.xxs),
              ],
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: foreground,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
