import 'package:flutter/material.dart';

import '../../core/theme/app_tokens.dart';

enum AppStateViewKind { loading, empty, error }

/// Shared loading, empty, and error presentation for list/detail surfaces.
class AppStateView extends StatelessWidget {
  const AppStateView.loading({required this.message, this.title, super.key})
    : kind = AppStateViewKind.loading,
      icon = Icons.hourglass_top_rounded,
      action = null;

  const AppStateView.empty({
    required this.message,
    this.title,
    this.icon = Icons.inbox_outlined,
    this.action,
    super.key,
  }) : kind = AppStateViewKind.empty;

  const AppStateView.error({
    required this.message,
    required this.action,
    this.title,
    this.icon = Icons.error_outline_rounded,
    super.key,
  }) : kind = AppStateViewKind.error;

  final AppStateViewKind kind;
  final String? title;
  final String message;
  final IconData icon;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = switch (kind) {
      AppStateViewKind.loading => theme.colorScheme.primary,
      AppStateViewKind.empty => theme.colorScheme.outline,
      AppStateViewKind.error => theme.colorScheme.error,
    };

    return Center(
      child: SingleChildScrollView(
        padding: AppSpacing.card,
        child: Semantics(
          liveRegion: kind != AppStateViewKind.empty,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (kind == AppStateViewKind.loading)
                  const SizedBox.square(
                    dimension: AppSizes.stateIcon,
                    child: CircularProgressIndicator(strokeWidth: 3),
                  )
                else
                  Icon(icon, size: AppSizes.stateIcon, color: color),
                const SizedBox(height: AppSpacing.md),
                if (title != null) ...[
                  Text(
                    title!,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppSpacing.xs),
                ],
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyLarge,
                ),
                if (action != null) ...[
                  const SizedBox(height: AppSpacing.md),
                  action!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
