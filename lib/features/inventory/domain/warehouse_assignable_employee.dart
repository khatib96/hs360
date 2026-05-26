class WarehouseAssignableEmployee {
  const WarehouseAssignableEmployee({
    required this.id,
    required this.code,
    required this.nameAr,
    required this.nameEn,
    required this.isActive,
  });

  final String id;
  final String code;
  final String nameAr;
  final String nameEn;
  final bool isActive;

  factory WarehouseAssignableEmployee.fromRow(Map<String, dynamic> row) {
    return WarehouseAssignableEmployee(
      id: row['id'] as String,
      code: row['code'] as String,
      nameAr: row['name_ar'] as String,
      nameEn: row['name_en'] as String? ?? '',
      isActive: row['is_active'] as bool? ?? true,
    );
  }
}
