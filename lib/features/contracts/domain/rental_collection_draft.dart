import 'package:decimal/decimal.dart';

import '../../../core/utils/decimal_parser.dart';
import '../../finance_shared/domain/payment_method.dart';

/// Rental collection input for preview/collect RPCs.
class RentalCollectionDraft {
  const RentalCollectionDraft({
    required this.contractId,
    required this.date,
    required this.amount,
    required this.paymentMethod,
    required this.cashAccountId,
    this.coverageMonths = const [],
    this.coverageStart,
    this.coverageEnd,
    this.notes,
    this.referenceNo,
  });

  final String contractId;
  final DateTime date;
  final Decimal amount;
  final PaymentMethod paymentMethod;
  final String cashAccountId;
  final List<String> coverageMonths;
  final DateTime? coverageStart;
  final DateTime? coverageEnd;
  final String? notes;
  final String? referenceNo;

  Map<String, dynamic> toPayload() {
    final payload = <String, dynamic>{
      'contract_id': contractId,
      'date': _isoDate(date),
      'amount': amount.toString(),
      'payment_method': paymentMethod.toDb(),
      'cash_account_id': cashAccountId,
    };

    if (coverageMonths.isNotEmpty) {
      payload['coverage_months'] = coverageMonths;
    } else if (coverageStart != null && coverageEnd != null) {
      payload['coverage_start'] = _isoDate(coverageStart!);
      payload['coverage_end'] = _isoDate(coverageEnd!);
    }

    if (notes?.trim().isNotEmpty == true) {
      payload['notes'] = notes!.trim();
    }
    if (referenceNo?.trim().isNotEmpty == true) {
      payload['reference_no'] = referenceNo!.trim();
    }

    return payload;
  }
}

/// Read-only rental collection preview from `preview_rental_collection`.
class RentalCollectionPreview {
  const RentalCollectionPreview({
    required this.contractId,
    this.contractNumber,
    this.coverageMonths = const [],
    this.lineCount = 0,
    this.subtotal,
    this.taxAmount,
    this.invoiceTotal,
    this.expectedCollectedAmount,
    this.taxPolicy,
  });

  final String contractId;
  final String? contractNumber;
  final List<String> coverageMonths;
  final int lineCount;
  final Decimal? subtotal;
  final Decimal? taxAmount;
  final Decimal? invoiceTotal;
  final Decimal? expectedCollectedAmount;
  final String? taxPolicy;

  factory RentalCollectionPreview.fromRpcJson(Map<String, dynamic> json) {
    final monthsRaw = json['coverage_months'];
    final months = monthsRaw is List
        ? monthsRaw.map((m) => m.toString()).toList()
        : const <String>[];

    return RentalCollectionPreview(
      contractId: json['contract_id'] as String,
      contractNumber: json['contract_number'] as String?,
      coverageMonths: months,
      lineCount: json['line_count'] as int? ?? months.length,
      subtotal: tryParseDecimal(json['subtotal']),
      taxAmount: tryParseDecimal(json['tax_amount']),
      invoiceTotal: tryParseDecimal(json['invoice_total']),
      expectedCollectedAmount: tryParseDecimal(
        json['expected_collected_amount'],
      ),
      taxPolicy: json['tax_policy'] as String?,
    );
  }
}

/// Confirmed rental collection result from `collect_rental_payment`.
class RentalCollectionResult {
  const RentalCollectionResult({
    required this.invoiceId,
    required this.voucherId,
    this.coverageMonths = const [],
    this.invoiceTotal,
    this.collectedAmount,
  });

  final String invoiceId;
  final String voucherId;
  final List<String> coverageMonths;
  final Decimal? invoiceTotal;
  final Decimal? collectedAmount;
}

String _isoDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
