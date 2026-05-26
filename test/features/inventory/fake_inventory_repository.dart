import 'package:hs360/core/errors/inventory_exception.dart';
import 'package:hs360/features/inventory/data/inventory_repository.dart';
import 'package:hs360/features/inventory/domain/inventory_balance.dart';
import 'package:hs360/features/inventory/domain/inventory_movement.dart';

class FakeInventoryRepository extends InventoryRepository {
  FakeInventoryRepository({
    this.balances = const [],
    this.balancesError,
  }) : super(null);

  List<InventoryBalance> balances;
  final Object? balancesError;
  int fetchBalancesCount = 0;
  int fetchMovementsCount = 0;

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
    String? productId,
    String? warehouseId,
    int limit = 100,
  }) async {
    fetchMovementsCount++;
    return const [];
  }
}
