import 'package:hs360/core/errors/inventory_exception.dart';
import 'package:hs360/features/inventory/data/inventory_repository.dart';
import 'package:hs360/features/inventory/domain/inventory_balance.dart';
import 'package:hs360/features/inventory/domain/inventory_movement.dart';
import 'package:hs360/features/inventory/domain/movement_type.dart';

class FakeInventoryRepository extends InventoryRepository {
  FakeInventoryRepository({
    this.balances = const [],
    this.balancesError,
    this.movements = const [],
    this.movementsError,
  }) : super(null);

  List<InventoryBalance> balances;
  final Object? balancesError;
  List<InventoryMovement> movements;
  final Object? movementsError;

  int fetchBalancesCount = 0;
  int fetchMovementsCount = 0;

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
}
