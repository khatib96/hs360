import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';

/// Standard placement for feature-owned, permission-filtered module commands.
class AppModuleCommandBar extends StatelessWidget {
  const AppModuleCommandBar({required this.actions, super.key});

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      container: true,
      label: l10n.shellModuleActions,
      child: Container(
        key: const Key('shell-module-command-bar'),
        constraints: const BoxConstraints(minHeight: 52),
        decoration: const BoxDecoration(
          color: AppColors.offWhite,
          border: Border(bottom: BorderSide(color: AppColors.neutral100)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xs,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var index = 0; index < actions.length; index++) ...[
                actions[index],
                if (index != actions.length - 1)
                  const SizedBox(width: AppSpacing.xs),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
