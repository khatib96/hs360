import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../core/routing/app_routes.dart';
import '../../core/theme/app_theme.dart';
import '../../core/theme/app_tokens.dart';
import '../../features/auth/domain/app_session.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/auth/presentation/auth_error_messages.dart';

class AppUserCard extends ConsumerWidget {
  const AppUserCard({required this.session, this.collapsed = false, super.key});

  final AppSession session;
  final bool collapsed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    if (collapsed) {
      return PopupMenuButton<_UserAction>(
        key: const Key('shell-user-card'),
        tooltip: session.displayName,
        position: PopupMenuPosition.over,
        onSelected: (action) {
          if (action == _UserAction.signOut) {
            _signOut(context, ref, l10n);
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(enabled: false, child: _Identity(session: session)),
          const PopupMenuDivider(),
          PopupMenuItem(
            value: _UserAction.signOut,
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.logout),
              title: Text(l10n.logout),
            ),
          ),
        ],
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
          child: _Avatar(name: session.displayName),
        ),
      );
    }

    return Container(
      key: const Key('shell-user-card'),
      margin: const EdgeInsetsDirectional.all(AppSpacing.xs),
      padding: const EdgeInsetsDirectional.all(AppSpacing.xs),
      decoration: BoxDecoration(
        color: AppColors.pureWhite.withValues(alpha: 0.76),
        borderRadius: AppRadii.surfaceRadius,
        border: Border.all(color: AppColors.neutral100),
      ),
      child: Row(
        children: [
          _Avatar(name: session.displayName),
          const SizedBox(width: AppSpacing.xs),
          Expanded(child: _Identity(session: session)),
          IconButton(
            key: const Key('shell-sign-out'),
            tooltip: l10n.logout,
            onPressed: () => _signOut(context, ref, l10n),
            icon: const Icon(Icons.logout, size: AppSizes.icon),
          ),
        ],
      ),
    );
  }

  Future<void> _signOut(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
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

enum _UserAction { signOut }

class _Avatar extends StatelessWidget {
  const _Avatar({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final trimmed = name.trim();
    final initial = trimmed.isEmpty ? '?' : trimmed.characters.first;
    return CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.goldSoft,
      foregroundColor: AppColors.charcoal,
      child: Text(
        initial.toUpperCase(),
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _Identity extends StatelessWidget {
  const _Identity({required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          session.displayName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelLarge?.copyWith(
            color: AppColors.charcoal,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          session.email,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.neutral600,
          ),
        ),
      ],
    );
  }
}
