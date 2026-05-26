import '../domain/warehouse.dart';
import '../domain/warehouse_assignable_employee.dart';
import '../domain/warehouse_type.dart';

String localizedWarehouseName(Warehouse warehouse, String languageCode) {
  if (languageCode.toLowerCase() == 'ar') {
    return warehouse.nameAr;
  }
  return warehouse.nameEn;
}

String localizedEmployeeName(
  WarehouseAssignableEmployee employee,
  String languageCode,
) {
  if (languageCode.toLowerCase() == 'ar') {
    return employee.nameAr;
  }
  return employee.nameEn.isNotEmpty ? employee.nameEn : employee.nameAr;
}

String localizedEmployeeLabel(
  WarehouseAssignableEmployee employee,
  String languageCode,
) {
  return '${employee.code} - ${localizedEmployeeName(employee, languageCode)}';
}

String localizedWarehouseTypeLabel(
  WarehouseType type,
  String Function(String key) labelFor,
) {
  return switch (type) {
    WarehouseType.main => labelFor('main'),
    WarehouseType.branch => labelFor('branch'),
    WarehouseType.van => labelFor('van'),
  };
}

/// Employees eligible for van assignment in the form dropdown.
List<WarehouseAssignableEmployee> dropdownAssignableEmployees({
  required List<WarehouseAssignableEmployee> employees,
  required List<Warehouse> warehouses,
  String? excludeWarehouseId,
  String? includeAgentId,
}) {
  final blockedAgentIds = <String>{
    for (final w in warehouses)
      if (w.isActive &&
          w.type == WarehouseType.van &&
          w.agentId != null &&
          w.id != excludeWarehouseId)
        w.agentId!,
  };

  return employees.where((e) {
    if (!e.isActive) return false;
    if (e.id == includeAgentId) return true;
    return !blockedAgentIds.contains(e.id);
  }).toList();
}

String? employeeLabelForAgentId({
  required String? agentId,
  required Map<String, WarehouseAssignableEmployee> employeesById,
  required String languageCode,
  required String inactiveHint,
}) {
  if (agentId == null) return null;
  final employee = employeesById[agentId];
  if (employee == null) return null;
  final label = localizedEmployeeLabel(employee, languageCode);
  if (!employee.isActive) {
    return '$label ($inactiveHint)';
  }
  return label;
}
