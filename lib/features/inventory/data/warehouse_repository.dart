import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/products_exception.dart';
import '../../../core/network/supabase_providers.dart';
import '../../../domain/validators/warehouse_validator.dart';
import '../../auth/domain/app_session.dart';
import '../domain/warehouse.dart';
import '../domain/warehouse_assignable_employee.dart';
import '../domain/warehouse_form_state.dart';
import '../domain/warehouse_type.dart';

part 'warehouse_repository.g.dart';

const _warehouseColumns =
    'id, tenant_id, name_ar, name_en, type, agent_id, location_address, is_active, created_at';

@Riverpod(keepAlive: true)
WarehouseRepository warehouseRepository(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return WarehouseRepository(client);
}

class WarehouseRepository {
  WarehouseRepository(this._client);

  final SupabaseClient? _client;
  final WarehouseValidator _validator = const WarehouseValidator();

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) throw ProductsException.notConfigured();
    return client;
  }

  /// Loads warehouses. Pass [activeOnly: true] for movement/adjustment/transfer
  /// pickers (M7B+) — inactive warehouses must not appear as choices.
  Future<List<Warehouse>> fetchWarehouses({bool activeOnly = false}) async {
    try {
      var query = _requireClient.from('warehouses').select(_warehouseColumns);
      if (activeOnly) {
        query = query.eq('is_active', true);
      }
      final rows = await query.order('name_en');
      return (rows as List)
          .map((r) => Warehouse.fromRow(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e, st) {
      throw ProductsException.fromSupabase(e, st);
    }
  }

  Future<List<WarehouseAssignableEmployee>> fetchAssignableEmployees() async {
    try {
      final rows = await _requireClient.rpc('list_warehouse_assignable_employees');
      return (rows as List)
          .map(
            (r) => WarehouseAssignableEmployee.fromRow(
              Map<String, dynamic>.from(r),
            ),
          )
          .toList();
    } catch (e, st) {
      throw ProductsException.fromSupabase(e, st);
    }
  }

  Future<Warehouse> createWarehouse(
    AppSession session,
    WarehouseFormState input, {
    List<Warehouse> existingWarehouses = const [],
  }) async {
    final normalized = _normalizedInput(input);
    final validation = _validator.validate(
      normalized,
      existingWarehouses: existingWarehouses,
    );
    if (!validation.isValid) {
      throw ProductsException(code: validation.codes.first);
    }

    try {
      final row = await _requireClient
          .from('warehouses')
          .insert(_toMap(session, normalized))
          .select(_warehouseColumns)
          .single();
      return Warehouse.fromRow(Map<String, dynamic>.from(row));
    } catch (e, st) {
      throw ProductsException.fromSupabase(e, st);
    }
  }

  Future<Warehouse> updateWarehouse(
    AppSession session,
    String id,
    WarehouseFormState input, {
    List<Warehouse> existingWarehouses = const [],
  }) async {
    final normalized = _normalizedInput(input);
    final validation = _validator.validate(
      normalized,
      existingWarehouses: existingWarehouses,
      excludeWarehouseId: id,
    );
    if (!validation.isValid) {
      throw ProductsException(code: validation.codes.first);
    }

    try {
      final row = await _requireClient
          .from('warehouses')
          .update(_toMap(session, normalized, includeTenant: false))
          .eq('id', id)
          .select(_warehouseColumns)
          .single();
      return Warehouse.fromRow(Map<String, dynamic>.from(row));
    } catch (e, st) {
      throw ProductsException.fromSupabase(e, st);
    }
  }

  Future<void> deactivateWarehouse(AppSession session, String id) async {
    try {
      await _requireClient
          .from('warehouses')
          .update({'is_active': false})
          .eq('id', id);
    } catch (e, st) {
      throw ProductsException.fromSupabase(e, st);
    }
  }

  WarehouseFormState _normalizedInput(WarehouseFormState input) {
    if (input.type == WarehouseType.van) return input;
    return WarehouseFormState(
      nameAr: input.nameAr,
      nameEn: input.nameEn,
      type: input.type,
      agentId: null,
      locationAddress: input.locationAddress,
      isActive: input.isActive,
    );
  }

  Map<String, dynamic> _toMap(
    AppSession session,
    WarehouseFormState input, {
    bool includeTenant = true,
  }) {
    final isVan = input.type == WarehouseType.van;
    return {
      if (includeTenant) 'tenant_id': session.tenantId,
      'name_ar': input.nameAr.trim(),
      'name_en': input.nameEn.trim(),
      'type': input.type.toDb(),
      'agent_id': isVan ? input.agentId?.trim() : null,
      'location_address': _trimOrNull(input.locationAddress),
      'is_active': input.isActive,
    };
  }

  String? _trimOrNull(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }
}
