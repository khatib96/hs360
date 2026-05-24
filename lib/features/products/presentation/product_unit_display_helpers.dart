import 'package:hs360/l10n/app_localizations.dart';

import '../../inventory/domain/warehouse.dart';
import '../domain/product_unit.dart';
import '../domain/product_unit_health_status.dart';
import '../domain/unit_status.dart';

String localizedWarehouseName(Warehouse warehouse, String languageCode) {
  if (languageCode.toLowerCase() == 'ar') {
    return warehouse.nameAr;
  }
  return warehouse.nameEn;
}

String productUnitWarehouseLabel(ProductUnit unit, String languageCode) {
  if (languageCode.toLowerCase() == 'ar') {
    return unit.warehouseNameAr ?? unit.currentWarehouseId ?? '—';
  }
  return unit.warehouseNameEn ?? unit.currentWarehouseId ?? '—';
}

String unitStatusLabel(AppLocalizations l10n, UnitStatus status) {
  return switch (status) {
    UnitStatus.availableNew => l10n.productUnitStatusAvailableNew,
    UnitStatus.availableUsed => l10n.productUnitStatusAvailableUsed,
    UnitStatus.rented => l10n.productUnitStatusRented,
    UnitStatus.trial => l10n.productUnitStatusTrial,
    UnitStatus.maintenance => l10n.productUnitStatusMaintenance,
    UnitStatus.sold => l10n.productUnitStatusSold,
    UnitStatus.damaged => l10n.productUnitStatusDamaged,
    UnitStatus.lost => l10n.productUnitStatusLost,
    UnitStatus.retired => l10n.productUnitStatusRetired,
  };
}

String unitHealthLabel(
  AppLocalizations l10n,
  ProductUnitHealthStatus health,
) {
  return switch (health) {
    ProductUnitHealthStatus.good => l10n.productUnitHealthGood,
    ProductUnitHealthStatus.needsService => l10n.productUnitHealthNeedsService,
    ProductUnitHealthStatus.damaged => l10n.productUnitHealthDamaged,
    ProductUnitHealthStatus.lost => l10n.productUnitHealthLost,
  };
}
