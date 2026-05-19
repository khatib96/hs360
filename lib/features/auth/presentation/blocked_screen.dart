import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import 'auth_controller.dart';
import 'auth_error_messages.dart';

class BlockedScreen extends ConsumerWidget {
  const BlockedScreen({super.key});

  static const routePath = AppRoutes.blocked;
  static const routeName = AppRoutes.blockedName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return AppShell(
      title: l10n.blockedTitle,
      actions: [
        IconButton(
          tooltip: l10n.logout,
          icon: const Icon(LucideIcons.logOut),
          onPressed: () => _signOut(context, ref),
        ),
      ],
      body: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.blockedMessage, style: theme.textTheme.bodyLarge),
          ],
        ),
      ),
    );
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final l10n = AppLocalizations.of(context)!;
    await ref.read(authControllerProvider.notifier).signOut();
    if (!context.mounted) return;

    final authState = ref.read(authControllerProvider);
    if (authState.hasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authErrorMessage(l10n, authErrorCode(authState.error))),
        ),
      );
      return;
    }
    context.go(AppRoutes.login);
  }
}
