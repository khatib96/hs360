class ProductGroup {
  const ProductGroup({
    required this.id,
    required this.tenantId,
    required this.nameAr,
    required this.nameEn,
    this.parentId,
    this.sortOrder = 0,
    required this.isActive,
    this.createdAt,
  });

  final String id;
  final String tenantId;
  final String nameAr;
  final String nameEn;
  final String? parentId;
  final int sortOrder;
  final bool isActive;
  final DateTime? createdAt;

  factory ProductGroup.fromRow(Map<String, dynamic> row) {
    return ProductGroup(
      id: row['id'] as String,
      tenantId: row['tenant_id'] as String,
      nameAr: row['name_ar'] as String,
      nameEn: row['name_en'] as String,
      parentId: row['parent_id'] as String?,
      sortOrder: row['sort_order'] as int? ?? 0,
      isActive: row['is_active'] as bool? ?? true,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : null,
    );
  }
}

/// Input for create/update product group.
class ProductGroupFormState {
  const ProductGroupFormState({
    required this.nameAr,
    required this.nameEn,
    this.parentId,
    this.sortOrder = 0,
    this.isActive = true,
  });

  final String nameAr;
  final String nameEn;
  final String? parentId;
  final int sortOrder;
  final bool isActive;
}
