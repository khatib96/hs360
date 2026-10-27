/// One login of the current company, as returned by `list_tenant_users`.
class TenantUserAccount {
  const TenantUserAccount({
    required this.tenantUserId,
    required this.userId,
    required this.displayName,
    required this.login,
    required this.accountType,
    required this.isActive,
    required this.mustChangePassword,
    required this.isSelf,
    required this.permissionIds,
    this.lastSignInAt,
  });

  final String tenantUserId;
  final String userId;
  final String displayName;
  final String login;
  final String accountType;
  final bool isActive;
  final bool mustChangePassword;
  final bool isSelf;
  final Set<String> permissionIds;
  final DateTime? lastSignInAt;

  bool get isManager => accountType == 'manager';

  String get label => displayName.trim().isEmpty ? login : displayName;

  factory TenantUserAccount.fromJson(Map<String, dynamic> json) {
    final permissions = json['permission_ids'];
    return TenantUserAccount(
      tenantUserId: json['tenant_user_id'] as String,
      userId: json['user_id'] as String,
      displayName: json['display_name'] as String? ?? '',
      login: json['login'] as String? ?? '',
      accountType: json['account_type'] as String? ?? 'user',
      isActive: json['is_active'] == true,
      mustChangePassword: json['must_change_password'] == true,
      isSelf: json['is_self'] == true,
      permissionIds: {
        if (permissions is List)
          for (final id in permissions)
            if (id is String) id,
      },
      lastSignInAt: DateTime.tryParse(
        json['last_sign_in_at']?.toString() ?? '',
      )?.toLocal(),
    );
  }
}
