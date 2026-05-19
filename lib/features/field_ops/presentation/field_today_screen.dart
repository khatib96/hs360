import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';
import 'package:lucide_icons/lucide_icons.dart';

import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../auth/presentation/auth_error_messages.dart';

class FieldTodayScreen extends ConsumerWidget {
  const FieldTodayScreen({super.key});

  static const routePath = AppRoutes.fieldToday;
  static const routeName = AppRoutes.fieldTodayName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return AppShell(
      title: l10n.fieldTodayTitle,
      actions: [
        IconButton(
          tooltip: l10n.logout,
          icon: const Icon(LucideIcons.logOut),
          onPressed: () => _signOut(context, ref),
        ),
      ],
      body: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Text(
          l10n.fieldTodayPlaceholder,
          style: Theme.of(context).textTheme.bodyLarge,
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
