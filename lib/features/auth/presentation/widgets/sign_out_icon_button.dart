import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';
import 'package:flutter_lucide/flutter_lucide.dart';

import '../../../../core/routing/app_routes.dart';
import '../auth_controller.dart';
import '../auth_error_messages.dart';

class SignOutIconButton extends ConsumerWidget {
  const SignOutIconButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return IconButton(
      tooltip: l10n.logout,
      icon: const Icon(LucideIcons.log_out),
      onPressed: () => _signOut(context, ref),
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
