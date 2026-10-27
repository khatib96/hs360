/// One row of the global `permissions` catalog.
class PermissionCatalogEntry {
  const PermissionCatalogEntry({
    required this.id,
    required this.category,
    required this.labelAr,
    required this.labelEn,
    required this.isSensitive,
    required this.sortOrder,
  });

  final String id;
  final String category;
  final String labelAr;
  final String labelEn;
  final bool isSensitive;
  final int sortOrder;

  String label(String languageCode) {
    final preferred = languageCode == 'ar' ? labelAr : labelEn;
    if (preferred.trim().isNotEmpty) return preferred;
    return labelEn.trim().isNotEmpty ? labelEn : id;
  }

  factory PermissionCatalogEntry.fromJson(Map<String, dynamic> json) {
    final sortOrder = json['sort_order'];
    return PermissionCatalogEntry(
      id: json['id'] as String,
      category: json['category'] as String? ?? '',
      labelAr: json['label_ar'] as String? ?? '',
      labelEn: json['label_en'] as String? ?? '',
      isSensitive: json['is_sensitive'] == true,
      sortOrder: sortOrder is int ? sortOrder : 0,
    );
  }
}

class PermissionGroup {
  const PermissionGroup({required this.category, required this.entries});

  final String category;
  final List<PermissionCatalogEntry> entries;
}

/// Permissions of modules that are not built yet. Granting them has no
/// effect today, so the editor does not offer them.
const _hiddenPermissionPrefixes = [
  'hr.',
  'maintenance.',
  'quotations.',
  'visits.',
  'notifications.create',
  'notifications.delete',
  'settings.company.delete',
];

/// Display order of catalog categories in the editor.
const permissionCategoryOrder = [
  'core',
  'sales',
  'purchasing',
  'finance',
  'accounting',
  'inventory',
  'calendar',
  'communications',
  'settings',
  'security',
];

bool isPermissionOfferedInEditor(String permissionId) =>
    !_hiddenPermissionPrefixes.any(permissionId.startsWith);

/// Groups the offered permissions by category in a stable display order.
List<PermissionGroup> groupPermissionsForEditor(
  Iterable<PermissionCatalogEntry> catalog,
) {
  final byCategory = <String, List<PermissionCatalogEntry>>{};
  for (final entry in catalog) {
    if (!isPermissionOfferedInEditor(entry.id)) continue;
    byCategory.putIfAbsent(entry.category, () => []).add(entry);
  }

  int rank(String category) {
    final index = permissionCategoryOrder.indexOf(category);
    return index < 0 ? permissionCategoryOrder.length : index;
  }

  final categories = byCategory.keys.toList()
    ..sort((a, b) {
      final byRank = rank(a).compareTo(rank(b));
      return byRank != 0 ? byRank : a.compareTo(b);
    });

  return [
    for (final category in categories)
      PermissionGroup(
        category: category,
        entries: byCategory[category]!
          ..sort((a, b) {
            final bySort = a.sortOrder.compareTo(b.sortOrder);
            return bySort != 0 ? bySort : a.id.compareTo(b.id);
          }),
      ),
  ];
}
