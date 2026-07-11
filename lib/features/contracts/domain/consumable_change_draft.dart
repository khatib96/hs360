import 'package:decimal/decimal.dart';

/// Consumable change draft for `schedule_contract_consumable_change`.
class ConsumableChangeDraft {
  const ConsumableChangeDraft({
    required this.contractId,
    required this.contractLineId,
    required this.newProductId,
    required this.effectiveDate,
    required this.qtyPerRefill,
    required this.reason,
  });

  final String contractId;
  final String contractLineId;
  final String newProductId;
  final DateTime effectiveDate;
  final Decimal qtyPerRefill;
  final String reason;

  Map<String, dynamic> toPayload() {
    return {
      'contract_id': contractId,
      'contract_line_id': contractLineId,
      'new_product_id': newProductId,
      'effective_date': _isoDate(effectiveDate),
      'qty_per_refill': qtyPerRefill.toString(),
      'reason': reason.trim(),
    };
  }
}

String _isoDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
