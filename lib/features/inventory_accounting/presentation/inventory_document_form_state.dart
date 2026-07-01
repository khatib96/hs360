import 'package:decimal/decimal.dart';

import '../../../domain/validators/inventory_adjustment_document_validator.dart';
import '../../inventory/domain/warehouse.dart';
import '../../products/domain/product.dart';
import '../../products/domain/product_unit.dart';
import '../domain/inventory_adjustment_reason.dart';
import 'inventory_document_form_mode.dart';

class InventoryDocumentFormLineState {
  InventoryDocumentFormLineState({
    this.product,
    Decimal? qty,
    this.unitCost,
    Decimal? countedQty,
    this.systemQty,
    List<String>? unitIds,
    List<SerializedUnitInput>? serialUnits,
  }) : qty = qty ?? Decimal.one,
       countedQty = countedQty ?? Decimal.zero,
       unitIds = unitIds ?? const [],
       serialUnits = serialUnits ?? const [];

  final Product? product;
  final Decimal qty;
  final Decimal? unitCost;
  final Decimal countedQty;
  final Decimal? systemQty;
  final List<String> unitIds;
  final List<SerializedUnitInput> serialUnits;

  Decimal? get deltaQty {
    if (systemQty == null) return null;
    return countedQty - systemQty!;
  }

  InventoryDocumentFormLineState copyWith({
    Product? product,
    Decimal? qty,
    Decimal? unitCost,
    Decimal? countedQty,
    Decimal? systemQty,
    List<String>? unitIds,
    List<SerializedUnitInput>? serialUnits,
    bool clearProduct = false,
    bool clearUnitCost = false,
    bool clearSystemQty = false,
  }) {
    return InventoryDocumentFormLineState(
      product: clearProduct ? null : (product ?? this.product),
      qty: qty ?? this.qty,
      unitCost: clearUnitCost ? null : (unitCost ?? this.unitCost),
      countedQty: countedQty ?? this.countedQty,
      systemQty: clearSystemQty ? null : (systemQty ?? this.systemQty),
      unitIds: unitIds ?? this.unitIds,
      serialUnits: serialUnits ?? this.serialUnits,
    );
  }
}

class InventoryDocumentFormState {
  InventoryDocumentFormState({
    required this.mode,
    this.warehouseId,
    required this.date,
    this.notes = '',
    this.reason,
    this.gainReason,
    this.lossReason,
    List<InventoryDocumentFormLineState>? lines,
    this.warehouses = const [],
    this.reasons = const [],
    this.gainReasons = const [],
    this.lossReasons = const [],
    this.availableUnits = const [],
    this.isLoadingMeta = false,
    this.isSubmitting = false,
    this.errorCode,
    this.validationCodes = const [],
    this.isSearchingProducts = false,
    this.productSearchResults = const [],
  }) : lines = lines ?? [InventoryDocumentFormLineState()];

  final InventoryDocumentFormMode mode;
  final String? warehouseId;
  final DateTime date;
  final String notes;
  final InventoryAdjustmentReason? reason;
  final InventoryAdjustmentReason? gainReason;
  final InventoryAdjustmentReason? lossReason;
  final List<InventoryDocumentFormLineState> lines;
  final List<Warehouse> warehouses;
  final List<InventoryAdjustmentReason> reasons;
  final List<InventoryAdjustmentReason> gainReasons;
  final List<InventoryAdjustmentReason> lossReasons;
  final List<ProductUnit> availableUnits;
  final bool isLoadingMeta;
  final bool isSubmitting;
  final String? errorCode;
  final List<String> validationCodes;
  final bool isSearchingProducts;
  final List<Product> productSearchResults;

  bool get hasValidationErrors => validationCodes.isNotEmpty;

  InventoryDocumentFormState copyWith({
    String? warehouseId,
    DateTime? date,
    String? notes,
    InventoryAdjustmentReason? reason,
    InventoryAdjustmentReason? gainReason,
    InventoryAdjustmentReason? lossReason,
    List<InventoryDocumentFormLineState>? lines,
    List<Warehouse>? warehouses,
    List<InventoryAdjustmentReason>? reasons,
    List<InventoryAdjustmentReason>? gainReasons,
    List<InventoryAdjustmentReason>? lossReasons,
    List<ProductUnit>? availableUnits,
    bool? isLoadingMeta,
    bool? isSubmitting,
    String? errorCode,
    List<String>? validationCodes,
    bool? isSearchingProducts,
    List<Product>? productSearchResults,
    bool clearWarehouse = false,
    bool clearReason = false,
    bool clearGainReason = false,
    bool clearLossReason = false,
    bool clearError = false,
    bool clearValidation = false,
    bool clearAvailableUnits = false,
  }) {
    return InventoryDocumentFormState(
      mode: mode,
      warehouseId: clearWarehouse ? null : (warehouseId ?? this.warehouseId),
      date: date ?? this.date,
      notes: notes ?? this.notes,
      reason: clearReason ? null : (reason ?? this.reason),
      gainReason: clearGainReason ? null : (gainReason ?? this.gainReason),
      lossReason: clearLossReason ? null : (lossReason ?? this.lossReason),
      lines: lines ?? this.lines,
      warehouses: warehouses ?? this.warehouses,
      reasons: reasons ?? this.reasons,
      gainReasons: gainReasons ?? this.gainReasons,
      lossReasons: lossReasons ?? this.lossReasons,
      availableUnits: clearAvailableUnits
          ? const []
          : (availableUnits ?? this.availableUnits),
      isLoadingMeta: isLoadingMeta ?? this.isLoadingMeta,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      validationCodes: clearValidation
          ? const []
          : (validationCodes ?? this.validationCodes),
      isSearchingProducts: isSearchingProducts ?? this.isSearchingProducts,
      productSearchResults: productSearchResults ?? this.productSearchResults,
    );
  }
}

DateTime defaultInventoryFormDate() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day);
}
