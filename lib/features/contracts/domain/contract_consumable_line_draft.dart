import 'package:decimal/decimal.dart';

/// Editable consumable line for contract creation payloads.
class ContractConsumableLineDraft {
  const ContractConsumableLineDraft({
    required this.productId,
    required this.qtyPerRefill,
    this.refillFrequencyMonths = 1,
  });

  final String productId;
  final Decimal qtyPerRefill;
  final int refillFrequencyMonths;

  Map<String, dynamic> toPayload() {
    return {
      'product_id': productId,
      'qty_per_refill': qtyPerRefill.toString(),
      'refill_frequency_months': refillFrequencyMonths,
    };
  }
}
