import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/finance_exception.dart';
import '../../../core/network/supabase_providers.dart';
import '../../auth/domain/app_session.dart';
import '../../finance_shared/domain/date_range.dart';
import '../../finance_shared/domain/pagination_cursor.dart';
import '../domain/invoice_detail.dart';
import '../domain/invoice_filters.dart';
import '../domain/invoice_form_state.dart';
import '../domain/invoice_permissions.dart';
import '../domain/invoice_summary.dart';
import '../domain/invoice_type.dart';
import '../domain/party_credit.dart';
import '../domain/return_invoice_draft.dart';
import '../domain/returnable_invoice_line.dart';
import 'invoice_rpc_mapper.dart';

part 'invoice_repository.g.dart';

@Riverpod(keepAlive: true)
InvoiceRepository invoiceRepository(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return InvoiceRepository(client);
}

class InvoiceRepository {
  InvoiceRepository(this._client);

  static const defaultPageSize = 50;

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) throw FinanceException.notConfigured();
    return client;
  }

  void _assertCanViewAny(AppSession session) {
    if (!canViewAnyInvoices(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
  }

  Future<List<InvoiceSummary>> listSalesInvoices(
    AppSession session, {
    InvoiceFilters filters = const InvoiceFilters(),
    PaginationCursor page = const PaginationCursor(),
  }) async {
    if (!canViewSalesInvoices(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    return _listSales(session, filters, page);
  }

  Future<List<InvoiceSummary>> listPurchaseInvoices(
    AppSession session, {
    InvoiceFilters filters = const InvoiceFilters(),
    PaginationCursor page = const PaginationCursor(),
  }) async {
    if (!canViewPurchaseInvoices(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    return _listPurchase(session, filters, page);
  }

  Future<List<InvoiceSummary>> listReturnInvoices(
    AppSession session, {
    InvoiceFilters filters = const InvoiceFilters(),
    PaginationCursor page = const PaginationCursor(),
  }) async {
    if (!canViewReturnInvoices(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    return _listReturns(session, filters, page);
  }

  Future<InvoiceDetail> getSalesInvoiceDetail(
    AppSession session,
    String invoiceId,
  ) async {
    if (!canViewSalesInvoices(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    return _fetchSalesDetail(invoiceId);
  }

  Future<InvoiceDetail> getPurchaseInvoiceDetail(
    AppSession session,
    String invoiceId,
  ) async {
    if (!canViewPurchaseInvoices(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    return _fetchPurchaseDetail(invoiceId);
  }

  Future<InvoiceDetail> getReturnInvoiceDetail(
    AppSession session,
    String invoiceId,
  ) async {
    if (!canViewReturnInvoices(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    return _fetchReturnDetail(invoiceId);
  }

  Future<InvoiceDetail> fetchInvoiceDetail(
    String invoiceId,
    AppSession session, {
    InvoiceType? type,
  }) async {
    _assertCanViewAny(session);
    if (type != null) {
      return _fetchTypedDetail(session, invoiceId, type);
    }

    FinanceException? lastError;
    for (final candidate in _detailProbeOrder(session)) {
      try {
        return await _fetchTypedDetail(session, invoiceId, candidate);
      } on FinanceException catch (error) {
        if (error.code == FinanceException.validationFailed ||
            error.code == FinanceException.notFound) {
          lastError = error;
          continue;
        }
        rethrow;
      }
    }
    throw lastError ?? const FinanceException(code: FinanceException.notFound);
  }

  Future<List<ReturnableInvoiceLine>> listReturnableInvoiceLines(
    AppSession session,
    String originalInvoiceId,
  ) async {
    if (!canViewAnyInvoices(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    try {
      final rows = await _requireClient.rpc(
        'list_returnable_invoice_lines',
        params: {'p_original_invoice_id': originalInvoiceId},
      );
      return (rows as List)
          .map(
            (r) =>
                ReturnableInvoiceLine.fromListRow(Map<String, dynamic>.from(r)),
          )
          .toList();
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<List<PartyCredit>> listAvailablePartyCredits(
    AppSession session, {
    required String partyId,
    required String direction,
  }) async {
    if (!canViewAnyInvoices(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    try {
      final rows = await _requireClient.rpc(
        'list_available_party_credits',
        params: {'p_party_id': partyId, 'p_direction': direction},
      );
      return (rows as List)
          .map((r) => PartyCredit.fromListRow(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<String> saveInvoiceDraft(
    AppSession session,
    InvoiceFormState form,
  ) async {
    if (!canEditInvoiceDraft(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    try {
      final id = await _requireClient.rpc(
        'save_invoice_draft',
        params: {'p_data': form.toDraftPayload()},
      );
      return id as String;
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<String> discardInvoiceDraft(
    AppSession session,
    String invoiceId,
  ) async {
    if (!canEditInvoiceDraft(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    try {
      final id = await _requireClient.rpc(
        'discard_invoice_draft',
        params: {'p_invoice_id': invoiceId},
      );
      return id as String;
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<String> recordSalesInvoice(
    AppSession session,
    InvoiceFormState form,
    String idempotencyKey,
  ) async {
    if (!canCreateSalesInvoice(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    return _recordInvoice(
      'record_sales_invoice',
      form.toRecordPayload(),
      idempotencyKey,
    );
  }

  Future<String> recordPurchaseInvoice(
    AppSession session,
    InvoiceFormState form,
    String idempotencyKey,
  ) async {
    if (!canCreatePurchaseInvoice(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    return _recordInvoice(
      'record_purchase_invoice',
      form.toRecordPayload(),
      idempotencyKey,
    );
  }

  Future<String> recordSalesReturn(
    AppSession session,
    ReturnInvoiceDraft draft,
    String idempotencyKey,
  ) async {
    if (!canCreateSalesReturn(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    return _recordInvoice(
      'record_sales_return',
      draft.toRecordPayload(),
      idempotencyKey,
    );
  }

  Future<String> recordPurchaseReturn(
    AppSession session,
    ReturnInvoiceDraft draft,
    String idempotencyKey,
  ) async {
    if (!canCreatePurchaseReturn(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    return _recordInvoice(
      'record_purchase_return',
      draft.toRecordPayload(),
      idempotencyKey,
    );
  }

  Future<String> cancelInvoice(
    AppSession session,
    String invoiceId,
    String reason,
    String idempotencyKey,
  ) async {
    if (!canCancelInvoice(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    try {
      final id = await _requireClient.rpc(
        'cancel_invoice',
        params: {
          'p_invoice_id': invoiceId,
          'p_reason': reason.trim(),
          'p_idempotency_key': idempotencyKey,
        },
      );
      return id as String;
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<String> cancelReturnInvoice(
    AppSession session,
    String invoiceId,
    String reason,
    String idempotencyKey,
  ) async {
    if (!canCancelInvoice(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    try {
      final id = await _requireClient.rpc(
        'cancel_return_invoice',
        params: cancelReturnInvoiceParams(
          returnInvoiceId: invoiceId,
          reason: reason,
          idempotencyKey: idempotencyKey,
        ),
      );
      return id as String;
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<String> applyReturnCreditToInvoice(
    AppSession session, {
    required String returnInvoiceId,
    required String targetInvoiceId,
    required String amount,
    required String idempotencyKey,
  }) async {
    if (!canCreateAnyReturn(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    try {
      final id = await _requireClient.rpc(
        'apply_return_credit_to_invoice',
        params: {
          'p_return_invoice_id': returnInvoiceId,
          'p_target_invoice_id': targetInvoiceId,
          'p_amount': amount,
          'p_idempotency_key': idempotencyKey,
        },
      );
      return id as String;
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<InvoiceDetail> _fetchTypedDetail(
    AppSession session,
    String invoiceId,
    InvoiceType type,
  ) {
    return switch (type) {
      InvoiceType.sales => getSalesInvoiceDetail(session, invoiceId),
      InvoiceType.purchase => getPurchaseInvoiceDetail(session, invoiceId),
      InvoiceType.salesReturn ||
      InvoiceType.purchaseReturn => getReturnInvoiceDetail(session, invoiceId),
    };
  }

  List<InvoiceType> _detailProbeOrder(AppSession session) {
    final order = <InvoiceType>[];
    if (canViewSalesInvoices(session)) order.add(InvoiceType.sales);
    if (canViewPurchaseInvoices(session)) order.add(InvoiceType.purchase);
    if (canViewReturnInvoices(session)) {
      order.add(InvoiceType.salesReturn);
      order.add(InvoiceType.purchaseReturn);
    }
    return order;
  }

  Future<List<InvoiceSummary>> _listSales(
    AppSession session,
    InvoiceFilters filters,
    PaginationCursor page,
  ) async {
    try {
      final rows = await _requireClient.rpc(
        'list_sales_invoices',
        params: _salesListParams(filters, page),
      );
      return (rows as List)
          .map(
            (r) =>
                InvoiceSummary.fromSalesListRow(Map<String, dynamic>.from(r)),
          )
          .toList();
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<List<InvoiceSummary>> _listPurchase(
    AppSession session,
    InvoiceFilters filters,
    PaginationCursor page,
  ) async {
    try {
      final rows = await _requireClient.rpc(
        'list_purchase_invoices',
        params: _purchaseListParams(filters, page),
      );
      return (rows as List)
          .map(
            (r) => InvoiceSummary.fromPurchaseListRow(
              Map<String, dynamic>.from(r),
            ),
          )
          .toList();
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<List<InvoiceSummary>> _listReturns(
    AppSession session,
    InvoiceFilters filters,
    PaginationCursor page,
  ) async {
    try {
      final rows = await _requireClient.rpc(
        'list_return_invoices',
        params: _returnListParams(filters, page),
      );
      return (rows as List)
          .map(
            (r) =>
                InvoiceSummary.fromReturnListRow(Map<String, dynamic>.from(r)),
          )
          .toList();
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<InvoiceDetail> _fetchSalesDetail(String invoiceId) async {
    try {
      final json = await _requireClient.rpc(
        'get_sales_invoice_detail',
        params: {'p_invoice_id': invoiceId},
      );
      return mapSalesInvoiceDetail(Map<String, dynamic>.from(json as Map));
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<InvoiceDetail> _fetchPurchaseDetail(String invoiceId) async {
    try {
      final json = await _requireClient.rpc(
        'get_purchase_invoice_detail',
        params: {'p_invoice_id': invoiceId},
      );
      return mapPurchaseInvoiceDetail(Map<String, dynamic>.from(json as Map));
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<InvoiceDetail> _fetchReturnDetail(String invoiceId) async {
    try {
      final json = await _requireClient.rpc(
        'get_return_invoice_detail',
        params: {'p_invoice_id': invoiceId},
      );
      return mapReturnInvoiceDetail(Map<String, dynamic>.from(json as Map));
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<String> _recordInvoice(
    String rpcName,
    Map<String, dynamic> payload,
    String idempotencyKey,
  ) async {
    try {
      final id = await _requireClient.rpc(
        rpcName,
        params: {'p_data': payload, 'p_idempotency_key': idempotencyKey},
      );
      return id as String;
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Map<String, dynamic> _salesListParams(
    InvoiceFilters filters,
    PaginationCursor page,
  ) {
    return {
      'p_customer_id': filters.partyId,
      'p_status': filters.status?.toDb(),
      'p_date_from': dateRangeToIsoDate(filters.dateRange.from),
      'p_date_to': dateRangeToIsoDate(filters.dateRange.to),
      'p_search': _trimSearch(filters.search),
      'p_limit': page.limit,
      'p_offset': page.offset,
    };
  }

  Map<String, dynamic> _purchaseListParams(
    InvoiceFilters filters,
    PaginationCursor page,
  ) {
    return {
      'p_supplier_id': filters.partyId,
      'p_status': filters.status?.toDb(),
      'p_date_from': dateRangeToIsoDate(filters.dateRange.from),
      'p_date_to': dateRangeToIsoDate(filters.dateRange.to),
      'p_search': _trimSearch(filters.search),
      'p_limit': page.limit,
      'p_offset': page.offset,
    };
  }

  Map<String, dynamic> _returnListParams(
    InvoiceFilters filters,
    PaginationCursor page,
  ) {
    return {
      'p_party_id': filters.partyId,
      'p_type': filters.type?.toDb(),
      'p_status': filters.status?.toDb(),
      'p_date_from': dateRangeToIsoDate(filters.dateRange.from),
      'p_date_to': dateRangeToIsoDate(filters.dateRange.to),
      'p_search': _trimSearch(filters.search),
      'p_limit': page.limit,
      'p_offset': page.offset,
    };
  }

  String? _trimSearch(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
