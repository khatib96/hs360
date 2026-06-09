import '../../../core/documents/domain/document_payload.dart';
import '../domain/customer_balance_summary.dart';
import '../domain/customer_statement_row.dart';

/// Maps live customer statement UI data to a print payload for preview.
StatementPayload mapCustomerStatementToDocumentPayload({
  required String customerId,
  required Map<String, dynamic> customer,
  required List<CustomerStatementRow> rows,
  required CustomerBalanceSummary summary,
  DateTime? fromDate,
  DateTime? toDate,
}) {
  final now = DateTime.now();
  final from = fromDate ?? DateTime(now.year, 1, 1);
  final to = toDate ?? now;

  return StatementPayload(
    customer: customer,
    fromDate: from,
    toDate: to,
    generatedAt: now,
    summary: StatementSummary(
      openingBalance:
          summary.balance - summary.debitTotal + summary.creditTotal,
      totalDebit: summary.debitTotal,
      totalCredit: summary.creditTotal,
      closingBalance: summary.balance,
    ),
    lines: rows
        .map(
          (row) => StatementLine(
            entryDate: row.entryDate,
            entryNumber: row.entryNumber,
            source: row.source.dbValue,
            description: row.description,
            debit: row.debit,
            credit: row.credit,
            runningBalance: row.runningBalance,
          ),
        )
        .toList(),
    rowCount: rows.length,
  );
}

Map<String, dynamic> customerHeaderFromDetail({
  required String id,
  required String code,
  required String nameAr,
  required String nameEn,
}) {
  return {'id': id, 'code': code, 'name_ar': nameAr, 'name_en': nameEn};
}
