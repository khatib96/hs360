import '../../auth/domain/app_session.dart';

bool canViewUsers(AppSession session) =>
    session.isManager || session.permissions.can('settings.users.view');

bool canEditUserPermissions(AppSession session) =>
    session.isManager || session.permissions.can('settings.users.edit');

bool canAddUsers(AppSession session) =>
    session.isManager || session.permissions.can('settings.users.invite');

bool canDeactivateUsers(AppSession session) =>
    session.isManager || session.permissions.can('settings.users.deactivate');

/// Non-managers may only grant or remove permissions they hold themselves
/// (enforced again by `set_tenant_user_permissions`).
bool canChangePermission(AppSession session, String permissionId) =>
    session.isManager || session.permissions.can(permissionId);
