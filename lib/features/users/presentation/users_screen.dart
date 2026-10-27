import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/app_state_view.dart';
import '../../../shared/widgets/app_status_badge.dart';
import '../../../shared/widgets/app_table_frame.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/permission_catalog.dart';
import '../domain/tenant_user_account.dart';
import '../domain/users_permissions.dart';
import 'users_messages.dart';
import 'users_providers.dart';
import 'widgets/create_user_dialog.dart';

class UsersScreen extends ConsumerWidget {
  const UsersScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(authControllerProvider).valueOrNull;
    final users = ref.watch(tenantUsersProvider);

    return AppShell(
      title: l10n.navUsersSettings,
      currentRoute: AppRoutes.usersSettings,
      moduleActions: [
        if (session != null && canAddUsers(session))
          FilledButton.icon(
            key: const Key('users-add-command'),
            onPressed: () => _addUser(context, ref, session.isManager),
            icon: const Icon(Icons.person_add_alt_1_outlined),
            label: Text(l10n.usersAdd),
          ),
      ],
      body: users.when(
        loading: () => AppStateView.loading(message: l10n.loading),
        error: (error, _) => AppStateView.error(
          message: '${l10n.usersLoadError}\n${usersErrorMessage(l10n, error)}',
          action: FilledButton(
            onPressed: () => ref.invalidate(tenantUsersProvider),
            child: Text(l10n.retry),
          ),
        ),
        data: (accounts) => accounts.isEmpty
            ? AppStateView.empty(
                icon: Icons.group_outlined,
                message: l10n.usersEmpty,
              )
            : AppTableFrame(
                // Rows paint ink on this Material, not under the frame color.
                child: Material(
                  type: MaterialType.transparency,
                  child: ListView.separated(
                    key: const Key('users-list'),
                    itemCount: accounts.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) => _UserRow(
                      account: accounts[index],
                      onOpen: () => context.push(
                        AppRoutes.usersSettingsDetailPath(
                          accounts[index].tenantUserId,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
      ),
    );
  }

  Future<void> _addUser(
    BuildContext context,
    WidgetRef ref,
    bool canCreateManager,
  ) async {
    final created = await showCreateUserDialog(
      context,
      canCreateManager: canCreateManager,
    );
    if (created != true || !context.mounted) return;
    ref.invalidate(tenantUsersProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(AppLocalizations.of(context)!.usersCreated)),
    );
  }
}

class _UserRow extends StatelessWidget {
  const _UserRow({required this.account, required this.onOpen});

  final TenantUserAccount account;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final lastSignIn = account.lastSignInAt;
    final grantedCount = account.permissionIds
        .where(isPermissionOfferedInEditor)
        .length;

    return ListTile(
      key: Key('user-row-${account.tenantUserId}'),
      onTap: onOpen,
      leading: CircleAvatar(
        backgroundColor: AppColors.neutral100,
        child: Text(
          account.label.characters.first.toUpperCase(),
          style: theme.textTheme.titleSmall,
        ),
      ),
      title: Wrap(
        spacing: AppSpacing.xs,
        runSpacing: AppSpacing.xxs,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(account.label, style: theme.textTheme.titleSmall),
          if (account.isSelf)
            AppStatusBadge(label: l10n.usersYou, tone: AppStatusTone.info),
          AppStatusBadge(
            label: account.isManager
                ? l10n.usersTypeManager
                : l10n.usersTypeUser,
            tone: account.isManager
                ? AppStatusTone.brand
                : AppStatusTone.neutral,
          ),
          AppStatusBadge(
            label: account.isActive
                ? l10n.usersStatusActive
                : l10n.usersStatusInactive,
            tone: account.isActive
                ? AppStatusTone.success
                : AppStatusTone.error,
          ),
          if (account.mustChangePassword)
            AppStatusBadge(
              label: l10n.usersMustChangePassword,
              tone: AppStatusTone.warning,
            ),
          // Can sign in but sees nothing useful.
          if (!account.isManager && grantedCount == 0)
            AppStatusBadge(
              label: l10n.usersNoPermissions,
              tone: AppStatusTone.warning,
            ),
        ],
      ),
      subtitle: Text(
        [
          account.login,
          account.isManager
              ? l10n.usersFullAccess
              : l10n.usersPermissionCount(grantedCount),
          '${l10n.usersColumnLastSignIn}: ${lastSignIn == null ? l10n.usersNeverSignedIn : DateFormat.yMd(locale).add_jm().format(lastSignIn)}',
        ].join(' · '),
      ),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
