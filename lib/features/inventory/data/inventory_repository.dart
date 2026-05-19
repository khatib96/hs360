import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/inventory_exception.dart';
import '../../../core/network/supabase_providers.dart';
import '../../../domain/validators/inventory_adjustment_validator.dart';
import '../domain/inventory_adjustment_form_state.dart';
import '../domain/inventory_balance.dart';
import '../domain/inventory_movement.dart';

part 'inventory_repository.g.dart';

const _balanceColumns =
    'id, tenant_id, warehouse_id, product_id, qty_available, qty_rented, '
    'qty_trial, qty_maintenance, qty_damaged, updated_at';

const _movementColumns =
    'id, tenant_id, movement_type, warehouse_id, product_id, product_unit_id, '
    'qty, unit_cost, reference_table, reference_id, notes, occurred_at, '
    'created_at, created_by';

const _defaultMovementLimit = 100;

@Riverpod(keepAlive: true)
InventoryRepository inventoryRepository(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return InventoryRepository(client);
}

class InventoryRepository {
  InventoryRepository(this._client);

  final SupabaseClient? _client;
  final InventoryAdjustmentValidator _validator =
      const InventoryAdjustmentValidator();

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) {
      throw const InventoryException(code: InventoryException.unknown);
    }
    return client;
  }

  Future<List<InventoryBalance>> fetchInventoryBalances({
    String? productId,
    String? warehouseId,
  }) async {
    try {
      var query = _requireClient.from('inventory_balances').select(_balanceColumns);
      if (productId != null) {
        query = query.eq('product_id', productId);
      }
      if (warehouseId != null) {
        query = query.eq('warehouse_id', warehouseId);
      }
      final rows = await query;
      return (rows as List)
          .map((r) => InventoryBalance.fromRow(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e, st) {
      throw InventoryException.fromSupabase(e, st);
    }
  }

  Future<List<InventoryMovement>> fetchInventoryMovements({
    String? productId,
    String? warehouseId,
    int limit = _defaultMovementLimit,
  }) async {
    try {
      var query = _requireClient
          .from('inventory_movements')
          .select(_movementColumns);
      if (productId != null) {
        query = query.eq('product_id', productId);
      }
      if (warehouseId != null) {
        query = query.eq('warehouse_id', warehouseId);
      }
      final rows = await query
          .order('occurred_at', ascending: false)
          .limit(limit);
      return (rows as List)
          .map((r) => InventoryMovement.fromRow(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e, st) {
      throw InventoryException.fromSupabase(e, st);
    }
  }

  Future<String> recordInventoryAdjustment(
    InventoryAdjustmentFormState input,
  ) async {
    final validation = _validator.validate(input);
    if (!validation.isValid) {
      throw InventoryException(code: validation.codes.first);
    }

    try {
      final response = await _requireClient.rpc(
        'record_inventory_adjustment',
        params: {
          'p_warehouse_id': input.warehouseId,
          'p_product_id': input.productId,
          'p_qty': input.qty.toString(),
          'p_movement_type': input.movementType.toDb(),
          'p_unit_cost': input.unitCost?.toString(),
          'p_notes': input.notes.trim(),
        },
      );
      return response as String;
    } catch (e, st) {
      throw InventoryException.fromSupabase(e, st);
    }
  }
}
