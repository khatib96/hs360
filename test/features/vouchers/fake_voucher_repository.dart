import 'package:decimal/decimal.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/finance_shared/domain/pagination_cursor.dart';
import 'package:hs360/features/finance_shared/domain/party_reference.dart';
import 'package:hs360/features/finance_shared/domain/payment_method.dart';
import 'package:hs360/features/vouchers/data/voucher_rpc_mapper.dart';
import 'package:hs360/features/vouchers/domain/voucher_allocation.dart';
import 'package:hs360/features/vouchers/data/voucher_repository.dart';
import 'package:hs360/features/vouchers/domain/voucher_detail.dart';
import 'package:hs360/features/vouchers/domain/voucher_filters.dart';
import 'package:hs360/features/vouchers/domain/voucher_form_state.dart';
import 'package:hs360/features/vouchers/domain/voucher_status.dart';
import 'package:hs360/features/vouchers/domain/voucher_summary.dart';
import 'package:hs360/features/vouchers/domain/voucher_type.dart';

class FakeVoucherRepository extends VoucherRepository {
  FakeVoucherRepository({
    List<VoucherSummary> vouchers = const [],
    this.fetchError,
    this.detailById = const {},
    List<OpenInvoiceAllocationOption> openCustomerInvoices = const [],
    List<OpenInvoiceAllocationOption> openSupplierInvoices = const [],
  }) : vouchers = List<VoucherSummary>.from(vouchers),
       openCustomerInvoices = List<OpenInvoiceAllocationOption>.from(
         openCustomerInvoices,
       ),
       openSupplierInvoices = List<OpenInvoiceAllocationOption>.from(
         openSupplierInvoices,
       ),
       super(null);

  List<VoucherSummary> vouchers;
  Object? fetchError;
  Map<String, VoucherDetail> detailById;

  VoucherFilters? lastFilters;
  PaginationCursor? lastPage;
  VoucherFormState? lastRecordForm;
  String? lastRecordedIdempotencyKey;
  String? lastCancelReason;
  String? lastCancelVoucherId;
  List<OpenInvoiceAllocationOption> openCustomerInvoices;
  List<OpenInvoiceAllocationOption> openSupplierInvoices;

  @override
  Future<List<OpenInvoiceAllocationOption>> listOpenCustomerInvoices(
    AppSession session,
    String customerId,
  ) async {
    _throwIfFetchError();
    return openCustomerInvoices;
  }

  @override
  Future<List<OpenInvoiceAllocationOption>> listOpenSupplierInvoices(
    AppSession session,
    String supplierId,
  ) async {
    _throwIfFetchError();
    return openSupplierInvoices;
  }

  @override
  Future<String> recordPaymentVoucher(
    AppSession session,
    VoucherFormState form,
    String idempotencyKey,
  ) async {
    lastRecordForm = form;
    lastRecordedIdempotencyKey = idempotencyKey;
    return 'voucher-payment-new';
  }

  @override
  Future<String> cancelVoucher(
    AppSession session,
    String voucherId,
    String reason,
    String idempotencyKey,
  ) async {
    lastCancelVoucherId = voucherId;
    lastCancelReason = reason;
    return voucherId;
  }

  @override
  Future<List<VoucherSummary>> listVouchers(
    AppSession session, {
    VoucherFilters filters = const VoucherFilters(),
    PaginationCursor page = const PaginationCursor(),
  }) async {
    _throwIfFetchError();
    lastFilters = filters;
    lastPage = page;
    if (page.offset >= vouchers.length) return const [];
    final end = page.offset + page.limit;
    return vouchers.sublist(
      page.offset,
      end > vouchers.length ? vouchers.length : end,
    );
  }

  @override
  Future<VoucherDetail> getVoucherDetail(
    AppSession session,
    String voucherId,
  ) async {
    _throwIfFetchError();
    final detail = detailById[voucherId];
    if (detail == null) {
      throw const FinanceException(code: FinanceException.notFound);
    }
    return detail;
  }

  @override
  Future<String> recordReceiptVoucher(
    AppSession session,
    VoucherFormState form,
    String idempotencyKey,
  ) async {
    lastRecordForm = form;
    lastRecordedIdempotencyKey = idempotencyKey;
    return 'voucher-new';
  }

  void _throwIfFetchError() {
    final error = fetchError;
    if (error == null) return;
    if (error is FinanceException) throw error;
    throw const FinanceException(code: FinanceException.unknown);
  }
}

VoucherSummary sampleVoucherSummary({String id = 'v-1'}) {
  return VoucherSummary(
    id: id,
    voucherNumber: 'RV-001',
    type: VoucherType.receipt,
    status: VoucherStatus.confirmed,
    date: DateTime(2026, 6, 1),
    amount: Decimal.parse('50.000'),
    paymentMethod: PaymentMethod.cash,
    customer: const PartyReference(
      customerId: 'cust-1',
      nameAr: 'عميل',
      nameEn: 'Customer',
    ),
    cashAccountId: 'acc-cash',
    allocatedAmount: Decimal.parse('50.000'),
    unallocatedAmount: Decimal.zero,
  );
}

VoucherDetail sampleVoucherDetail({
  String id = 'v-1',
  VoucherType type = VoucherType.receipt,
  VoucherStatus status = VoucherStatus.confirmed,
}) {
  return VoucherDetail(
    id: id,
    voucherNumber: 'RV-001',
    type: type,
    status: status,
    date: DateTime(2026, 6, 1),
    amount: Decimal.parse('50.000'),
    paymentMethod: PaymentMethod.cash,
    customer: type == VoucherType.receipt
        ? const PartyReference(
            customerId: 'cust-1',
            nameAr: 'عميل',
            nameEn: 'Customer',
          )
        : null,
    supplier: type == VoucherType.payment
        ? const PartyReference(
            supplierId: 'sup-1',
            nameAr: 'مورد',
            nameEn: 'Supplier',
          )
        : null,
    account: const VoucherAccountRef(
      id: 'acct-1',
      code: '2000',
      nameAr: 'حساب',
      nameEn: 'Account',
    ),
    cashAccount: const VoucherAccountRef(
      id: 'cash-1',
      code: '1000',
      nameAr: 'نقد',
      nameEn: 'Cash',
    ),
    allocations: const [],
    allocatedAmount: Decimal.parse('50.000'),
    unallocatedAmount: Decimal.zero,
  );
}

OpenInvoiceAllocationOption sampleOpenInvoice({
  String id = 'inv-1',
  Decimal? outstanding,
}) {
  final amount = outstanding ?? Decimal.parse('100.000');
  return OpenInvoiceAllocationOption(
    id: id,
    invoiceNumber: 'INV-001',
    status: 'confirmed',
    date: DateTime(2026, 5, 1),
    total: amount,
    paidAmount: Decimal.zero,
    outstanding: amount,
  );
}
