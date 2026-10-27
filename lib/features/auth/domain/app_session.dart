import 'app_permissions.dart';

/// Authenticated user context for routing and permission gates.
class AppSession {
  const AppSession({
    required this.userId,
    required this.email,
    required this.tenantId,
    required this.tenantUserId,
    required this.accountType,
    required this.displayName,
    required this.preferredLocale,
    required this.permissions,
    this.mustChangePassword = false,
  });

  final String userId;
  final String email;
  final String tenantId;
  final String tenantUserId;
  final String accountType;
  final String displayName;
  final String preferredLocale;
  final AppPermissions permissions;

  /// Set after an admin created the login or reset its password.
  final bool mustChangePassword;

  bool get isManager => accountType == 'manager';
}
