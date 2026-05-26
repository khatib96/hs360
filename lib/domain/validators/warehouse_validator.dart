import '../../core/errors/products_exception.dart';
import '../../features/inventory/domain/warehouse.dart';
import '../../features/inventory/domain/warehouse_form_state.dart';
import '../../features/inventory/domain/warehouse_type.dart';
import 'validation_result.dart';

class WarehouseValidator {
  const WarehouseValidator();

  ValidationResult validate(
    WarehouseFormState input, {
    List<Warehouse> existingWarehouses = const [],
    String? excludeWarehouseId,
  }) {
    final codes = <String>[];

    if (input.nameAr.trim().isEmpty) {
      codes.add(ProductsException.nameArRequired);
    }
    if (input.nameEn.trim().isEmpty) {
      codes.add(ProductsException.nameEnRequired);
    }

    if (input.type == WarehouseType.van) {
      if (input.agentId == null || input.agentId!.trim().isEmpty) {
        codes.add(ProductsException.warehouseAgentRequired);
      }
    }

    if (input.isActive &&
        input.type == WarehouseType.van &&
        input.agentId != null &&
        input.agentId!.trim().isNotEmpty) {
      final agentId = input.agentId!.trim();
      final duplicate = existingWarehouses.any(
        (w) =>
            w.id != excludeWarehouseId &&
            w.isActive &&
            w.type == WarehouseType.van &&
            w.agentId == agentId,
      );
      if (duplicate) {
        codes.add(ProductsException.duplicateActiveVanWarehouse);
      }
    }

    if (codes.isEmpty) return const ValidationResult.valid();
    return ValidationResult(codes: codes);
  }
}
