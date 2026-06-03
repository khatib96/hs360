import 'account_type.dart';

/// Chart-of-accounts row from [chart_of_accounts].
class ChartAccount {
  const ChartAccount({
    required this.id,
    required this.tenantId,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.type,
    this.parentId,
    required this.isSubaccount,
    this.relatedEntityTable,
    this.relatedEntityId,
    required this.isActive,
    required this.isSystem,
    this.createdAt,
  });

  final String id;
  final String tenantId;
  final String code;
  final String nameAr;
  final String nameEn;
  final AccountType type;
  final String? parentId;
  final bool isSubaccount;
  final String? relatedEntityTable;
  final String? relatedEntityId;
  final bool isActive;
  final bool isSystem;
  final DateTime? createdAt;

  bool get isEntityLinked => relatedEntityId != null;

  bool get isCustomerSubaccount => relatedEntityTable == 'customers';

  bool get isSupplierSubaccount => relatedEntityTable == 'suppliers';

  bool get isManualAccount => !isSystem && !isEntityLinked;

  bool get canManualEdit => isManualAccount;

  bool get canManualDeactivate => isManualAccount;

  String displayName(String locale) {
    if (locale == 'ar') return nameAr;
    return nameEn;
  }

  factory ChartAccount.fromRow(Map<String, dynamic> row) {
    return ChartAccount(
      id: row['id'] as String,
      tenantId: row['tenant_id'] as String,
      code: row['code'] as String,
      nameAr: row['name_ar'] as String,
      nameEn: row['name_en'] as String,
      type: AccountType.fromDb(row['type'] as String?),
      parentId: row['parent_id'] as String?,
      isSubaccount: row['is_subaccount'] as bool? ?? false,
      relatedEntityTable: row['related_entity_table'] as String?,
      relatedEntityId: row['related_entity_id'] as String?,
      isActive: row['is_active'] as bool? ?? true,
      isSystem: row['is_system'] as bool? ?? false,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : null,
    );
  }
}

/// Explicit column list for [chart_of_accounts] (no updated_at column).
abstract final class ChartAccountColumns {
  static const list = '''
id, tenant_id, code, name_ar, name_en, type, parent_id,
is_subaccount, related_entity_table, related_entity_id,
is_active, is_system, created_at
''';
}
