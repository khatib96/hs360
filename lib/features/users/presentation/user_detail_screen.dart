import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_detail_surface.dart';
import '../../../shared/widgets/app_lifecycle_action_dialog.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/app_state_view.dart';
import '../../../shared/widgets/app_status_badge.dart';
import '../../../shared/widgets/message_banner.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/users_repository.dart';
import '../domain/permission_catalog.dart';
import '../domain/tenant_user_account.dart';
import '../domain/users_permissions.dart';
import 'users_messages.dart';
import 'users_providers.dart';
import 'widgets/permission_editor.dart';
import 'widgets/reset_password_dialog.dart';

class UserDetailScreen extends ConsumerWidget {
  const UserDetailScreen({required this.tenantUserId, super.key});

  final String tenantUserId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(authControllerProvider).valueOrNull;
    final users = ref.watch(tenantUsersProvider);
    final catalog = ref.watch(permissionCatalogProvider);

    Widget body;
    TenantUserAccount? account;
    if (users.isLoading || catalog.isLoading || session == null) {
      body = AppStateView.loading(message: l10n.loading);
    } else if (users.hasError || catalog.hasError) {
      body = AppStateView.error(
        message: usersErrorMessage(l10n, (users.error ?? catalog.error)!),
        action: FilledButton(
          onPressed: () {
            ref.invalidate(tenantUsersProvider);
            ref.invalidate(permissionCatalogProvider);
          },
          child: Text(l10n.retry),
        ),
      );
    } else {
      account = users.requireValue
          .where((item) => item.tenantUserId == tenantUserId)
          .firstOrNull;
      body = account == null
          ? AppStateView.empty(
              icon: Icons.person_off_outlined,
              message: l10n.usersEmpty,
            )
          : _UserDetailBody(
              session: session,
              account: account,
              groups: groupPermissionsForEditor(catalog.requireValue),
            );
    }

    return AppShell(
      title: account?.label ?? l10n.navUsersSettings,
      currentRoute: AppRoutes.usersSettings,
      moduleActions: [
        if (session != null && account != null)
          ..._actions(context, ref, session, account),
      ],
      body: body,
    );
  }

  List<Widget> _actions(
    BuildContext context,
    WidgetRef ref,
    AppSession session,
    TenantUserAccount account,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final manageable =
        !account.isSelf && (!account.isManager || session.isManager);
    if (!manageable) return const [];

    return [
      if (canEditUserPermissions(session))
        OutlinedButton.icon(
          key: const Key('user-reset-password'),
          onPressed: () => _resetPassword(context, ref, account),
          icon: const Icon(Icons.key_outlined),
          label: Text(l10n.usersResetPassword),
        ),
      if (canDeactivateUsers(session))
        account.isActive
            ? OutlinedButton.icon(
                key: const Key('user-deactivate'),
                onPressed: () => _setActive(context, ref, account, false),
                icon: const Icon(Icons.block_outlined),
                label: Text(l10n.usersDeactivate),
              )
            : FilledButton.icon(
                key: const Key('user-activate'),
                onPressed: () => _setActive(context, ref, account, true),
                icon: const Icon(Icons.check_circle_outline),
                label: Text(l10n.usersActivate),
              ),
    ];
  }

  Future<void> _resetPassword(
    BuildContext context,
    WidgetRef ref,
    TenantUserAccount account,
  ) async {
    final done = await showResetPasswordDialog(context, account: account);
    if (done != true || !context.mounted) return;
    ref.invalidate(tenantUsersProvider);
    _snack(context, AppLocalizations.of(context)!.usersResetPasswordDone);
  }

  Future<void> _setActive(
    BuildContext context,
    WidgetRef ref,
    TenantUserAccount account,
    bool isActive,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    if (!isActive) {
      final confirmed = await showAppLifecycleActionDialog(
        context: context,
        title: l10n.usersDeactivate,
        consequence: l10n.usersDeactivateConfirm(account.label),
        confirmLabel: l10n.usersDeactivate,
      );
      if (confirmed == null || !context.mounted) return;
    }
    try {
      await ref
          .read(usersRepositoryProvider)
          .setActive(account.tenantUserId, isActive);
      ref.invalidate(tenantUsersProvider);
      if (context.mounted) {
        _snack(context, isActive ? l10n.usersActivated : l10n.usersDeactivated);
      }
    } catch (error) {
      if (context.mounted) _snack(context, usersErrorMessage(l10n, error));
    }
  }
}

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

class _UserDetailBody extends ConsumerWidget {
  const _UserDetailBody({
    required this.session,
    required this.account,
    required this.groups,
  });

  final AppSession session;
  final TenantUserAccount account;
  final List<PermissionGroup> groups;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = ref.watch(localeProvider).languageCode;
    final canEdit =
        canEditUserPermissions(session) &&
        !account.isSelf &&
        !account.isManager;

    return SingleChildScrollView(
      padding: AppSpacing.page,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppDetailSection(
            title: account.label,
            trailing: Wrap(
              spacing: AppSpacing.xs,
              children: [
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
              ],
            ),
            child: AppInfoRow(
              label: l10n.usersColumnLogin,
              value: Text(account.login),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          if (account.isSelf)
            MessageBanner(
              variant: MessageBannerVariant.info,
              message: l10n.usersSelfNote,
            )
          else if (account.isManager)
            MessageBanner(
              variant: MessageBannerVariant.info,
              message: l10n.usersManagerFullAccess,
            )
          else
            PermissionEditor(
              key: Key('permission-editor-${account.tenantUserId}'),
              groups: groups,
              initial: account.permissionIds,
              languageCode: languageCode,
              canChange: (id) => canEdit && canChangePermission(session, id),
              onSave: (selected) => _save(context, ref, selected),
            ),
        ],
      ),
    );
  }

  Future<bool> _save(
    BuildContext context,
    WidgetRef ref,
    Set<String> selected,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      await ref
          .read(usersRepositoryProvider)
          .setPermissions(account.tenantUserId, selected);
      ref.invalidate(tenantUsersProvider);
      if (context.mounted) _snack(context, l10n.usersPermissionsSaved);
      return true;
    } catch (error) {
      if (context.mounted) _snack(context, usersErrorMessage(l10n, error));
      return false;
    }
  }
}
