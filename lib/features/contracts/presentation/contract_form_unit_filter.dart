import '../../products/domain/product_unit.dart';
import '../../products/domain/unit_status.dart';

List<ProductUnit> filterAvailableContractUnits(List<ProductUnit> units) {
  return units
      .where(
        (unit) =>
            unit.status == UnitStatus.availableNew ||
            unit.status == UnitStatus.availableUsed,
      )
      .toList();
}
