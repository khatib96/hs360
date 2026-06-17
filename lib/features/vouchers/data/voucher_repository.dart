import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/finance_exception.dart';
import '../../../core/network/supabase_providers.dart';
import '../../auth/domain/app_session.dart';
import '../../finance_shared/domain/date_range.dart';
import '../../finance_shared/domain/finance_permissions.dart';
import '../../finance_shared/domain/pagination_cursor.dart';
import '../domain/voucher_detail.dart';
import '../domain/voucher_filters.dart';
import '../domain/voucher_form_state.dart';
import '../domain/voucher_summary.dart';
import 'voucher_rpc_mapper.dart';

part 'voucher_repository.g.dart';

@Riverpod(keepAlive: true)
VoucherRepository voucherRepository(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return VoucherRepository(client);
}

class VoucherRepository {
  VoucherRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) throw FinanceException.notConfigured();
    return client;
  }

  void _assertCanView(AppSession session) {
    if (!canViewVouchers(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
  }

  void _assertCanListOpenCustomerInvoices(AppSession session) {
    if (!(canViewVouchers(session) ||
        canCreateReceiptVoucher(session) ||
        canViewSalesInvoices(session))) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
  }

  void _assertCanListOpenSupplierInvoices(AppSession session) {
    if (!(canViewVouchers(session) ||
        canCreatePaymentVoucher(session) ||
        canViewPurchaseInvoices(session))) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
  }

  Future<List<VoucherSummary>> listVouchers(
    AppSession session, {
    VoucherFilters filters = const VoucherFilters(),
    PaginationCursor page = const PaginationCursor(),
  }) async {
    _assertCanView(session);
    try {
      final rows = await _requireClient.rpc(
        'list_vouchers',
        params: {
          'p_customer_or_supplier_id': filters.partyId,
          'p_type': filters.type?.toDb(),
          'p_status': filters.status?.toDb(),
          'p_date_from': dateRangeToIsoDate(filters.dateRange.from),
          'p_date_to': dateRangeToIsoDate(filters.dateRange.to),
          'p_search': _trimSearch(filters.search),
          'p_limit': page.limit,
          'p_offset': page.offset,
        },
      );
      return (rows as List)
          .map((r) => VoucherSummary.fromListRow(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<VoucherDetail> getVoucherDetail(
    AppSession session,
    String voucherId,
  ) async {
    _assertCanView(session);
    try {
      final json = await _requireClient.rpc(
        'get_voucher_detail',
        params: {'p_voucher_id': voucherId},
      );
      return mapVoucherDetail(Map<String, dynamic>.from(json as Map));
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<List<OpenInvoiceAllocationOption>> listOpenCustomerInvoices(
    AppSession session,
    String customerId,
  ) async {
    _assertCanListOpenCustomerInvoices(session);
    try {
      final rows = await _requireClient.rpc(
        'list_open_customer_invoices',
        params: {'p_customer_id': customerId},
      );
      return (rows as List)
          .map(
            (r) => OpenInvoiceAllocationOption.fromListRow(
              Map<String, dynamic>.from(r),
            ),
          )
          .toList();
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<List<OpenInvoiceAllocationOption>> listOpenSupplierInvoices(
    AppSession session,
    String supplierId,
  ) async {
    _assertCanListOpenSupplierInvoices(session);
    try {
      final rows = await _requireClient.rpc(
        'list_open_supplier_invoices',
        params: {'p_supplier_id': supplierId},
      );
      return (rows as List)
          .map(
            (r) => OpenInvoiceAllocationOption.fromListRow(
              Map<String, dynamic>.from(r),
            ),
          )
          .toList();
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<String> recordReceiptVoucher(
    AppSession session,
    VoucherFormState form,
    String idempotencyKey,
  ) async {
    if (!canCreateReceiptVoucher(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    return _recordVoucher(
      'record_receipt_voucher',
      form.toRecordPayload(),
      idempotencyKey,
    );
  }

  Future<String> recordPaymentVoucher(
    AppSession session,
    VoucherFormState form,
    String idempotencyKey,
  ) async {
    if (!canCreatePaymentVoucher(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    return _recordVoucher(
      'record_payment_voucher',
      form.toRecordPayload(),
      idempotencyKey,
    );
  }

  Future<String> recordCustomerRefundVoucher(
    AppSession session, {
    required String returnInvoiceId,
    required VoucherFormState form,
    required String idempotencyKey,
  }) async {
    if (!canCreatePaymentVoucher(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    return _recordReturnRefundVoucher(
      'record_customer_refund_voucher',
      returnInvoiceId,
      form,
      idempotencyKey,
    );
  }

  Future<String> recordSupplierRefundReceipt(
    AppSession session, {
    required String returnInvoiceId,
    required VoucherFormState form,
    required String idempotencyKey,
  }) async {
    if (!canCreateReceiptVoucher(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    return _recordReturnRefundVoucher(
      'record_supplier_refund_receipt',
      returnInvoiceId,
      form,
      idempotencyKey,
    );
  }

  Future<String> cancelVoucher(
    AppSession session,
    String voucherId,
    String reason,
    String idempotencyKey,
  ) async {
    if (!canCancelVoucher(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    try {
      final id = await _requireClient.rpc(
        'cancel_voucher',
        params: {
          'p_voucher_id': voucherId,
          'p_reason': reason.trim(),
          'p_idempotency_key': idempotencyKey,
        },
      );
      return id as String;
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<String> _recordVoucher(
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

  Future<String> _recordReturnRefundVoucher(
    String rpcName,
    String returnInvoiceId,
    VoucherFormState form,
    String idempotencyKey,
  ) async {
    try {
      final id = await _requireClient.rpc(
        rpcName,
        params: returnRefundVoucherParams(
          rpcReturnInvoiceId: returnInvoiceId,
          form: form,
          idempotencyKey: idempotencyKey,
        ),
      );
      return id as String;
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  String? _trimSearch(String? value) {
    final trimmed = value?.trim();
    if (trimmed == null || trimmed.isEmpty) return null;
    return trimmed;
  }
}
