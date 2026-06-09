import 'package:decimal/decimal.dart';

import '../../../core/utils/decimal_parser.dart';
import 'document_kind.dart';

/// Base type for server-provided print payloads.
sealed class DocumentPayload {
  const DocumentPayload();

  DocumentKind get kind;
}

class StatementPayload extends DocumentPayload {
  const StatementPayload({
    required this.customer,
    required this.fromDate,
    required this.toDate,
    required this.generatedAt,
    required this.summary,
    required this.lines,
    required this.rowCount,
    this.notes,
  });

  final Map<String, dynamic> customer;
  final DateTime fromDate;
  final DateTime toDate;
  final DateTime generatedAt;
  final StatementSummary summary;
  final List<StatementLine> lines;
  final int rowCount;
  final String? notes;

  @override
  DocumentKind get kind => DocumentKind.customerStatement;

  factory StatementPayload.fromRpc(Map<String, dynamic> json) {
    final linesRaw = json['lines'];
    return StatementPayload(
      customer: Map<String, dynamic>.from(json['customer'] as Map),
      fromDate: DateTime.parse(json['from_date'] as String),
      toDate: DateTime.parse(json['to_date'] as String),
      generatedAt: DateTime.parse(json['generated_at'] as String),
      summary: StatementSummary.fromJson(
        Map<String, dynamic>.from(json['summary'] as Map),
      ),
      lines: linesRaw is List
          ? linesRaw
                .map(
                  (l) => StatementLine.fromJson(
                    Map<String, dynamic>.from(l as Map),
                  ),
                )
                .toList()
          : const [],
      rowCount: json['row_count'] as int? ?? 0,
      notes: json['notes'] as String?,
    );
  }
}

class StatementSummary {
  const StatementSummary({
    required this.openingBalance,
    required this.totalDebit,
    required this.totalCredit,
    required this.closingBalance,
  });

  final Decimal openingBalance;
  final Decimal totalDebit;
  final Decimal totalCredit;
  final Decimal closingBalance;

  factory StatementSummary.fromJson(Map<String, dynamic> json) {
    return StatementSummary(
      openingBalance: parseDecimal(json['opening_balance']),
      totalDebit: parseDecimal(json['total_debit']),
      totalCredit: parseDecimal(json['total_credit']),
      closingBalance: parseDecimal(json['closing_balance']),
    );
  }
}

class StatementLine {
  const StatementLine({
    required this.entryDate,
    required this.entryNumber,
    required this.source,
    required this.description,
    required this.debit,
    required this.credit,
    required this.runningBalance,
  });

  final DateTime entryDate;
  final String entryNumber;
  final String source;
  final String? description;
  final Decimal debit;
  final Decimal credit;
  final Decimal runningBalance;

  factory StatementLine.fromJson(Map<String, dynamic> json) {
    return StatementLine(
      entryDate: DateTime.parse(json['entry_date'] as String),
      entryNumber: json['entry_number'] as String? ?? '',
      source: json['source'] as String? ?? '',
      description: json['description'] as String?,
      debit: parseDecimal(json['debit']),
      credit: parseDecimal(json['credit']),
      runningBalance: parseDecimal(json['running_balance']),
    );
  }
}

class AssetLabelPayload extends DocumentPayload {
  const AssetLabelPayload({
    required this.unit,
    required this.product,
    required this.tenant,
  });

  final Map<String, dynamic> unit;
  final Map<String, dynamic> product;
  final Map<String, dynamic> tenant;

  @override
  DocumentKind get kind => DocumentKind.assetTagLabel;

  factory AssetLabelPayload.fromRpc(Map<String, dynamic> json) {
    return AssetLabelPayload(
      unit: Map<String, dynamic>.from(json['unit'] as Map),
      product: Map<String, dynamic>.from(json['product'] as Map),
      tenant: Map<String, dynamic>.from(json['tenant'] as Map),
    );
  }
}

/// Fixture payload for invoice renderer smoke tests (M3 — no live invoice RPC yet).
class InvoicePayload extends DocumentPayload {
  const InvoicePayload({
    required this.documentType,
    required this.document,
    required this.party,
    required this.lines,
    required this.totals,
  });

  final DocumentKind documentType;
  final Map<String, dynamic> document;
  final Map<String, dynamic> party;
  final List<Map<String, dynamic>> lines;
  final Map<String, dynamic> totals;

  @override
  DocumentKind get kind => documentType;
}

/// Fixture payload for voucher renderer smoke tests (M3 — no live voucher RPC yet).
class VoucherPayload extends DocumentPayload {
  const VoucherPayload({
    required this.documentType,
    required this.document,
    required this.party,
    required this.payment,
  });

  final DocumentKind documentType;
  final Map<String, dynamic> document;
  final Map<String, dynamic> party;
  final Map<String, dynamic> payment;

  @override
  DocumentKind get kind => documentType;
}
