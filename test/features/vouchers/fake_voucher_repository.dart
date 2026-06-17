import 'package:decimal/decimal.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/finance_shared/domain/pagination_cursor.dart';
import 'package:hs360/features/finance_shared/domain/party_reference.dart';
import 'package:hs360/features/finance_shared/domain/payment_method.dart';
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
  }) : vouchers = List<VoucherSummary>.from(vouchers),
       super(null);

  List<VoucherSummary> vouchers;
  Object? fetchError;
  Map<String, VoucherDetail> detailById;

  VoucherFilters? lastFilters;
  PaginationCursor? lastPage;
  VoucherFormState? lastRecordForm;
  String? lastRecordedIdempotencyKey;

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
