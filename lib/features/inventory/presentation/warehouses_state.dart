import '../domain/warehouse.dart';
import '../domain/warehouse_assignable_employee.dart';

class WarehousesState {
  const WarehousesState({
    this.warehouses = const [],
    this.employees = const [],
    this.isLoading = false,
    this.errorCode,
    this.employeeLookupErrorCode,
  });

  final List<Warehouse> warehouses;
  final List<WarehouseAssignableEmployee> employees;
  final bool isLoading;
  final String? errorCode;
  final String? employeeLookupErrorCode;

  bool get hasError => errorCode != null;
  bool get hasEmployeeLookupWarning => employeeLookupErrorCode != null;

  Map<String, WarehouseAssignableEmployee> get employeesById => {
        for (final e in employees) e.id: e,
      };

  WarehousesState copyWith({
    List<Warehouse>? warehouses,
    List<WarehouseAssignableEmployee>? employees,
    bool? isLoading,
    String? errorCode,
    String? employeeLookupErrorCode,
    bool clearError = false,
    bool clearEmployeeLookupError = false,
  }) {
    return WarehousesState(
      warehouses: warehouses ?? this.warehouses,
      employees: employees ?? this.employees,
      isLoading: isLoading ?? this.isLoading,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      employeeLookupErrorCode: clearEmployeeLookupError
          ? null
          : (employeeLookupErrorCode ?? this.employeeLookupErrorCode),
    );
  }
}
