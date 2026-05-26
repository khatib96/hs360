import '../domain/warehouse.dart';
import '../domain/warehouse_assignable_employee.dart';

class WarehousesState {
  const WarehousesState({
    this.warehouses = const [],
    this.employees = const [],
    this.isLoading = false,
    this.errorCode,
  });

  final List<Warehouse> warehouses;
  final List<WarehouseAssignableEmployee> employees;
  final bool isLoading;
  final String? errorCode;

  bool get hasError => errorCode != null;

  Map<String, WarehouseAssignableEmployee> get employeesById => {
        for (final e in employees) e.id: e,
      };

  WarehousesState copyWith({
    List<Warehouse>? warehouses,
    List<WarehouseAssignableEmployee>? employees,
    bool? isLoading,
    String? errorCode,
    bool clearError = false,
  }) {
    return WarehousesState(
      warehouses: warehouses ?? this.warehouses,
      employees: employees ?? this.employees,
      isLoading: isLoading ?? this.isLoading,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
    );
  }
}
