import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/customer_exception.dart';
import '../../../core/network/supabase_providers.dart';
import '../../../domain/validators/customer_validator.dart';
import '../../auth/domain/app_session.dart';
import '../domain/customer.dart';
import '../domain/customer_balance_summary.dart';
import '../domain/customer_filters.dart';
import '../domain/customer_form_state.dart';
import '../domain/customer_statement_row.dart';

part 'customer_repository.g.dart';

@Riverpod(keepAlive: true)
CustomerRepository customerRepository(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return CustomerRepository(client);
}

class CustomerRepository {
  CustomerRepository(this._client);

  final SupabaseClient? _client;
  final CustomerValidator _validator = const CustomerValidator();

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) throw CustomerException.notConfigured();
    return client;
  }

  bool _canView(AppSession session) =>
      session.isManager || session.permissions.can('customers.view');

  void _assertCanView(AppSession session) {
    if (!_canView(session)) {
      throw const CustomerException(code: CustomerException.permissionDenied);
    }
  }

  void _assertCanMutateAndView(
    AppSession session, {
    required String actionPerm,
  }) {
    if (!session.isManager && !session.permissions.can(actionPerm)) {
      throw const CustomerException(code: CustomerException.permissionDenied);
    }
    _assertCanView(session);
  }

  Future<List<Customer>> fetchCustomers(
    AppSession session,
    CustomerFilters filters, {
    int offset = 0,
    int limit = 100,
  }) async {
    _assertCanView(session);
    assert(offset >= 0);
    assert(limit > 0);
    try {
      var query = _requireClient.from('customers').select(CustomerColumns.list);

      final search = filters.search?.trim();
      if (search != null && search.isNotEmpty) {
        final pattern = '%$search%';
        query = query.or(
          'code.ilike.$pattern,name_ar.ilike.$pattern,'
          'name_en.ilike.$pattern,phone_primary.ilike.$pattern,'
          'email.ilike.$pattern',
        );
      }
      if (filters.isActive != null) {
        query = query.eq('is_active', filters.isActive!);
      }
      if (filters.isVip != null) {
        query = query.eq('is_vip', filters.isVip!);
      }
      if (filters.customerType != null) {
        query = query.eq('customer_type', filters.customerType!.toDb());
      }
      if (filters.area?.trim().isNotEmpty == true) {
        query = query.eq('area', filters.area!.trim());
      }
      if (filters.governorate?.trim().isNotEmpty == true) {
        query = query.eq('governorate', filters.governorate!.trim());
      }

      final rows = await query.order('code').range(offset, offset + limit - 1);
      return (rows as List)
          .map((r) => Customer.fromRow(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e, st) {
      throw CustomerException.fromSupabase(e, st);
    }
  }

  Future<Customer?> fetchCustomerById(AppSession session, String id) async {
    _assertCanView(session);
    try {
      final row = await _requireClient
          .from('customers')
          .select(CustomerColumns.list)
          .eq('id', id)
          .maybeSingle();

      if (row == null) return null;
      return Customer.fromRow(Map<String, dynamic>.from(row));
    } catch (e, st) {
      throw CustomerException.fromSupabase(e, st);
    }
  }

  Future<Customer> createCustomer(
    AppSession session,
    CustomerFormState input,
  ) async {
    _assertCanMutateAndView(session, actionPerm: 'customers.create');
    final validation = _validator.validate(input);
    if (!validation.isValid) {
      throw CustomerException(code: validation.codes.first);
    }

    try {
      final id = await _requireClient.rpc(
        'create_customer',
        params: {'p_data': input.toCreatePayload()},
      );
      final created = await fetchCustomerById(session, id as String);
      if (created == null) {
        throw const CustomerException(code: CustomerException.validationFailed);
      }
      return created;
    } catch (e, st) {
      throw CustomerException.fromSupabase(e, st);
    }
  }

  Future<Customer> updateCustomer(
    AppSession session,
    String id,
    CustomerFormState input,
  ) async {
    _assertCanMutateAndView(session, actionPerm: 'customers.edit');
    final validation = _validator.validate(input);
    if (!validation.isValid) {
      throw CustomerException(code: validation.codes.first);
    }

    try {
      await _requireClient.rpc(
        'update_customer',
        params: {'p_id': id, 'p_data': input.toUpdatePayload()},
      );
      final updated = await fetchCustomerById(session, id);
      if (updated == null) {
        throw const CustomerException(code: CustomerException.validationFailed);
      }
      return updated;
    } catch (e, st) {
      throw CustomerException.fromSupabase(e, st);
    }
  }

  Future<Customer> ensureCustomerAccount(AppSession session, String id) async {
    _assertCanMutateAndView(session, actionPerm: 'customers.edit');

    try {
      await _requireClient.rpc('ensure_customer_account', params: {'p_id': id});
      final updated = await fetchCustomerById(session, id);
      if (updated == null) {
        throw const CustomerException(code: CustomerException.validationFailed);
      }
      return updated;
    } catch (e, st) {
      throw CustomerException.fromSupabase(e, st);
    }
  }

  Future<Customer> deactivateCustomer(AppSession session, String id) async {
    _assertCanMutateAndView(session, actionPerm: 'customers.delete');

    try {
      await _requireClient.rpc('deactivate_customer', params: {'p_id': id});
      final deactivated = await fetchCustomerById(session, id);
      if (deactivated == null) {
        throw const CustomerException(code: CustomerException.validationFailed);
      }
      return deactivated;
    } catch (e, st) {
      throw CustomerException.fromSupabase(e, st);
    }
  }

  Future<List<CustomerStatementRow>> fetchCustomerStatement(
    AppSession session,
    String customerId, {
    DateTime? from,
    DateTime? to,
    int offset = 0,
    int limit = 100,
  }) async {
    if (!session.isManager &&
        !session.permissions.can('customers.view_ledger')) {
      throw const CustomerException(code: CustomerException.permissionDenied);
    }
    assert(offset >= 0);
    assert(limit > 0);

    try {
      final rows = await _requireClient
          .rpc(
            'get_customer_statement',
            params: {
              'p_customer_id': customerId,
              'p_from': from != null ? _dateOnly(from) : null,
              'p_to': to != null ? _dateOnly(to) : null,
            },
          )
          .range(offset, offset + limit - 1);
      return (rows as List)
          .map(
            (r) => CustomerStatementRow.fromRow(
              Map<String, dynamic>.from(r as Map),
            ),
          )
          .toList();
    } catch (e, st) {
      throw CustomerException.fromSupabase(e, st);
    }
  }

  Future<CustomerBalanceSummary> fetchCustomerBalanceSummary(
    AppSession session,
    String customerId,
  ) async {
    if (!session.isManager &&
        !session.permissions.can('customers.view_ledger')) {
      throw const CustomerException(code: CustomerException.permissionDenied);
    }

    try {
      final rows = await _requireClient.rpc(
        'get_customer_balance_summary',
        params: {'p_customer_id': customerId},
      );
      final list = rows as List;
      if (list.isEmpty) return CustomerBalanceSummary.zero();
      return CustomerBalanceSummary.fromRow(
        Map<String, dynamic>.from(list.first as Map),
      );
    } catch (e, st) {
      throw CustomerException.fromSupabase(e, st);
    }
  }

  String _dateOnly(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
