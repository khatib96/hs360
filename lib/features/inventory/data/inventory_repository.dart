import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/inventory_exception.dart';
import '../../../core/network/supabase_providers.dart';
import '../../../domain/validators/inventory_adjustment_validator.dart';
import '../../auth/domain/app_session.dart';
import '../../products/domain/product_cost_access.dart';
import '../domain/inventory_adjustment_form_state.dart';
import '../domain/inventory_permissions.dart';
import '../domain/inventory_balance.dart';
import '../domain/inventory_movement.dart';
import '../domain/movement_type.dart';

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
    String? warehouseId,
    MovementType? movementType,
    DateTime? occurredFrom,
    DateTime? occurredBefore,
    Set<String>? productIds,
    int limit = _defaultMovementLimit,
  }) async {
    try {
      var query = _requireClient
          .from('inventory_movements')
          .select(_movementColumns);
      if (warehouseId != null) {
        query = query.eq('warehouse_id', warehouseId);
      }
      if (movementType != null) {
        query = query.eq('movement_type', movementType.toDb());
      }
      if (occurredFrom != null) {
        query = query.gte(
          'occurred_at',
          occurredFrom.toUtc().toIso8601String(),
        );
      }
      if (occurredBefore != null) {
        query = query.lt(
          'occurred_at',
          occurredBefore.toUtc().toIso8601String(),
        );
      }
      if (productIds != null && productIds.isNotEmpty) {
        query = query.inFilter('product_id', productIds.toList());
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
