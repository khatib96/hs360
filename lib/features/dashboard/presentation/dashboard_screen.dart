import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../auth/presentation/widgets/authenticated_user_summary.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const routePath = AppRoutes.dashboard;
  static const routeName = AppRoutes.dashboardName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AppShell(
      title: l10n.dashboard,
      currentRoute: AppRoutes.dashboard,
      body: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppBrandMark(title: l10n.appTitle),
            const SizedBox(height: 24),
            Text(l10n.appTitle, style: theme.textTheme.displaySmall),
            const SizedBox(height: 8),
            Text(
              l10n.dashboardPhase2Subtitle,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 24),
            const AuthenticatedUserSummary(),
          ],
        ),
      ),
    );
  }
}
