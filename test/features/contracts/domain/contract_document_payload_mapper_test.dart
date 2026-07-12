import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/domain/document_payload.dart';
import 'package:hs360/core/documents/services/document_render_dto.dart';
import 'package:hs360/features/contracts/domain/contract_detail.dart';
import 'package:hs360/features/contracts/domain/contract_document_payload_allowlist.dart';
import 'package:hs360/features/contracts/domain/contract_document_payload_mapper.dart';
import 'package:hs360/features/contracts/domain/contract_line.dart';
import 'package:hs360/features/contracts/domain/contract_status.dart';
import 'package:hs360/features/contracts/domain/contract_type.dart';

ContractDetail _detail({
  ContractType type = ContractType.rental,
  ContractStatus status = ContractStatus.active,
  bool richInternalFields = false,
}) {
  return ContractDetail(
    id: 'con-1',
    contractNumber: 'CON-001',
    type: type,
    status: status,
    customerId: richInternalFields ? 'cust-internal' : null,
    customerNameAr: 'عميل',
    customerNameEn: 'Customer',
    serviceLocationId: richInternalFields ? 'loc-internal' : null,
    contactPersonName: 'Sara',
    contactPhone: '+965 5000 0000',
    contactEmail: 'sara@example.com',
    serviceLocationName: 'Main Site',
    locationGovernorate: 'Hawalli',
    locationArea: 'Salmiya',
    signatureUrl: richInternalFields ? 'https://example.com/sig.png' : null,
    startDate: DateTime(2026, 7, 1),
    endDate: DateTime(2027, 7, 1),
    monthlyRentalValue: type.isTrial ? null : Decimal.parse('120.000'),
    totalContractValue: type.isTrial ? null : Decimal.parse('1440.000'),
    snapshotDeviceMonthlyCost: richInternalFields
        ? Decimal.parse('40.000')
        : null,
    snapshotOilMonthlyCost: richInternalFields ? Decimal.parse('20.000') : null,
    snapshotTotalMonthlyCost: richInternalFields
        ? Decimal.parse('60.000')
        : null,
    snapshotMonthlyProfit: richInternalFields ? Decimal.parse('60.000') : null,
    minProfitOverridden: richInternalFields,
    overrideReason: richInternalFields ? 'manager override' : null,
    assetLines: [
      ContractAssetLine(
        id: 'line-1',
        productId: 'prod-1',
        lineOrder: 0,
        productNameEn: 'Device',
        productSku: richInternalFields ? 'SKU-001' : null,
        productGroupNameEn: richInternalFields ? 'Group' : null,
        serialNumber: 'SN-001',
        snapshotUnitCost: richInternalFields ? Decimal.parse('100.000') : null,
        snapshotMonthlyCost: richInternalFields
            ? Decimal.parse('40.000')
            : null,
        snapshotUnitPrimary: 'piece',
      ),
    ],
    consumableLines: [
      ContractConsumableLine(
        id: 'line-2',
        productId: 'oil-1',
        lineOrder: 1,
        productNameEn: 'Oil',
        refillFrequencyMonths: richInternalFields ? 3 : null,
        qtyPerRefill: Decimal.parse('500'),
        snapshotUnitPrimary: 'ml',
        currentOilProductId: richInternalFields ? 'oil-current' : null,
        scheduledOilProductId: richInternalFields ? 'oil-scheduled' : null,
      ),
    ],
  );
}

Set<String> _collectKeys(Object? value, [String prefix = '']) {
  final keys = <String>{};
  if (value is Map) {
    for (final entry in value.entries) {
      final key = prefix.isEmpty ? '${entry.key}' : '$prefix.${entry.key}';
      keys.add(entry.key as String);
      keys.addAll(_collectKeys(entry.value, key));
    }
  } else if (value is List) {
    for (final item in value) {
      keys.addAll(_collectKeys(item, prefix));
    }
  }
  return keys;
}

