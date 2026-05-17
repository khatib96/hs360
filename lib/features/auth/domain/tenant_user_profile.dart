/// Active tenant membership row used to build [AppSession].
class TenantUserProfile {
  const TenantUserProfile({
    required this.tenantUserId,
    required this.tenantId,
    required this.accountType,
    required this.displayName,
    required this.preferredLocale,
  });

  final String tenantUserId;
  final String tenantId;
  final String accountType;
  final String displayName;
  final String preferredLocale;

  factory TenantUserProfile.fromRow(Map<String, dynamic> row) {
    return TenantUserProfile(
      tenantUserId: row['id'] as String,
      tenantId: row['tenant_id'] as String,
      accountType: row['account_type'] as String,
      displayName: (row['display_name'] as String?) ?? '',
      preferredLocale: (row['preferred_locale'] as String?) ?? 'ar',
    );
  }
}
