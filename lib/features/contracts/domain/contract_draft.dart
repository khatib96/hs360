import 'package:decimal/decimal.dart';

import 'contract_asset_line_draft.dart';
import 'contract_consumable_line_draft.dart';
import 'contract_type.dart';

/// In-memory contract draft before create/preview RPCs.
class ContractDraft {
  const ContractDraft({
    required this.type,
    this.customerId,
    this.serviceLocationId,
    required this.startDate,
    this.endDate,
    this.billingDay,
    this.refillDay,
    this.trialDays,
    this.notes,
    this.monthlyRentalValue,
    this.requestOverride = false,
    this.overrideReason,
    this.assetLines = const [],
    this.consumableLines = const [],
  });

  final ContractType type;
  final String? customerId;
  final String? serviceLocationId;
  final DateTime startDate;
  final DateTime? endDate;
  final int? billingDay;
  final int? refillDay;
  final int? trialDays;
  final String? notes;
  final Decimal? monthlyRentalValue;
  final bool requestOverride;
  final String? overrideReason;
  final List<ContractAssetLineDraft> assetLines;
  final List<ContractConsumableLineDraft> consumableLines;

  Map<String, dynamic> toTrialPayload() => _basePayload();

  Map<String, dynamic> toRentalPayload() {
    final payload = _basePayload();
    if (monthlyRentalValue != null) {
      payload['monthly_rental_value'] = monthlyRentalValue!.toString();
    }
    if (requestOverride) {
      payload['request_override'] = true;
      if (overrideReason?.trim().isNotEmpty == true) {
        payload['override_reason'] = overrideReason!.trim();
      }
    }
    return payload;
  }

  /// Profit preview RPC payload (rental pricing path).
  Map<String, dynamic> toPreviewPayload() {
    return {
      'monthly_rental_value': (monthlyRentalValue ?? Decimal.zero).toString(),
      if (requestOverride) 'request_override': true,
      if (overrideReason?.trim().isNotEmpty == true)
        'override_reason': overrideReason!.trim(),
      'asset_lines': assetLines.map((l) => l.toPayload()).toList(),
      'consumable_lines': consumableLines.map((l) => l.toPayload()).toList(),
    };
  }

  Map<String, dynamic> _basePayload() {
    return {
      if (customerId?.trim().isNotEmpty == true) 'customer_id': customerId,
      if (serviceLocationId?.trim().isNotEmpty == true)
        'service_location_id': serviceLocationId,
      'start_date': _isoDate(startDate),
      if (endDate != null) 'end_date': _isoDate(endDate!),
      if (billingDay != null) 'billing_day': billingDay,
      if (refillDay != null) 'refill_day': refillDay,
      if (trialDays != null) 'trial_days': trialDays,
      if (notes?.trim().isNotEmpty == true) 'notes': notes!.trim(),
      'asset_lines': assetLines.map((l) => l.toPayload()).toList(),
      'consumable_lines': consumableLines.map((l) => l.toPayload()).toList(),
    };
  }
}

String _isoDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
