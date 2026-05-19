import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/products_exception.dart';
import '../../../core/network/supabase_providers.dart';
import '../../auth/domain/app_session.dart';
import '../domain/product_group.dart';

part 'product_group_repository.g.dart';

const _groupColumns =
    'id, tenant_id, name_ar, name_en, parent_id, sort_order, is_active, created_at';

@Riverpod(keepAlive: true)
ProductGroupRepository productGroupRepository(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return ProductGroupRepository(client);
}

class ProductGroupRepository {
  ProductGroupRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) throw ProductsException.notConfigured();
    return client;
  }

  Future<List<ProductGroup>> fetchProductGroups({bool activeOnly = false}) async {
    try {
      var query = _requireClient.from('product_groups').select(_groupColumns);
      if (activeOnly) {
        query = query.eq('is_active', true);
      }
      final rows = await query.order('sort_order');
      return (rows as List)
          .map((r) => ProductGroup.fromRow(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e, st) {
      throw ProductsException.fromSupabase(e, st);
    }
  }

  Future<ProductGroup?> fetchProductGroupById(String id) async {
    try {
      final row = await _requireClient
          .from('product_groups')
          .select(_groupColumns)
          .eq('id', id)
          .maybeSingle();
      if (row == null) return null;
      return ProductGroup.fromRow(Map<String, dynamic>.from(row));
    } catch (e, st) {
      throw ProductsException.fromSupabase(e, st);
    }
  }

  Future<ProductGroup> createProductGroup(
    AppSession session,
    ProductGroupFormState input,
  ) async {
    try {
      final row = await _requireClient
          .from('product_groups')
          .insert(_toMap(session, input))
          .select(_groupColumns)
          .single();
      return ProductGroup.fromRow(Map<String, dynamic>.from(row));
    } catch (e, st) {
      throw ProductsException.fromSupabase(e, st);
    }
  }

  Future<ProductGroup> updateProductGroup(
    AppSession session,
    String id,
    ProductGroupFormState input,
  ) async {
    try {
      final row = await _requireClient
          .from('product_groups')
          .update(_toMap(session, input, includeTenant: false))
          .eq('id', id)
          .select(_groupColumns)
          .single();
      return ProductGroup.fromRow(Map<String, dynamic>.from(row));
    } catch (e, st) {
      throw ProductsException.fromSupabase(e, st);
    }
  }

  Future<void> deactivateProductGroup(AppSession session, String id) async {
    try {
      await _requireClient
          .from('product_groups')
          .update({'is_active': false})
          .eq('id', id);
    } catch (e, st) {
      throw ProductsException.fromSupabase(e, st);
    }
  }

  Map<String, dynamic> _toMap(
    AppSession session,
    ProductGroupFormState input, {
    bool includeTenant = true,
  }) {
    return {
      if (includeTenant) 'tenant_id': session.tenantId,
      'name_ar': input.nameAr.trim(),
      'name_en': input.nameEn.trim(),
      'parent_id': input.parentId,
      'sort_order': input.sortOrder,
      'is_active': input.isActive,
    };
  }
}
