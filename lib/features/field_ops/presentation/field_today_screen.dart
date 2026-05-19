import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../auth/presentation/widgets/authenticated_user_summary.dart';
import '../../auth/presentation/widgets/sign_out_icon_button.dart';

class FieldTodayScreen extends ConsumerWidget {
  const FieldTodayScreen({super.key});

  static const routePath = AppRoutes.fieldToday;
  static const routeName = AppRoutes.fieldTodayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AppShell(
      title: l10n.fieldTodayTitle,
      actions: const [SignOutIconButton()],
      body: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const AuthenticatedUserSummary(),
                const SizedBox(height: 16),
                Text(
                  l10n.fieldTodayPlaceholder,
                  style: theme.textTheme.bodyLarge,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
