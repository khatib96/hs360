import 'package:decimal/decimal.dart';
import 'package:hs360/core/errors/inventory_exception.dart';
import 'package:hs360/domain/validators/inventory_adjustment_validator.dart';
import 'package:hs360/domain/validators/inventory_transfer_validator.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/inventory/data/inventory_repository.dart';
import 'package:hs360/features/inventory/domain/inventory_adjustment_form_state.dart';
import 'package:hs360/features/inventory/domain/inventory_transfer_form_state.dart';
import 'package:hs360/features/inventory/domain/inventory_balance.dart';
import 'package:hs360/features/inventory/domain/inventory_movement.dart';
import 'package:hs360/features/inventory/domain/movement_type.dart';
import 'package:hs360/features/inventory/domain/inventory_permissions.dart';
import 'package:hs360/features/inventory/domain/transfer_product_option.dart';
import 'package:hs360/features/inventory/domain/transfer_warehouse_option.dart';
import 'package:hs360/features/products/domain/product_cost_access.dart';

class FakeInventoryRepository extends InventoryRepository {
  FakeInventoryRepository({
    this.balances = const [],
    this.balancesError,
    this.movements = const [],
    this.movementsError,
    this.adjustmentResult = 'movement-id',
    this.adjustmentError,
    this.transferWarehouses = const [],
    this.transferProducts = const [],
    this.transferSourceQty,
    this.transferResult = 'transfer-id',
    this.transferError,
  }) : super(null);

  List<InventoryBalance> balances;
  final Object? balancesError;
  List<InventoryMovement> movements;
  final Object? movementsError;

  final String adjustmentResult;
  final Object? adjustmentError;

  final List<TransferWarehouseOption> transferWarehouses;
  final List<TransferProductOption> transferProducts;
  final Decimal? transferSourceQty;
  final String transferResult;
  final Object? transferError;

  int fetchBalancesCount = 0;
  int fetchMovementsCount = 0;
  int adjustmentCallCount = 0;
  int transferCallCount = 0;
  int listTransferWarehousesCallCount = 0;
  int searchTransferProductsCallCount = 0;
  int getTransferSourceQtyCallCount = 0;
  AppSession? lastAdjustmentSession;
  InventoryAdjustmentFormState? lastAdjustmentInput;
  AppSession? lastTransferSession;
  InventoryTransferFormState? lastTransferInput;

  String? lastWarehouseId;
  MovementType? lastMovementType;
  DateTime? lastOccurredFrom;
  DateTime? lastOccurredBefore;
  Set<String>? lastProductIds;
  int? lastLimit;

  @override
  Future<List<InventoryBalance>> fetchInventoryBalances({
    String? productId,
    String? warehouseId,
  }) async {
    fetchBalancesCount++;
    final error = balancesError;
    if (error != null) {
      if (error is InventoryException) throw error;
      throw const InventoryException(code: InventoryException.unknown);
    }
    var result = List<InventoryBalance>.from(balances);
    if (productId != null) {
      result = result.where((b) => b.productId == productId).toList();
    }
    if (warehouseId != null) {
      result = result.where((b) => b.warehouseId == warehouseId).toList();
    }
    return result;
  }

  @override
  Future<List<InventoryMovement>> fetchInventoryMovements({
    String? warehouseId,
    MovementType? movementType,
    DateTime? occurredFrom,
    DateTime? occurredBefore,
    Set<String>? productIds,
    int limit = 100,
  }) async {
    fetchMovementsCount++;
    lastWarehouseId = warehouseId;
    lastMovementType = movementType;
    lastOccurredFrom = occurredFrom;
    lastOccurredBefore = occurredBefore;
    lastProductIds = productIds;
    lastLimit = limit;

    final error = movementsError;
    if (error != null) {
      if (error is InventoryException) throw error;
      throw const InventoryException(code: InventoryException.unknown);
    }

    var result = List<InventoryMovement>.from(movements);
    if (warehouseId != null) {
      result = result.where((m) => m.warehouseId == warehouseId).toList();
    }
    if (movementType != null) {
      result = result.where((m) => m.movementType == movementType).toList();
    }
    if (productIds != null && productIds.isNotEmpty) {
      result = result.where((m) => productIds.contains(m.productId)).toList();
    }
    if (occurredFrom != null) {
      result = result.where((m) => !m.occurredAt.isBefore(occurredFrom)).toList();
    }
    if (occurredBefore != null) {
      result = result.where((m) => m.occurredAt.isBefore(occurredBefore)).toList();
    }
    if (result.length > limit) {
      result = result.take(limit).toList();
    }
    return result;
  }

  @override
  Future<String> recordInventoryAdjustment(
    AppSession session,
    InventoryAdjustmentFormState input,
  ) async {
    if (!canCreateInventoryMovements(session)) {
      throw const InventoryException(code: InventoryException.permissionDenied);
    }
    if (input.movementType == MovementType.adjustmentIn &&
        !canWriteProductCosts(session)) {
      throw const InventoryException(code: InventoryException.permissionDenied);
    }

    const validator = InventoryAdjustmentValidator();
    final validation = validator.validate(input);
    if (!validation.isValid) {
      throw InventoryException(code: validation.codes.first);
    }

    adjustmentCallCount++;
    lastAdjustmentSession = session;
    lastAdjustmentInput = input;

    final error = adjustmentError;
    if (error != null) {
      if (error is InventoryException) throw error;
      throw const InventoryException(code: InventoryException.unknown);
    }

    return adjustmentResult;
  }

  @override
  Future<List<TransferWarehouseOption>> listTransferWarehouses(
    AppSession session,
  ) async {
    if (!canCreateInventoryMovements(session)) {
      throw const InventoryException(code: InventoryException.permissionDenied);
    }
    listTransferWarehousesCallCount++;
    return transferWarehouses;
  }

  @override
  Future<List<TransferProductOption>> searchTransferProducts(
    AppSession session,
    String query, {
    int limit = 20,
  }) async {
    if (!canCreateInventoryMovements(session)) {
      throw const InventoryException(code: InventoryException.permissionDenied);
    }
    searchTransferProductsCallCount++;
    return transferProducts;
  }

  @override
  Future<Decimal> getTransferSourceQty(
    AppSession session, {
    required String warehouseId,
    required String productId,
  }) async {
    if (!canCreateInventoryMovements(session)) {
      throw const InventoryException(code: InventoryException.permissionDenied);
    }
    getTransferSourceQtyCallCount++;
    return transferSourceQty ?? Decimal.zero;
  }

  @override
  Future<String> recordInventoryTransfer(
    AppSession session,
    InventoryTransferFormState input,
  ) async {
    if (!canCreateInventoryMovements(session)) {
      throw const InventoryException(code: InventoryException.permissionDenied);
    }

    const validator = InventoryTransferValidator();
    final validation = validator.validate(input);
    if (!validation.isValid) {
      throw InventoryException(code: validation.codes.first);
    }

    transferCallCount++;
    lastTransferSession = session;
    lastTransferInput = input;

    final error = transferError;
    if (error != null) {
      if (error is InventoryException) throw error;
      throw const InventoryException(code: InventoryException.unknown);
    }

    return transferResult;
  }
}
