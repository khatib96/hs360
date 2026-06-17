import 'package:decimal/decimal.dart';

import '../../../core/utils/decimal_parser.dart';
import '../../finance_shared/domain/party_reference.dart';
import '../domain/invoice_detail.dart';
import '../domain/invoice_line.dart';
import '../domain/invoice_status.dart';
import '../domain/invoice_type.dart';

Map<String, dynamic> cancelReturnInvoiceParams({
  required String returnInvoiceId,
  required String reason,
  required String idempotencyKey,
}) {
  return {
    'p_return_invoice_id': returnInvoiceId,
    'p_reason': reason.trim(),
    'p_idempotency_key': idempotencyKey,
  };
}

InvoiceDetail mapSalesInvoiceDetail(Map<String, dynamic> json) {
  return _mapInvoiceDetail(json, InvoiceType.sales);
}

InvoiceDetail mapPurchaseInvoiceDetail(Map<String, dynamic> json) {
  return _mapInvoiceDetail(json, InvoiceType.purchase);
}

InvoiceDetail mapReturnInvoiceDetail(Map<String, dynamic> json) {
  final type = InvoiceType.fromDb(json['type'] as String?);
  return _mapInvoiceDetail(json, type);
}

InvoiceDetail _mapInvoiceDetail(Map<String, dynamic> json, InvoiceType type) {
  final currency = json['currency'];
  Map<String, dynamic>? currencyMap;
  if (currency is Map) {
    currencyMap = Map<String, dynamic>.from(currency);
  }

  final customerJson = json['customer'];
  final supplierJson = json['supplier'];
  final warehouseJson = json['warehouse'];
  final originalJson = json['original_invoice'];
  final linesRaw = json['lines'];
  final allocationsRaw = json['credit_allocations'];

  return InvoiceDetail(
    id: json['id'] as String,
    invoiceNumber: json['invoice_number'] as String?,
    type: type,
    status: InvoiceStatus.fromDb(json['status'] as String?),
    date: DateTime.parse(json['date'] as String),
    dueDate: json['due_date'] != null
        ? DateTime.parse(json['due_date'] as String)
        : null,
    customer: customerJson is Map
        ? PartyReference.fromCustomerJson(
            Map<String, dynamic>.from(customerJson),
          )
        : null,
    supplier: supplierJson is Map
        ? PartyReference.fromSupplierJson(
            Map<String, dynamic>.from(supplierJson),
          )
        : null,
    warehouse: warehouseJson is Map
        ? InvoiceWarehouseRef.fromJson(Map<String, dynamic>.from(warehouseJson))
        : null,
    notes: json['notes'] as String?,
    subtotal: _parse(json['subtotal']),
    discountAmount: _parse(json['discount_amount']),
    taxAmount: _parse(json['tax_amount']),
    total: _parse(json['total']),
    paidAmount: _parse(json['paid_amount'] ?? 0),
    outstanding: _parse(json['outstanding'] ?? 0),
    currencyCode: currencyMap?['code'] as String?,
    currencySymbol: currencyMap?['symbol'] as String?,
    currencyDecimalPlaces: currencyMap?['decimal_places'] as int? ?? 3,
    creditRemaining: json['credit_remaining'] != null
        ? _parse(json['credit_remaining'])
        : null,
    returnReason: json['return_reason'] as String?,
    originalInvoice: originalJson is Map
        ? InvoiceOriginalRef.fromJson(Map<String, dynamic>.from(originalJson))
        : null,
    journalEntryId: json['journal_entry_id'] as String?,
    reversalJournalEntryId: json['reversal_journal_entry_id'] as String?,
    confirmedAt: json['confirmed_at'] != null
        ? DateTime.parse(json['confirmed_at'] as String)
        : null,
    cancelledAt: json['cancelled_at'] != null
        ? DateTime.parse(json['cancelled_at'] as String)
        : null,
    lines: linesRaw is List
        ? linesRaw
              .map(
                (line) => InvoiceLine.fromRpcJson(
                  Map<String, dynamic>.from(line as Map),
                ),
              )
              .toList()
        : const [],
    creditAllocations: allocationsRaw is List
        ? allocationsRaw
              .map(
                (row) => ReturnCreditAllocation.fromJson(
                  Map<String, dynamic>.from(row as Map),
                ),
              )
              .toList()
        : const [],
  );
}

Decimal _parse(dynamic value) => parseDecimal(value);
