import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/finance_exception.dart';
import '../../../core/network/supabase_providers.dart';
import '../../auth/domain/app_session.dart';
import '../../finance_shared/domain/pagination_cursor.dart';
import '../domain/closure_draft.dart';
import '../domain/contract_detail.dart';
import '../domain/contract_draft.dart';
import '../domain/contract_filters.dart';
import '../domain/consumable_change_draft.dart';
import '../domain/contract_permissions.dart';
import '../domain/contract_pricing_preview.dart';
import '../domain/contract_summary.dart';
import '../domain/rental_collection_draft.dart';
import '../domain/trial_conversion_draft.dart';
import '../domain/trial_extension_draft.dart';
import '../domain/trial_return_draft.dart';
import 'contract_rpc_mapper.dart';

part 'contract_repository.g.dart';

@Riverpod(keepAlive: true)
ContractRepository contractRepository(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return ContractRepository(client);
}

class ContractRepository {
  ContractRepository(this._client);

  static const defaultPageSize = 50;

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) throw FinanceException.notConfigured();
    return client;
  }

  Future<List<ContractSummary>> listContracts(
    AppSession session, {
    ContractFilters filters = const ContractFilters(),
    PaginationCursor page = const PaginationCursor(),
  }) async {
    if (!canViewContracts(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    try {
      final rows = await _requireClient.rpc(
        'list_contracts',
        params: _listParams(filters, page),
      );
      return (rows as List)
          .map(
            (row) => ContractSummary.fromListRow(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<ContractDetail> fetchContractDetail(
    AppSession session,
    String contractId,
  ) async {
    if (!canViewContracts(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    try {
      final json = await _requireClient.rpc(
        'get_contract_detail',
        params: {'p_contract_id': contractId},
      );
      return mapContractDetail(Map<String, dynamic>.from(json as Map));
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Map<String, dynamic> _listParams(
    ContractFilters filters,
    PaginationCursor page,
  ) {
    return {
      'p_customer_id': filters.customerId,
      'p_type': filters.type?.toDb(),
      'p_status': filters.status?.toDb(),
      'p_date_from': filters.dateRange.from?.toIso8601String().split('T').first,
      'p_date_to': filters.dateRange.to?.toIso8601String().split('T').first,
      'p_search': filters.search,
      'p_low_profit_override_only': filters.lowProfitOverrideOnly,
      'p_limit': page.limit,
      'p_offset': page.offset,
    };
  }

  Future<ContractPricingPreview> previewContractProfit(
    AppSession session,
    ContractDraft draft,
  ) async {
    if (!canPreviewContractProfit(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    try {
      final json = await _requireClient.rpc(
        'preview_contract_profit',
        params: {'p_data': draft.toPreviewPayload()},
      );
      return mapContractPricingPreview(Map<String, dynamic>.from(json as Map));
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<String> createTrialContract(
    AppSession session,
    ContractDraft draft,
    String idempotencyKey,
  ) async {
    if (!canCreateContract(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    return _createContract(
      'create_trial_contract',
      draft.toTrialPayload(),
      idempotencyKey,
    );
  }

  Future<String> createRentalContract(
    AppSession session,
    ContractDraft draft,
    String idempotencyKey,
  ) async {
    if (!canCreateContract(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    return _createContract(
      'create_rental_contract',
      draft.toRentalPayload(),
      idempotencyKey,
    );
  }

  Future<String> convertTrialToRental(
    AppSession session,
    TrialConversionDraft draft,
    String idempotencyKey,
  ) async {
    if (!canConvertTrial(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    return _mutateContract(
      'convert_trial_to_rental',
      draft.toPayload(),
      idempotencyKey,
    );
  }

  Future<String> extendTrialContract(
    AppSession session,
    TrialExtensionDraft draft,
    String idempotencyKey,
  ) async {
    if (!canExtendTrial(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    return _mutateContract(
      'extend_trial_contract',
      draft.toPayload(),
      idempotencyKey,
    );
  }

  Future<String> returnTrialContract(
    AppSession session,
    TrialReturnDraft draft,
    String idempotencyKey,
  ) async {
    if (!canReturnTrial(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    return _mutateContract(
      'return_trial_contract',
      draft.toPayload(),
      idempotencyKey,
    );
  }

  Future<String> closeContract(
    AppSession session,
    ClosureDraft draft,
    String idempotencyKey,
  ) async {
    if (!canCloseContract(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    return _mutateContract('close_contract', draft.toPayload(), idempotencyKey);
  }

  Future<String> scheduleConsumableChange(
    AppSession session,
    ConsumableChangeDraft draft,
    String idempotencyKey,
  ) async {
    if (!canScheduleConsumableChange(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    return _mutateContract(
      'schedule_contract_consumable_change',
      draft.toPayload(),
      idempotencyKey,
    );
  }

  Future<RentalCollectionPreview> previewRentalCollection(
    AppSession session,
    RentalCollectionDraft draft,
  ) async {
    if (!canPreviewRentalCollection(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    try {
      final json = await _requireClient.rpc(
        'preview_rental_collection',
        params: {'p_data': draft.toPayload()},
      );
      return mapRentalCollectionPreview(Map<String, dynamic>.from(json as Map));
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<List<String>> listCoveredRentalMonths(
    AppSession session,
    String contractId,
  ) async {
    if (!canPreviewRentalCollection(session) &&
        !canCollectRentalPayment(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    try {
      final json = await _requireClient.rpc(
        'list_covered_rental_months',
        params: {'p_contract_id': contractId},
      );
      return mapCoveredRentalMonths(Map<String, dynamic>.from(json as Map));
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<RentalCollectionResult> collectRentalPayment(
    AppSession session,
    RentalCollectionDraft draft,
    String idempotencyKey,
  ) async {
    if (!canCollectRentalPayment(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    try {
      final json = await _requireClient.rpc(
        'collect_rental_payment',
        params: {
          'p_data': draft.toPayload(),
          'p_idempotency_key': idempotencyKey,
        },
      );
      return mapRentalCollectionResult(Map<String, dynamic>.from(json as Map));
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<String> _createContract(
    String rpcName,
    Map<String, dynamic> payload,
    String idempotencyKey,
  ) async {
    try {
      final id = await _requireClient.rpc(
        rpcName,
        params: {'p_data': payload, 'p_idempotency_key': idempotencyKey},
      );
      return parseRpcUuidRequired(id);
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<String> _mutateContract(
    String rpcName,
    Map<String, dynamic> payload,
    String idempotencyKey,
  ) async {
    try {
      final id = await _requireClient.rpc(
        rpcName,
        params: {'p_data': payload, 'p_idempotency_key': idempotencyKey},
      );
      return parseRpcUuidRequired(id);
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }
}