void _assertCustomerPayloadPrivacy(ContractPayload payload) {
  final tree = {
    'document': payload.document,
    'party': payload.party,
    'location': payload.location,
    'lines': payload.lines,
    'totals': payload.totals,
    if (payload.signatureUrl != null) 'signature': payload.signatureUrl,
  };

  for (final key in _collectKeys(tree)) {
    expect(
      kForbiddenContractPayloadKeys.contains(key),
      isFalse,
      reason: 'forbidden key leaked: $key',
    );
  }

  for (final key in payload.totals.keys) {
    expect(kAllowedContractTotalsKeys, contains(key));
  }

  for (final line in payload.lines) {
    expect(line.keys.toSet(), kAllowedContractLineKeys);
  }
}

void main() {
  test('maps contract detail to customer payload with renderer keys', () {
    final payload = mapContractDetailToCustomerPayload(_detail());

    expect(payload, isA<ContractPayload>());
    expect(payload.kind, DocumentKind.contract);
    expect(payload.document['number'], 'CON-001');
    expect(payload.document['type'], 'rental');
    expect(payload.document['status'], 'active');
    expect(payload.document['is_draft'], isFalse);
    expect(payload.party['name_en'], 'Customer');
    expect(payload.party['contact_person'], 'Sara');
    expect(payload.location['name'], 'Main Site');
    expect(payload.location['governorate'], 'Hawalli');

    expect(payload.lines, hasLength(2));
    final assetLine = payload.lines.first;
    expect(
      assetLine.keys,
      containsAll(['product_name', 'serial', 'qty', 'unit']),
    );
    expect(assetLine.containsKey('product_id'), isFalse);
    expect(assetLine.containsKey('snapshot_unit_cost'), isFalse);
    expect(assetLine['serial'], 'SN-001');
    expect(assetLine['unit'], 'piece');

    final consumableLine = payload.lines.last;
    expect(consumableLine['serial'], '');
    expect(consumableLine['qty'], Decimal.parse('500'));
    expect(consumableLine['unit'], 'ml');

    expect(payload.totals['monthly_rental'], Decimal.parse('120.000'));
    expect(payload.totals['total_value'], Decimal.parse('1440.000'));
    expect(payload.totals['is_trial'], isFalse);
    expect(payload.totals.containsKey('snapshot_monthly_profit'), isFalse);

    _assertCustomerPayloadPrivacy(payload);
  });

  test('manager-visible internal costs do not leak into customer payload', () {
    final payload = mapContractDetailToCustomerPayload(
      _detail(richInternalFields: true),
    );

    _assertCustomerPayloadPrivacy(payload);
    expect(payload.totals.containsKey('monthly_rental'), isTrue);
    expect(payload.totals.containsKey('snapshot_monthly_profit'), isFalse);
    expect(payload.lines.first.containsKey('snapshot_unit_cost'), isFalse);
    expect(payload.lines.first.containsKey('product_sku'), isFalse);
    expect(payload.lines.first.containsKey('refill_frequency_months'), isFalse);
    expect(payload.signatureUrl, 'https://example.com/sig.png');
  });

  test('signature URL is not copied into the renderer payload JSON', () {
    final payload = mapContractDetailToCustomerPayload(
      _detail(richInternalFields: true),
    );

    final serialized = serializePayload(payload);

    expect(payload.signatureUrl, isNotNull);
    expect(serialized.containsKey('signature_url'), isFalse);
  });

  test('uses snapshot_unit_primary on lines not live product unit', () {
    final payload = mapContractDetailToCustomerPayload(
      ContractDetail(
        id: 'con-2',
        type: ContractType.rental,
        status: ContractStatus.active,
        startDate: DateTime(2026, 1, 1),
        assetLines: [
          ContractAssetLine(
            id: 'line-1',
            productId: 'prod-1',
            lineOrder: 0,
            productNameEn: 'Device',
            snapshotUnitPrimary: 'liter',
          ),
        ],
      ),
    );

    expect(payload.lines.single['unit'], 'liter');
    expect(payload.lines.single.containsKey('snapshot_unit_primary'), isFalse);
  });

  test('marks trial contracts and draft status without rental totals', () {
    final trial = mapContractDetailToCustomerPayload(
      _detail(type: ContractType.trial, status: ContractStatus.draft),
    );

    expect(trial.document['is_draft'], isTrue);
    expect(trial.totals['is_trial'], isTrue);
    expect(trial.totals.containsKey('monthly_rental'), isFalse);
    expect(trial.totals.containsKey('total_value'), isFalse);
    _assertCustomerPayloadPrivacy(trial);
  });
}
