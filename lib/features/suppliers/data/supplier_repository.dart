import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/supplier_exception.dart';
import '../../../core/network/supabase_providers.dart';
import '../../../domain/validators/supplier_validator.dart';
import '../../auth/domain/app_session.dart';
import '../domain/supplier.dart';
import '../domain/supplier_filters.dart';
import '../domain/supplier_form_state.dart';

part 'supplier_repository.g.dart';

@Riverpod(keepAlive: true)
SupplierRepository supplierRepository(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return SupplierRepository(client);
}

class SupplierRepository {
  SupplierRepository(this._client);

  final SupabaseClient? _client;
  final SupplierValidator _validator = const SupplierValidator();

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) throw SupplierException.notConfigured();
    return client;
  }

  bool _canView(AppSession session) =>
      session.isManager || session.permissions.can('suppliers.view');

  void _assertCanView(AppSession session) {
    if (!_canView(session)) {
      throw const SupplierException(code: SupplierException.permissionDenied);
    }
  }

  void _assertCanMutateAndView(
    AppSession session, {
    required String actionPerm,
  }) {
    if (!session.isManager && !session.permissions.can(actionPerm)) {
      throw const SupplierException(code: SupplierException.permissionDenied);
    }
    _assertCanView(session);
  }

  Future<List<Supplier>> fetchSuppliers(
    AppSession session,
    SupplierFilters filters, {
    int offset = 0,
    int limit = 100,
  }) async {
    _assertCanView(session);
    assert(offset >= 0);
    assert(limit > 0);
    try {
      var query = _requireClient.from('suppliers').select(SupplierColumns.list);

      final search = filters.search?.trim();
      if (search != null && search.isNotEmpty) {
        final pattern = '%$search%';
        query = query.or(
          'code.ilike.$pattern,name_ar.ilike.$pattern,'
          'name_en.ilike.$pattern,phone.ilike.$pattern,email.ilike.$pattern',
        );
      }
      if (filters.isActive != null) {
        query = query.eq('is_active', filters.isActive!);
      }

      final rows = await query.order('code').range(offset, offset + limit - 1);
      return (rows as List)
          .map((r) => Supplier.fromRow(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e, st) {
      throw SupplierException.fromSupabase(e, st);
    }
  }

  Future<Supplier?> fetchSupplierById(AppSession session, String id) async {
    _assertCanView(session);
    try {
      final row = await _requireClient
          .from('suppliers')
          .select(SupplierColumns.list)
          .eq('id', id)
          .maybeSingle();

      if (row == null) return null;
      return Supplier.fromRow(Map<String, dynamic>.from(row));
    } catch (e, st) {
      throw SupplierException.fromSupabase(e, st);
    }
  }

  Future<Supplier> createSupplier(
    AppSession session,
    SupplierFormState input,
  ) async {
    _assertCanMutateAndView(session, actionPerm: 'suppliers.create');
    final validation = _validator.validate(input);
    if (!validation.isValid) {
      throw SupplierException(code: validation.codes.first);
    }

    try {
      final id = await _requireClient.rpc(
        'create_supplier',
        params: {'p_data': input.toCreatePayload()},
      );
      final created = await fetchSupplierById(session, id as String);
      if (created == null) {
        throw const SupplierException(code: SupplierException.validationFailed);
      }
      return created;
    } catch (e, st) {
      throw SupplierException.fromSupabase(e, st);
    }
  }

  Future<Supplier> updateSupplier(
    AppSession session,
    String id,
    SupplierFormState input,
  ) async {
    _assertCanMutateAndView(session, actionPerm: 'suppliers.edit');
    final validation = _validator.validate(input);
    if (!validation.isValid) {
      throw SupplierException(code: validation.codes.first);
    }

    try {
      await _requireClient.rpc(
        'update_supplier',
        params: {'p_id': id, 'p_data': input.toUpdatePayload()},
      );
      final updated = await fetchSupplierById(session, id);
      if (updated == null) {
        throw const SupplierException(code: SupplierException.validationFailed);
      }
      return updated;
    } catch (e, st) {
      throw SupplierException.fromSupabase(e, st);
    }
  }

  Future<Supplier> ensureSupplierAccount(AppSession session, String id) async {
    _assertCanMutateAndView(session, actionPerm: 'suppliers.edit');

    try {
      await _requireClient.rpc('ensure_supplier_account', params: {'p_id': id});
      final updated = await fetchSupplierById(session, id);
      if (updated == null) {
        throw const SupplierException(code: SupplierException.validationFailed);
      }
      return updated;
    } catch (e, st) {
      throw SupplierException.fromSupabase(e, st);
    }
  }

  Future<Supplier> deactivateSupplier(AppSession session, String id) async {
    _assertCanMutateAndView(session, actionPerm: 'suppliers.delete');

    try {
      await _requireClient.rpc('deactivate_supplier', params: {'p_id': id});
      final deactivated = await fetchSupplierById(session, id);
      if (deactivated == null) {
        throw const SupplierException(code: SupplierException.validationFailed);
      }
      return deactivated;
    } catch (e, st) {
      throw SupplierException.fromSupabase(e, st);
    }
  }
}
