import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../core/routing/app_navigation.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../features/auth/domain/app_session.dart';

class AppContextualNavigation extends StatelessWidget {
  const AppContextualNavigation({
    required this.module,
    required this.activeDestination,
    required this.session,
    super.key,
  });

  final AppNavigationModule module;
  final AppNavigationDestination? activeDestination;
  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final destinations = module.visibleDestinations(session);
    if (destinations.length < 2) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    return Semantics(
      container: true,
      label: l10n.shellContextNavigation,
      child: Container(
        key: const Key('shell-contextual-navigation'),
        height: 52,
        decoration: const BoxDecoration(
          color: AppColors.pureWhite,
          border: Border(bottom: BorderSide(color: AppColors.neutral100)),
        ),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: AppSpacing.md,
            vertical: 8,
          ),
          child: Row(
            children: [
              for (final destination in destinations) ...[
                _DestinationChip(
                  destination: destination,
                  active: destination.id == activeDestination?.id,
                ),
                if (destination != destinations.last)
                  const SizedBox(width: AppSpacing.xs),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DestinationChip extends StatelessWidget {
  const _DestinationChip({required this.destination, required this.active});

  final AppNavigationDestination destination;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final label = destination.label(AppLocalizations.of(context)!);
    return Material(
      color: active ? AppColors.goldSoft : AppColors.neutral50,
      shape: const StadiumBorder(),
      child: InkWell(
        key: Key('shell-context-${destination.id}'),
        customBorder: const StadiumBorder(),
        onTap: () => context.go(destination.route),
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 14,
            vertical: 8,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                destination.icon,
                size: 18,
                color: active ? AppColors.charcoal : AppColors.neutral600,
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: active ? AppColors.charcoal : AppColors.neutral600,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
