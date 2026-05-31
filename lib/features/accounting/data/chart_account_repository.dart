import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/accounting_exception.dart';
import '../../../core/network/supabase_providers.dart';
import '../../../domain/validators/chart_account_validator.dart';
import '../../auth/domain/app_session.dart';
import '../domain/account_type.dart';
import '../domain/chart_account.dart';
import '../domain/chart_account_form_state.dart';
import '../domain/chart_account_tree.dart';

part 'chart_account_repository.g.dart';

@Riverpod(keepAlive: true)
ChartAccountRepository chartAccountRepository(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return ChartAccountRepository(client);
}

class ChartAccountRepository {
  ChartAccountRepository(this._client);

  final SupabaseClient? _client;
  final ChartAccountValidator _validator = const ChartAccountValidator();

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) throw AccountingException.notConfigured();
    return client;
  }

  bool _canView(AppSession session) =>
      session.isManager || session.permissions.can('chart_of_accounts.view');

  void _assertCanView(AppSession session) {
    if (!_canView(session)) {
      throw const AccountingException(code: AccountingException.permissionDenied);
    }
  }

  void _assertCanMutateAndView(
    AppSession session, {
    required String actionPerm,
  }) {
    if (!session.isManager && !session.permissions.can(actionPerm)) {
      throw const AccountingException(code: AccountingException.permissionDenied);
    }
    _assertCanView(session);
  }

  Future<List<ChartAccount>> fetchChartAccounts(
    AppSession session, {
    AccountType? type,
    bool? isActive,
  }) async {
    _assertCanView(session);
    try {
      var query =
          _requireClient.from('chart_of_accounts').select(ChartAccountColumns.list);

      if (type != null) {
        query = query.eq('type', type.toDb());
      }
      if (isActive != null) {
        query = query.eq('is_active', isActive);
      }

      final rows = await query.order('code');
      return (rows as List)
          .map((r) => ChartAccount.fromRow(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e, st) {
      throw AccountingException.fromSupabase(e, st);
    }
  }

  Future<ChartAccount?> fetchChartAccountById(
    AppSession session,
    String id,
  ) async {
    _assertCanView(session);
    try {
      final row = await _requireClient
          .from('chart_of_accounts')
          .select(ChartAccountColumns.list)
          .eq('id', id)
          .maybeSingle();

      if (row == null) return null;
      return ChartAccount.fromRow(Map<String, dynamic>.from(row));
    } catch (e, st) {
      throw AccountingException.fromSupabase(e, st);
    }
  }

  Future<List<ChartAccountTreeNode>> fetchChartAccountTree(
    AppSession session, {
    AccountType? type,
    bool? isActive,
  }) async {
    final accounts = await fetchChartAccounts(
      session,
      type: type,
      isActive: isActive,
    );
    return buildChartAccountTree(accounts);
  }

  Future<ChartAccount> createChartAccount(
    AppSession session,
    ChartAccountFormState input,
  ) async {
    _assertCanMutateAndView(session, actionPerm: 'chart_of_accounts.create');

    AccountType? parentType;
    if (input.parentId != null) {
      final parent = await fetchChartAccountById(session, input.parentId!);
      if (parent == null) {
        throw const AccountingException(
          code: AccountingException.parentTypeMismatch,
        );
      }
      parentType = parent.type;
    }

    final validation = _validator.validateCreate(input, parentType: parentType);
    if (!validation.isValid) {
      throw AccountingException(code: validation.codes.first);
    }

    try {
      final id = await _requireClient.rpc(
        'create_chart_account',
        params: {'p_data': input.toCreatePayload()},
      );
      final created = await fetchChartAccountById(session, id as String);
      if (created == null) {
        throw const AccountingException(
          code: AccountingException.validationFailed,
        );
      }
      return created;
    } catch (e, st) {
      throw AccountingException.fromSupabase(e, st);
    }
  }

  Future<ChartAccount> updateChartAccount(
    AppSession session,
    String id,
    ChartAccountFormState input,
  ) async {
    _assertCanMutateAndView(session, actionPerm: 'chart_of_accounts.edit');

    // 2. Load current account.
    final current = await fetchChartAccountById(session, id);
    if (current == null) {
      throw const AccountingException(code: AccountingException.validationFailed);
    }

    // 3. Parent type guard when type changes.
    AccountType? parentType;
    if (input.type != current.type && current.parentId != null) {
      final parent = await fetchChartAccountById(session, current.parentId!);
      if (parent == null) {
        throw const AccountingException(
          code: AccountingException.parentTypeMismatch,
        );
      }
      parentType = parent.type;
    }

    final validation = _validator.validateUpdate(
      input,
      currentType: current.type,
      currentParentId: current.parentId,
      parentType: parentType,
    );
    if (!validation.isValid) {
      throw AccountingException(code: validation.codes.first);
    }

    // 4. RPC + re-fetch.
    try {
      await _requireClient.rpc(
        'update_chart_account',
        params: {
          'p_id': id,
          'p_data': input.toUpdatePayload(),
        },
      );
      final updated = await fetchChartAccountById(session, id);
      if (updated == null) {
        throw const AccountingException(
          code: AccountingException.validationFailed,
        );
      }
      return updated;
    } catch (e, st) {
      throw AccountingException.fromSupabase(e, st);
    }
  }

  Future<ChartAccount> deactivateChartAccount(
    AppSession session,
    String id,
  ) async {
    _assertCanMutateAndView(session, actionPerm: 'chart_of_accounts.delete');

    try {
      await _requireClient.rpc(
        'deactivate_chart_account',
        params: {'p_id': id},
      );
      final deactivated = await fetchChartAccountById(session, id);
      if (deactivated == null) {
        throw const AccountingException(
          code: AccountingException.validationFailed,
        );
      }
      return deactivated;
    } catch (e, st) {
      throw AccountingException.fromSupabase(e, st);
    }
  }
}
