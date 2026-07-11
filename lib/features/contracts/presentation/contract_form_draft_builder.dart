import '../domain/contract_asset_line_draft.dart';
import '../domain/contract_consumable_line_draft.dart';
import '../domain/contract_draft.dart';
import '../domain/contract_type.dart';
import 'contract_form_state.dart';

const contractDefaultRentalTermMonths = 12;

ContractDraft buildContractDraft(ContractFormUiState state) {
  return ContractDraft(
    type: state.type,
    customerId: state.customerId,
    serviceLocationId: state.serviceLocationId,
    startDate: state.startDate ?? DateTime.now(),
    endDate: state.endDate,
    billingDay: state.type == ContractType.rental ? state.billingDay : null,
    refillDay: state.type == ContractType.rental ? state.refillDay : null,
    trialDays: state.type == ContractType.trial ? state.trialDays : null,
    notes: state.notes.trim().isEmpty ? null : state.notes.trim(),
    monthlyRentalValue: state.type == ContractType.rental
        ? state.monthlyRentalValue
        : null,
    requestOverride: state.requestOverride,
    overrideReason: state.overrideReason.trim().isEmpty
        ? null
        : state.overrideReason.trim(),
    assetLines: [
      for (final line in state.assetLines)
        if (line.product != null)
          ContractAssetLineDraft(
            productId: line.product!.id,
            productUnitId: line.productUnitId,
          ),
    ],
    consumableLines: [
      for (final line in state.consumableLines)
        if (line.product != null)
          ContractConsumableLineDraft(
            productId: line.product!.id,
            qtyPerRefill: line.qtyPerRefill,
            refillFrequencyMonths: line.refillFrequencyMonths,
          ),
    ],
  );
}

Map<String, bool> serializedByProductIdFromContractLines(
  ContractFormUiState state,
) {
  final map = <String, bool>{};
  for (final line in state.assetLines) {
    final product = line.product;
    if (product != null) {
      map[product.id] = product.isSerialized;
    }
  }
  for (final line in state.consumableLines) {
    final product = line.product;
    if (product != null) {
      map[product.id] = product.isSerialized;
    }
  }
  return map;
}

DateTime? contractDraftEffectiveEndDate(ContractDraft draft) {
  if (draft.endDate != null) return draft.endDate;
  if (draft.type == ContractType.trial) {
    return draft.startDate.add(Duration(days: draft.trialDays ?? 30));
  }
  return _addMonths(draft.startDate, contractDefaultRentalTermMonths);
}

DateTime _addMonths(DateTime date, int months) {
  final monthIndex = date.month - 1 + months;
  final year = date.year + monthIndex ~/ 12;
  final month = monthIndex % 12 + 1;
  final day = date.day;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, day > lastDay ? lastDay : day);
}
