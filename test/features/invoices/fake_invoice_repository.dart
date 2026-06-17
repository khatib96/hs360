import 'package:decimal/decimal.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/finance_shared/domain/pagination_cursor.dart';
import 'package:hs360/features/finance_shared/domain/party_reference.dart';
import 'package:hs360/features/invoices/data/invoice_repository.dart';
import 'package:hs360/features/invoices/domain/invoice_detail.dart';
import 'package:hs360/features/invoices/domain/invoice_filters.dart';
import 'package:hs360/features/invoices/domain/invoice_form_state.dart';
import 'package:hs360/features/invoices/domain/invoice_status.dart';
import 'package:hs360/features/invoices/domain/invoice_summary.dart';
import 'package:hs360/features/invoices/domain/invoice_type.dart';
import 'package:hs360/features/invoices/domain/return_invoice_draft.dart';

class FakeInvoiceRepository extends InvoiceRepository {
  FakeInvoiceRepository({
    List<InvoiceSummary> salesInvoices = const [],
    List<InvoiceSummary> purchaseInvoices = const [],
    List<InvoiceSummary> returnInvoices = const [],
    this.fetchError,
    this.detailById = const {},
  }) : salesInvoices = List<InvoiceSummary>.from(salesInvoices),
       purchaseInvoices = List<InvoiceSummary>.from(purchaseInvoices),
       returnInvoices = List<InvoiceSummary>.from(returnInvoices),
       super(null);

  List<InvoiceSummary> salesInvoices;
  List<InvoiceSummary> purchaseInvoices;
  List<InvoiceSummary> returnInvoices;
  Object? fetchError;
  Map<String, InvoiceDetail> detailById;

  InvoiceFilters? lastSalesFilters;
  InvoiceFilters? lastPurchaseFilters;
  InvoiceFilters? lastReturnFilters;
  PaginationCursor? lastPage;
  String? lastRecordedIdempotencyKey;
  InvoiceFormState? lastRecordForm;
  ReturnInvoiceDraft? lastReturnDraft;
  String? lastCancelledId;
  String? lastCancelReason;

  @override
  Future<List<InvoiceSummary>> listSalesInvoices(
    AppSession session, {
    InvoiceFilters filters = const InvoiceFilters(),
    PaginationCursor page = const PaginationCursor(),
  }) async {
    _throwIfFetchError();
    lastSalesFilters = filters;
    lastPage = page;
    return _slice(salesInvoices, page);
  }

  @override
  Future<List<InvoiceSummary>> listPurchaseInvoices(
    AppSession session, {
    InvoiceFilters filters = const InvoiceFilters(),
    PaginationCursor page = const PaginationCursor(),
  }) async {
    _throwIfFetchError();
    lastPurchaseFilters = filters;
    lastPage = page;
    return _slice(purchaseInvoices, page);
  }

  @override
  Future<List<InvoiceSummary>> listReturnInvoices(
    AppSession session, {
    InvoiceFilters filters = const InvoiceFilters(),
    PaginationCursor page = const PaginationCursor(),
  }) async {
    _throwIfFetchError();
    lastReturnFilters = filters;
    lastPage = page;
    return _slice(returnInvoices, page);
  }

  @override
  Future<InvoiceDetail> fetchInvoiceDetail(
    String invoiceId,
    AppSession session, {
    InvoiceType? type,
  }) async {
    _throwIfFetchError();
    final detail = detailById[invoiceId];
    if (detail == null) {
      throw const FinanceException(code: FinanceException.notFound);
    }
    return detail;
  }

  @override
  Future<String> recordSalesInvoice(
    AppSession session,
    InvoiceFormState form,
    String idempotencyKey,
  ) async {
    lastRecordForm = form;
    lastRecordedIdempotencyKey = idempotencyKey;
    return 'inv-new';
  }

  @override
  Future<String> cancelInvoice(
    AppSession session,
    String invoiceId,
    String reason,
    String idempotencyKey,
  ) async {
    lastCancelledId = invoiceId;
    lastCancelReason = reason;
    lastRecordedIdempotencyKey = idempotencyKey;
    return invoiceId;
  }

  List<InvoiceSummary> _slice(
    List<InvoiceSummary> source,
    PaginationCursor page,
  ) {
    if (page.offset >= source.length) return const [];
    final end = page.offset + page.limit;
    return source.sublist(
      page.offset,
      end > source.length ? source.length : end,
    );
  }

  void _throwIfFetchError() {
    final error = fetchError;
    if (error == null) return;
    if (error is FinanceException) throw error;
    throw const FinanceException(code: FinanceException.unknown);
  }
}

InvoiceSummary sampleInvoiceSummary({
  String id = 'inv-1',
  InvoiceType type = InvoiceType.sales,
}) {
  return InvoiceSummary(
    id: id,
    invoiceNumber: 'SI-001',
    type: type,
    status: InvoiceStatus.confirmed,
    date: DateTime(2026, 6, 1),
    party: const PartyReference(
      customerId: 'cust-1',
      nameAr: 'عميل',
      nameEn: 'Customer',
    ),
    total: Decimal.parse('100.000'),
  );
}

InvoiceDetail sampleInvoiceDetail({
  String id = 'inv-1',
  InvoiceType type = InvoiceType.sales,
}) {
  return InvoiceDetail(
    id: id,
    invoiceNumber: 'SI-001',
    type: type,
    status: InvoiceStatus.confirmed,
    date: DateTime(2026, 6, 1),
    subtotal: Decimal.parse('100.000'),
    discountAmount: Decimal.zero,
    taxAmount: Decimal.zero,
    total: Decimal.parse('100.000'),
    paidAmount: Decimal.zero,
    outstanding: Decimal.parse('100.000'),
    lines: const [],
  );
}
