import 'package:decimal/decimal.dart';

import '../../../core/utils/decimal_parser.dart';
import 'invoice_type.dart';

/// Confirmed return invoice with remaining party credit.
class PartyCredit {
  const PartyCredit({
    required this.returnInvoiceId,
    this.returnInvoiceNumber,
    required this.returnType,
    required this.returnDate,
    this.originalInvoiceId,
    this.originalInvoiceNumber,
    required this.total,
    required this.creditRemaining,
  });

  final String returnInvoiceId;
  final String? returnInvoiceNumber;
  final InvoiceType returnType;
  final DateTime returnDate;
  final String? originalInvoiceId;
  final String? originalInvoiceNumber;
  final Decimal total;
  final Decimal creditRemaining;

  factory PartyCredit.fromListRow(Map<String, dynamic> row) {
    return PartyCredit(
      returnInvoiceId: row['return_invoice_id'] as String,
      returnInvoiceNumber: row['return_invoice_number'] as String?,
      returnType: InvoiceType.fromDb(row['return_type'] as String?),
      returnDate: DateTime.parse(row['return_date'] as String),
      originalInvoiceId: row['original_invoice_id'] as String?,
      originalInvoiceNumber: row['original_invoice_number'] as String?,
      total: parseDecimal(row['total']),
      creditRemaining: parseDecimal(row['credit_remaining']),
    );
  }
}
