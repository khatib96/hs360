import 'warehouse_type.dart';

class Warehouse {
  const Warehouse({
    required this.id,
    required this.tenantId,
    required this.nameAr,
    required this.nameEn,
    required this.type,
    this.agentId,
    this.locationAddress,
    required this.isActive,
    this.createdAt,
  });

  final String id;
  final String tenantId;
  final String nameAr;
  final String nameEn;
  final WarehouseType type;
  final String? agentId;
  final String? locationAddress;
  final bool isActive;
  final DateTime? createdAt;

  factory Warehouse.fromRow(Map<String, dynamic> row) {
    return Warehouse(
      id: row['id'] as String,
      tenantId: row['tenant_id'] as String,
      nameAr: row['name_ar'] as String,
      nameEn: row['name_en'] as String,
      type: WarehouseType.fromDb(row['type'] as String?),
      agentId: row['agent_id'] as String?,
      locationAddress: row['location_address'] as String?,
      isActive: row['is_active'] as bool? ?? true,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : null,
    );
  }
}
