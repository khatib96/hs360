import 'package:decimal/decimal.dart';

/// Trial-to-rental conversion draft for `convert_trial_to_rental`.
class TrialConversionDraft {
  const TrialConversionDraft({
    required this.trialContractId,
    required this.monthlyRentalValue,
    this.endDate,
    this.billingDay,
    this.refillDay,
    this.requestOverride = false,
    this.overrideReason,
  });

  final String trialContractId;
  final Decimal monthlyRentalValue;
  final DateTime? endDate;
  final int? billingDay;
  final int? refillDay;
  final bool requestOverride;
  final String? overrideReason;

  Map<String, dynamic> toPayload() {
    return {
      'trial_contract_id': trialContractId,
      'monthly_rental_value': monthlyRentalValue.toString(),
      if (endDate != null) 'end_date': _isoDate(endDate!),
      if (billingDay != null) 'billing_day': billingDay,
      if (refillDay != null) 'refill_day': refillDay,
      if (requestOverride) 'request_override': true,
      if (overrideReason?.trim().isNotEmpty == true)
        'override_reason': overrideReason!.trim(),
    };
  }
}

String _isoDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
