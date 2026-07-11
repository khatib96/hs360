import 'package:decimal/decimal.dart';

import '../domain/contract_asset_line_draft.dart';
import '../domain/contract_consumable_line_draft.dart';
import '../domain/contract_detail.dart';
import '../domain/contract_draft.dart';
import '../domain/contract_type.dart';
import '../domain/trial_conversion_draft.dart';
import 'contract_form_draft_builder.dart';

DateTime normalizeConversionStartDate([DateTime? now]) {
  final date = now ?? DateTime.now();
  return DateTime(date.year, date.month, date.day);
}

ContractDraft buildConversionPreviewDraft({
  required ContractDetail trialDetail,
  required DateTime conversionStartDate,
  required Decimal monthlyRentalValue,
  DateTime? endDate,
  int? billingDay,
  int? refillDay,
  bool requestOverride = false,
  String? overrideReason,
}) {
  return ContractDraft(
    type: ContractType.rental,
    customerId: trialDetail.customerId,
    serviceLocationId: trialDetail.serviceLocationId,
    startDate: conversionStartDate,
    endDate: endDate ?? defaultConversionEndDate(conversionStartDate),
    billingDay: billingDay,
    refillDay: refillDay,
    monthlyRentalValue: monthlyRentalValue,
    requestOverride: requestOverride,
    overrideReason: overrideReason,
    assetLines: [
      for (final line in trialDetail.assetLines)
        ContractAssetLineDraft(
          productId: line.productId,
          productUnitId: line.productUnitId,
        ),
    ],
    consumableLines: [
      for (final line in trialDetail.consumableLines)
        ContractConsumableLineDraft(
          productId: line.productId,
          qtyPerRefill:
              line.qtyPerRefill ?? line.currentQtyPerRefill ?? Decimal.one,
          refillFrequencyMonths: line.refillFrequencyMonths ?? 1,
        ),
    ],
  );
}

TrialConversionDraft buildTrialConversionDraft({
  required String trialContractId,
  required Decimal monthlyRentalValue,
  DateTime? endDate,
  int? billingDay,
  int? refillDay,
  bool requestOverride = false,
  String? overrideReason,
}) {
  return TrialConversionDraft(
    trialContractId: trialContractId,
    monthlyRentalValue: monthlyRentalValue,
    endDate: endDate,
    billingDay: billingDay,
    refillDay: refillDay,
    requestOverride: requestOverride,
    overrideReason: overrideReason,
  );
}

int defaultCycleDay(DateTime date) => date.day > 28 ? 28 : date.day;

DateTime defaultConversionEndDate(DateTime conversionStartDate) =>
    _addMonths(conversionStartDate, contractDefaultRentalTermMonths);

DateTime _addMonths(DateTime date, int months) {
  final monthIndex = date.month - 1 + months;
  final year = date.year + monthIndex ~/ 12;
  final month = monthIndex % 12 + 1;
  final day = date.day;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, day > lastDay ? lastDay : day);
}
