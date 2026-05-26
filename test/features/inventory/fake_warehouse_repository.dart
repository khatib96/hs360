import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/inventory/data/warehouse_repository.dart';
import 'package:hs360/features/inventory/domain/warehouse.dart';
import 'package:hs360/features/inventory/domain/warehouse_assignable_employee.dart';
import 'package:hs360/features/inventory/domain/warehouse_form_state.dart';
import 'package:hs360/features/inventory/domain/warehouse_type.dart';

class FakeWarehouseRepository extends WarehouseRepository {
  FakeWarehouseRepository({
    this.warehouses = const [],
    this.employees = const [],
  }) : super(null);

  List<Warehouse> warehouses;
  List<WarehouseAssignableEmployee> employees;
  WarehouseFormState? lastCreateInput;
  WarehouseFormState? lastUpdateInput;
  String? lastDeactivatedId;
  bool? lastActiveOnly;

  @override
  Future<List<Warehouse>> fetchWarehouses({bool activeOnly = false}) async {
    lastActiveOnly = activeOnly;
    if (activeOnly) {
      return warehouses.where((w) => w.isActive).toList();
    }
    return List<Warehouse>.from(warehouses);
  }

  @override
  Future<List<WarehouseAssignableEmployee>> fetchAssignableEmployees() async {
    return List<WarehouseAssignableEmployee>.from(employees);
  }

  @override
  Future<Warehouse> createWarehouse(
    AppSession session,
    WarehouseFormState input, {
    List<Warehouse> existingWarehouses = const [],
  }) async {
    lastCreateInput = input;
    final created = sampleWarehouse(id: 'new-wh');
    warehouses = [...warehouses, created];
    return created;
  }

  @override
  Future<Warehouse> updateWarehouse(
    AppSession session,
    String id,
    WarehouseFormState input, {
    List<Warehouse> existingWarehouses = const [],
  }) async {
    lastUpdateInput = input;
    return sampleWarehouse(id: id);
  }

  @override
  Future<void> deactivateWarehouse(AppSession session, String id) async {
    lastDeactivatedId = id;
    warehouses = [
      for (final w in warehouses)
        if (w.id == id)
          Warehouse(
            id: w.id,
            tenantId: w.tenantId,
            nameAr: w.nameAr,
            nameEn: w.nameEn,
            type: w.type,
            agentId: w.agentId,
            locationAddress: w.locationAddress,
            isActive: false,
            createdAt: w.createdAt,
          )
        else
          w,
    ];
  }
}

Warehouse sampleWarehouse({
  String id = 'wh-1',
  WarehouseType type = WarehouseType.main,
  String? agentId,
  bool isActive = true,
}) {
  return Warehouse(
    id: id,
    tenantId: 'tenant',
    nameAr: 'مخزن',
    nameEn: 'Warehouse',
    type: type,
    agentId: agentId,
    isActive: isActive,
  );
}

WarehouseAssignableEmployee sampleEmployee({
  String id = 'emp-1',
  String code = 'EMP-001',
  bool isActive = true,
}) {
  return WarehouseAssignableEmployee(
    id: id,
    code: code,
    nameAr: 'موظف',
    nameEn: 'Employee',
    isActive: isActive,
  );
}
