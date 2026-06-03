import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/chart_account_policy.dart';

class ChartAccountBadges extends StatelessWidget {
  const ChartAccountBadges({required this.badges, super.key});

  final List<ChartAccountBadgeKind> badges;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (badges.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: badges.map((badge) {
        final label = switch (badge) {
          ChartAccountBadgeKind.system => l10n.chartAccountBadgeSystem,
          ChartAccountBadgeKind.manual => l10n.chartAccountBadgeManual,
          ChartAccountBadgeKind.customer => l10n.chartAccountBadgeCustomer,
          ChartAccountBadgeKind.supplier => l10n.chartAccountBadgeSupplier,
          ChartAccountBadgeKind.inactive => l10n.chartAccountBadgeInactive,
        };
        final color = switch (badge) {
          ChartAccountBadgeKind.system => AppColors.info,
          ChartAccountBadgeKind.manual => AppColors.neutral600,
          ChartAccountBadgeKind.customer => AppColors.goldDeep,
          ChartAccountBadgeKind.supplier => AppColors.warning,
          ChartAccountBadgeKind.inactive => AppColors.error,
        };
        return Container(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 6,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                ),
          ),
        );
      }).toList(),
    );
  }
}
