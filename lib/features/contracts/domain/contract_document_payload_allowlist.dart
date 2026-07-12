/// Customer-facing contract PDF payload allowlists (M11).
const kAllowedContractLineKeys = {'product_name', 'serial', 'qty', 'unit'};

const kAllowedContractTotalsKeys = {
  'monthly_rental',
  'total_value',
  'is_trial',
};

const kForbiddenContractPayloadKeys = {
  'snapshot_device_monthly_cost',
  'snapshot_oil_monthly_cost',
  'snapshot_total_monthly_cost',
  'snapshot_monthly_profit',
  'snapshot_min_profit_threshold',
  'snapshot_asset_cost_basis',
  'snapshot_consumable_cost_basis',
  'snapshot_asset_lifespan_months',
  'snapshot_unit_cost',
  'snapshot_monthly_cost',
  'snapshot_unit_primary',
  'product_id',
  'product_unit_id',
  'product_sku',
  'product_name_ar',
  'product_name_en',
  'product_group_name_ar',
  'product_group_name_en',
  'line_order',
  'line_type',
  'refill_frequency_months',
  'current_oil_product_id',
  'scheduled_oil_product_id',
  'min_profit_overridden',
  'override_reason',
  'converted_from_contract_id',
  'converted_to_contract_id',
  'renewed_from_contract_id',
  'renewed_to_contract_id',
  'customer_id',
  'service_location_id',
  'signature_url',
};

void assertContractPayloadAllowlist(Map<String, dynamic> payload) {
  for (final key in payload.keys) {
    if (kForbiddenContractPayloadKeys.contains(key)) {
      throw StateError('forbidden contract payload key: $key');
    }
  }

  final document = payload['document'];
  if (document is Map) {
    for (final key in document.keys) {
      if (kForbiddenContractPayloadKeys.contains(key)) {
        throw StateError('forbidden contract document key: $key');
      }
    }
  }

  final party = payload['party'];
  if (party is Map) {
    for (final key in party.keys) {
      if (kForbiddenContractPayloadKeys.contains(key)) {
        throw StateError('forbidden contract party key: $key');
      }
    }
  }

  final location = payload['location'];
  if (location is Map) {
    for (final key in location.keys) {
      if (kForbiddenContractPayloadKeys.contains(key)) {
        throw StateError('forbidden contract location key: $key');
      }
    }
  }

  final totals = payload['totals'];
  if (totals is Map) {
    for (final key in totals.keys) {
      if (!kAllowedContractTotalsKeys.contains(key)) {
        throw StateError('forbidden contract totals key: $key');
      }
    }
  }

  final lines = payload['lines'];
  if (lines is List) {
    for (final line in lines) {
      if (line is! Map) {
        throw StateError('contract line must be a map');
      }
      for (final key in line.keys) {
        if (!kAllowedContractLineKeys.contains(key)) {
          throw StateError('forbidden contract line key: $key');
        }
      }
    }
  }
}
