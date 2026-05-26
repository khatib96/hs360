import 'warehouse_type.dart';

/// Input for create/update warehouse.
class WarehouseFormState {
  const WarehouseFormState({
    required this.nameAr,
    required this.nameEn,
    required this.type,
    this.agentId,
    this.locationAddress,
    this.isActive = true,
  });

  final String nameAr;
  final String nameEn;
  final WarehouseType type;
  final String? agentId;
  final String? locationAddress;
  final bool isActive;
}
