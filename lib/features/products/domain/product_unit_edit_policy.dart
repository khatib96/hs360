import 'unit_status.dart';

/// UX hint for safe edit; authoritative check is [update_product_unit_safe] RPC.
bool isUnitSafeEditable(UnitStatus status) {
  return switch (status) {
    UnitStatus.rented ||
    UnitStatus.trial ||
    UnitStatus.maintenance ||
    UnitStatus.sold ||
    UnitStatus.retired => false,
    UnitStatus.availableNew ||
    UnitStatus.availableUsed ||
    UnitStatus.damaged ||
    UnitStatus.lost => true,
  };
}
