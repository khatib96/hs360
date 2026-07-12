import 'package:decimal/decimal.dart';

import '../../../core/documents/domain/document_payload.dart';
import '../presentation/contract_display_helpers.dart';
import 'contract_detail.dart';
import 'contract_document_payload_allowlist.dart';
import 'contract_line.dart';

ContractPayload mapContractDetailToCustomerPayload(ContractDetail detail) {
  final now = DateTime.now();
  final durationMonths = contractDurationMonths(detail);
  final totalValue = contractDisplayTotalValue(detail);

  final document = <String, dynamic>{
    'number': detail.contractNumber ?? '',
    'type': detail.type.toDb(),
    'status': detail.status.toDb(),
    'printed_at': _dateOnly(now),
    'start_date': _dateOnly(detail.startDate),
    if (detail.endDate != null) 'end_date': _dateOnly(detail.endDate!),
    if (detail.trialDays != null) 'trial_days': detail.trialDays,
    if (detail.trialEndDate != null)
      'trial_end_date': _dateOnly(detail.trialEndDate!),
    'duration_months': ?durationMonths,
    if (detail.billingDay != null) 'billing_day': detail.billingDay,
    if (detail.refillDay != null) 'refill_day': detail.refillDay,
    if (detail.notes != null && detail.notes!.trim().isNotEmpty)
      'notes': detail.notes,
    'is_draft': detail.status.isDraft,
  };

  final party = <String, dynamic>{
    'name_ar': detail.customerNameAr ?? '',
    'name_en': detail.customerNameEn ?? '',
    if (detail.contactPersonName != null &&
        detail.contactPersonName!.trim().isNotEmpty)
      'contact_person': detail.contactPersonName,
    if (detail.contactPhone != null && detail.contactPhone!.trim().isNotEmpty)
      'phone': detail.contactPhone,
    if (detail.contactEmail != null && detail.contactEmail!.trim().isNotEmpty)
      'email': detail.contactEmail,
  };

  final location = <String, dynamic>{
    if (detail.serviceLocationName != null &&
        detail.serviceLocationName!.trim().isNotEmpty)
      'name': detail.serviceLocationName,
    if (detail.locationGovernorate != null &&
        detail.locationGovernorate!.trim().isNotEmpty)
      'governorate': detail.locationGovernorate,
    if (detail.locationArea != null && detail.locationArea!.trim().isNotEmpty)
      'area': detail.locationArea,
  };

  final lines = <Map<String, dynamic>>[
    ...detail.assetLines.map(_mapAssetLine),
    ...detail.consumableLines.map(_mapConsumableLine),
  ]..sort((a, b) => (a['_order'] as int).compareTo(b['_order'] as int));

  for (final line in lines) {
    line.remove('_order');
  }

  final totals = <String, dynamic>{
    if (detail.monthlyRentalValue != null)
      'monthly_rental': detail.monthlyRentalValue,
    'total_value': ?totalValue,
    'is_trial': detail.type.isTrial,
  };

  final payload = ContractPayload(
    document: document,
    party: party,
    location: location,
    lines: lines,
    totals: totals,
    signatureUrl: detail.signatureUrl,
  );

  assertContractPayloadAllowlist({
    'document': payload.document,
    'party': payload.party,
    'location': payload.location,
    'lines': payload.lines,
    'totals': payload.totals,
  });

  return payload;
}

Map<String, dynamic> _mapAssetLine(ContractAssetLine line) {
  return {
    '_order': line.lineOrder,
    'product_name': _productName(line.productNameAr, line.productNameEn),
    'serial': line.serialNumber ?? '',
    'qty': Decimal.one,
    'unit': line.snapshotUnitPrimary ?? '',
  };
}

Map<String, dynamic> _mapConsumableLine(ContractConsumableLine line) {
  return {
    '_order': line.lineOrder,
    'product_name': _productName(line.productNameAr, line.productNameEn),
    'serial': '',
    'qty': line.qtyPerRefill ?? Decimal.zero,
    'unit': line.snapshotUnitPrimary ?? '',
  };
}

String _productName(String? nameAr, String? nameEn) {
  final ar = nameAr?.trim() ?? '';
  final en = nameEn?.trim() ?? '';
  if (ar.isNotEmpty && en.isNotEmpty && ar != en) {
    return '$ar\n$en';
  }
  return en.isNotEmpty ? en : ar;
}

String _dateOnly(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
