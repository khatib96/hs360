import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/products_exception.dart';
import 'package:hs360/domain/validators/warehouse_validator.dart';
import 'package:hs360/features/inventory/domain/warehouse.dart';
import 'package:hs360/features/inventory/domain/warehouse_form_state.dart';
import 'package:hs360/features/inventory/domain/warehouse_type.dart';

Warehouse _warehouse({
  required String id,
  required WarehouseType type,
  String? agentId,
  bool isActive = true,
}) {
  return Warehouse(
    id: id,
    tenantId: 'tenant',
    nameAr: 'م',
    nameEn: 'W',
    type: type,
    agentId: agentId,
    isActive: isActive,
  );
}

void main() {
  const validator = WarehouseValidator();

  test('requires Arabic and English names', () {
    final result = validator.validate(
      const WarehouseFormState(
        nameAr: ' ',
        nameEn: '',
        type: WarehouseType.main,
      ),
    );
    expect(result.isValid, isFalse);
    expect(result.codes, contains(ProductsException.nameArRequired));
    expect(result.codes, contains(ProductsException.nameEnRequired));
  });

  test('van requires employee', () {
    final result = validator.validate(
      const WarehouseFormState(
        nameAr: 'سيارة',
        nameEn: 'Van',
        type: WarehouseType.van,
      ),
    );
    expect(result.codes, contains(ProductsException.warehouseAgentRequired));
  });

  test('valid van passes', () {
    final result = validator.validate(
      const WarehouseFormState(
        nameAr: 'سيارة',
        nameEn: 'Van',
        type: WarehouseType.van,
        agentId: 'emp-1',
      ),
    );
    expect(result.isValid, isTrue);
  });

  test('rejects duplicate active van for same employee', () {
    final result = validator.validate(
      const WarehouseFormState(
        nameAr: 'سيارة 2',
        nameEn: 'Van 2',
        type: WarehouseType.van,
        agentId: 'emp-1',
      ),
      existingWarehouses: [
        _warehouse(
          id: 'w1',
          type: WarehouseType.van,
          agentId: 'emp-1',
        ),
      ],
    );
    expect(
      result.codes,
      contains(ProductsException.duplicateActiveVanWarehouse),
    );
  });

  test('allows new active van when previous van is inactive', () {
    final result = validator.validate(
      const WarehouseFormState(
        nameAr: 'سيارة جديدة',
        nameEn: 'New van',
        type: WarehouseType.van,
        agentId: 'emp-1',
      ),
      existingWarehouses: [
        _warehouse(
          id: 'w1',
          type: WarehouseType.van,
          agentId: 'emp-1',
          isActive: false,
        ),
      ],
    );
    expect(result.isValid, isTrue);
  });

  test('non-van with stale agentId passes at validator layer', () {
    final result = validator.validate(
      const WarehouseFormState(
        nameAr: 'مخزن',
        nameEn: 'Main',
        type: WarehouseType.main,
        agentId: 'emp-1',
      ),
    );
    expect(result.isValid, isTrue);
  });
}
