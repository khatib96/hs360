import 'package:decimal/decimal.dart';

import '../../../core/utils/decimal_parser.dart';
import '../../finance_shared/domain/currency_total_dto.dart';
import '../../finance_shared/domain/party_reference.dart';
import 'invoice_status.dart';
import 'invoice_type.dart';

/// Bounded list row for sales, purchase, or return invoices.
class InvoiceSummary {
  const InvoiceSummary({
    required this.id,
    this.invoiceNumber,
    required this.type,
    required this.status,
    required this.date,
    this.dueDate,
    this.party,
    this.subtotal,
    this.discountAmount,
    this.taxAmount,
    required this.total,
    this.paidAmount,
    this.outstanding,
    this.currency,
    this.cancelledAt,
    this.originalInvoiceId,
    this.originalInvoiceNumber,
    this.creditRemaining,
    this.returnReason,
  });

  final String id;
  final String? invoiceNumber;
  final InvoiceType type;
  final InvoiceStatus status;
  final DateTime date;
  final DateTime? dueDate;
  final PartyReference? party;
  final Decimal? subtotal;
  final Decimal? discountAmount;
  final Decimal? taxAmount;
  final Decimal total;
  final Decimal? paidAmount;
  final Decimal? outstanding;
  final CurrencyTotalDto? currency;
  final DateTime? cancelledAt;
  final String? originalInvoiceId;
  final String? originalInvoiceNumber;
  final Decimal? creditRemaining;
  final String? returnReason;

  factory InvoiceSummary.fromSalesListRow(Map<String, dynamic> row) {
    return InvoiceSummary(
      id: row['id'] as String,
      invoiceNumber: row['invoice_number'] as String?,
      type: InvoiceType.sales,
      status: InvoiceStatus.fromDb(row['status'] as String?),
      date: DateTime.parse(row['date'] as String),
      dueDate: row['due_date'] != null
          ? DateTime.parse(row['due_date'] as String)
          : null,
      party: PartyReference(
        customerId: row['customer_id'] as String?,
        nameAr: row['customer_name_ar'] as String? ?? '',
        nameEn: row['customer_name_en'] as String? ?? '',
      ),
      subtotal: parseDecimal(row['subtotal']),
      discountAmount: parseDecimal(row['discount_amount']),
      taxAmount: parseDecimal(row['tax_amount']),
      total: parseDecimal(row['total']),
      paidAmount: parseDecimal(row['paid_amount']),
      outstanding: parseDecimal(row['outstanding']),
      currency: CurrencyTotalDto.fromRpcRow(row),
      cancelledAt: row['cancelled_at'] != null
          ? DateTime.parse(row['cancelled_at'] as String)
          : null,
    );
  }

  factory InvoiceSummary.fromPurchaseListRow(Map<String, dynamic> row) {
    return InvoiceSummary(
      id: row['id'] as String,
      invoiceNumber: row['invoice_number'] as String?,
      type: InvoiceType.purchase,
      status: InvoiceStatus.fromDb(row['status'] as String?),
      date: DateTime.parse(row['date'] as String),
      dueDate: row['due_date'] != null
          ? DateTime.parse(row['due_date'] as String)
          : null,
      party: PartyReference(
        supplierId: row['supplier_id'] as String?,
        nameAr: row['supplier_name_ar'] as String? ?? '',
        nameEn: row['supplier_name_en'] as String? ?? '',
      ),
      subtotal: parseDecimal(row['subtotal']),
      discountAmount: parseDecimal(row['discount_amount']),
      taxAmount: parseDecimal(row['tax_amount']),
      total: parseDecimal(row['total']),
      paidAmount: parseDecimal(row['paid_amount']),
      outstanding: parseDecimal(row['outstanding']),
      currency: CurrencyTotalDto.fromRpcRow(row),
      cancelledAt: row['cancelled_at'] != null
          ? DateTime.parse(row['cancelled_at'] as String)
          : null,
    );
  }

  factory InvoiceSummary.fromReturnListRow(Map<String, dynamic> row) {
    return InvoiceSummary(
      id: row['id'] as String,
      invoiceNumber: row['invoice_number'] as String?,
      type: InvoiceType.fromDb(row['type'] as String?),
      status: InvoiceStatus.fromDb(row['status'] as String?),
      date: DateTime.parse(row['date'] as String),
      party: PartyReference(
        customerId: row['customer_id'] as String?,
        supplierId: row['supplier_id'] as String?,
        nameAr: row['party_name_ar'] as String? ?? '',
        nameEn: row['party_name_en'] as String? ?? '',
      ),
      total: parseDecimal(row['total']),
      creditRemaining: parseDecimal(row['credit_remaining']),
      originalInvoiceId: row['original_invoice_id'] as String?,
      originalInvoiceNumber: row['original_invoice_number'] as String?,
      returnReason: row['return_reason'] as String?,
    );
  }
}
