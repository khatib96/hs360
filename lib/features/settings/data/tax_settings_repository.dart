import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/finance_exception.dart';
import '../../../core/network/supabase_providers.dart';
import '../../../domain/finance/tax_rate.dart';
import '../../../domain/finance/tax_settings.dart';
import '../../auth/domain/app_session.dart';
import '../../finance_shared/domain/finance_permissions.dart';
import 'tax_settings_rpc_mapper.dart';

part 'tax_settings_repository.g.dart';

@Riverpod(keepAlive: true)
TaxSettingsRepository taxSettingsRepository(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return TaxSettingsRepository(client);
}

class TaxSettingsRepository {
  TaxSettingsRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) throw FinanceException.notConfigured();
    return client;
  }

  void _assertCanView(AppSession session) {
    if (!canViewTaxSettings(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
  }

  void _assertCanEdit(AppSession session) {
    if (!canEditTaxSettings(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
  }

  Future<List<TaxRateVersion>> listTaxRates(
    AppSession session, {
    bool activeOnly = true,
    int limit = 100,
    int offset = 0,
  }) async {
    _assertCanView(session);
    try {
      final rows = await _requireClient.rpc(
        'list_tax_rates',
        params: {
          'p_active_only': activeOnly,
          'p_limit': limit,
          'p_offset': offset,
        },
      );
      return (rows as List)
          .map((r) => mapTaxRateRow(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<void> updateTaxSettings(
    AppSession session,
    TaxSettings settings,
  ) async {
    _assertCanEdit(session);
    try {
      await _requireClient.rpc(
        'update_tax_settings',
        params: {
          'p_data': {
            'tax_enabled': settings.taxEnabled,
            if (settings.taxRegistrationNumber != null)
              'tax_registration_number': settings.taxRegistrationNumber,
            if (settings.defaultTaxRateId != null)
              'default_tax_rate_id': settings.defaultTaxRateId,
          },
        },
      );
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }
}
