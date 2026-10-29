import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/finance_exception.dart';
import '../../../core/network/supabase_providers.dart';
import '../domain/rental_billing.dart';

typedef RentalBillingRpcInvoker =
    Future<dynamic> Function(String functionName, Map<String, dynamic> params);

final rentalBillingRepositoryProvider = Provider<RentalBillingRepository>((
  ref,
) {
  return RentalBillingRepository(ref.watch(supabaseClientProvider));
});

/// Rental collections per contract, cancelling a collection, and arrears.
class RentalBillingRepository {
  RentalBillingRepository(this._client, {RentalBillingRpcInvoker? rpcInvoker})
    : _rpcInvoker = rpcInvoker;

  final SupabaseClient? _client;
  final RentalBillingRpcInvoker? _rpcInvoker;

  Future<dynamic> _rpc(String name, Map<String, dynamic> params) async {
    try {
      final invoker = _rpcInvoker;
      if (invoker != null) return await invoker(name, params);
      final client = _client;
      if (client == null) throw FinanceException.notConfigured();
      return await client.rpc(name, params: params);
    } on FinanceException {
      rethrow;
    } catch (error, stackTrace) {
      throw FinanceException.fromSupabase(error, stackTrace);
    }
  }

  Future<List<RentalCollectionEntry>> listCollections(String contractId) async {
    final rows = await _rpc('list_contract_rental_collections', {
      'p_contract_id': contractId,
    });
    return [
      if (rows is List)
        for (final row in rows)
          if (row is Map)
            RentalCollectionEntry.fromJson(Map<String, dynamic>.from(row)),
    ];
  }

  Future<void> cancelCollection({
    required String invoiceId,
    required String reason,
    required String idempotencyKey,
  }) async {
    await _rpc('cancel_rental_collection', {
      'p_invoice_id': invoiceId,
      'p_reason': reason.trim(),
      'p_idempotency_key': idempotencyKey,
    });
  }

  Future<RentalArrearsReport> listArrears({DateTime? asOf}) async {
    final json = await _rpc('list_rental_arrears', {
      'p_as_of': asOf == null
          ? null
          : '${asOf.year.toString().padLeft(4, '0')}-'
                '${asOf.month.toString().padLeft(2, '0')}-'
                '${asOf.day.toString().padLeft(2, '0')}',
    });
    return RentalArrearsReport.fromJson(Map<String, dynamic>.from(json as Map));
  }
}

final contractRentalCollectionsProvider = FutureProvider.autoDispose
    .family<List<RentalCollectionEntry>, String>(
      (ref, contractId) => ref
          .watch(rentalBillingRepositoryProvider)
          .listCollections(contractId),
    );

final rentalArrearsProvider = FutureProvider.autoDispose<RentalArrearsReport>(
  (ref) => ref.watch(rentalBillingRepositoryProvider).listArrears(),
);
