import 'package:decimal/decimal.dart';

import '../../../core/utils/decimal_parser.dart';
import '../../finance_shared/domain/party_reference.dart';
import 'invoice_line.dart';
import 'invoice_status.dart';
import 'invoice_type.dart';

class InvoiceWarehouseRef {
  const InvoiceWarehouseRef({
    required this.id,
    required this.nameAr,
    required this.nameEn,
  });

  final String id;
  final String nameAr;
  final String nameEn;

  factory InvoiceWarehouseRef.fromJson(Map<String, dynamic>? json) {
    if (json == null) {
      throw FormatException('Warehouse JSON is null');
    }
    return InvoiceWarehouseRef(
      id: json['id'] as String,
      nameAr: json['name_ar'] as String? ?? '',
      nameEn: json['name_en'] as String? ?? '',
    );
  }
}

class InvoiceOriginalRef {
  const InvoiceOriginalRef({
    required this.id,
    required this.invoiceNumber,
    required this.date,
    required this.total,
  });

  final String id;
  final String? invoiceNumber;
  final DateTime date;
  final Decimal total;

  factory InvoiceOriginalRef.fromJson(Map<String, dynamic> json) {
    return InvoiceOriginalRef(
      id: json['id'] as String,
      invoiceNumber: json['invoice_number'] as String?,
      date: DateTime.parse(json['date'] as String),
      total: parseDecimal(json['total']),
    );
  }
}

class ReturnCreditAllocation {
  const ReturnCreditAllocation({
    required this.id,
    required this.allocationKind,
    this.targetInvoiceId,
    this.targetInvoiceNumber,
    this.voucherId,
    this.voucherNumber,
    required this.allocatedAmount,
    required this.isReversed,
    this.reversedAt,
    this.createdAt,
  });

  final String id;
  final String allocationKind;
  final String? targetInvoiceId;
  final String? targetInvoiceNumber;
  final String? voucherId;
  final String? voucherNumber;
  final Decimal allocatedAmount;
  final bool isReversed;
  final DateTime? reversedAt;
  final DateTime? createdAt;

  factory ReturnCreditAllocation.fromJson(Map<String, dynamic> json) {
    return ReturnCreditAllocation(
      id: json['id'] as String,
      allocationKind: json['allocation_kind'] as String,
      targetInvoiceId: json['target_invoice_id'] as String?,
      targetInvoiceNumber: json['target_invoice_number'] as String?,
      voucherId: json['voucher_id'] as String?,
      voucherNumber: json['voucher_number'] as String?,
      allocatedAmount: parseDecimal(json['allocated_amount']),
      isReversed: json['is_reversed'] as bool? ?? false,
      reversedAt: json['reversed_at'] != null
          ? DateTime.parse(json['reversed_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : null,
    );
  }
}

/// Full invoice snapshot from typed detail RPC JSON.
class InvoiceDetail {
  const InvoiceDetail({
    required this.id,
    this.invoiceNumber,
    required this.type,
    required this.status,
    required this.date,
    this.dueDate,
    this.customer,
    this.supplier,
    this.warehouse,
    this.notes,
    required this.subtotal,
    required this.discountAmount,
    required this.taxAmount,
    required this.total,
    required this.paidAmount,
    required this.outstanding,
    this.currencyCode,
    this.currencySymbol,
    this.currencyDecimalPlaces = 3,
    this.creditRemaining,
    this.returnReason,
    this.originalInvoice,
    this.journalEntryId,
    this.reversalJournalEntryId,
    this.confirmedAt,
    this.cancelledAt,
    required this.lines,
    this.creditAllocations = const [],
  });

  final String id;
  final String? invoiceNumber;
  final InvoiceType type;
  final InvoiceStatus status;
  final DateTime date;
  final DateTime? dueDate;
  final PartyReference? customer;
  final PartyReference? supplier;
  final InvoiceWarehouseRef? warehouse;
  final String? notes;
  final Decimal subtotal;
  final Decimal discountAmount;
  final Decimal taxAmount;
  final Decimal total;
  final Decimal paidAmount;
  final Decimal outstanding;
  final String? currencyCode;
  final String? currencySymbol;
  final int currencyDecimalPlaces;
  final Decimal? creditRemaining;
  final String? returnReason;
  final InvoiceOriginalRef? originalInvoice;
  final String? journalEntryId;
  final String? reversalJournalEntryId;
  final DateTime? confirmedAt;
  final DateTime? cancelledAt;
  final List<InvoiceLine> lines;
  final List<ReturnCreditAllocation> creditAllocations;

  PartyReference? get party => customer ?? supplier;
}
