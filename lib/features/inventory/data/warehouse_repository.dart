import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/products_exception.dart';
import '../../../core/network/supabase_providers.dart';
import '../domain/warehouse.dart';

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

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) throw ProductsException.notConfigured();
    return client;
  }

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
}
