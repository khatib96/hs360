/// Permission checks for the current session. Managers bypass all checks.
class AppPermissions {
  AppPermissions({required this.isManager, required Set<String> permissions})
    : permissions = Set.unmodifiable(permissions);

  final bool isManager;
  final Set<String> permissions;

  bool can(String permissionId) {
    if (isManager) return true;
    return permissions.contains(permissionId);
  }

  bool hasAny(Iterable<String> permissionIds) {
    if (isManager) return true;
    for (final id in permissionIds) {
      if (permissions.contains(id)) return true;
    }
    return false;
  }

  bool hasModule(String modulePrefix) {
    if (isManager) return true;
    return permissions.any(
      (p) => p == modulePrefix || p.startsWith('$modulePrefix.'),
    );
  }

  factory AppPermissions.fromRpc(Map<String, dynamic> data) {
    final isManager = data['is_manager'] as bool? ?? false;
    final raw = data['permissions'];
    final granted = <String>{};

    if (raw is List) {
      for (final item in raw) {
        if (item is String) granted.add(item);
      }
    }

    return AppPermissions(isManager: isManager, permissions: granted);
  }

  static final empty = AppPermissions(isManager: false, permissions: {});
  static final manager = AppPermissions(isManager: true, permissions: {});
}
