import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/finance_exception.dart';
import '../../../core/network/supabase_providers.dart';
import '../../auth/domain/app_session.dart';
import '../../finance_shared/domain/date_range.dart';
import '../../finance_shared/domain/finance_permissions.dart';
import '../../finance_shared/domain/pagination_cursor.dart';
import '../domain/cash_bank_activity_row.dart';
import 'cash_bank_rpc_mapper.dart';

part 'cash_bank_repository.g.dart';

@Riverpod(keepAlive: true)
CashBankRepository cashBankRepository(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return CashBankRepository(client);
}

class CashBankRepository {
  CashBankRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) throw FinanceException.notConfigured();
    return client;
  }

  void _assertCanView(AppSession session) {
    if (!canViewCashBank(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
  }

  Future<CashBankActivityPage> getCashBankActivity(
    AppSession session, {
    required String accountId,
    DateRange dateRange = const DateRange(),
    PaginationCursor page = const PaginationCursor(),
  }) async {
    _assertCanView(session);
    try {
      final json = await _requireClient.rpc(
        'get_cash_bank_activity',
        params: {
          'p_account_id': accountId,
          'p_date_from': dateRangeToIsoDate(dateRange.from),
          'p_date_to': dateRangeToIsoDate(dateRange.to),
          'p_limit': page.limit,
          'p_offset': page.offset,
        },
      );
      return mapCashBankActivityPage(Map<String, dynamic>.from(json as Map));
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }
}
