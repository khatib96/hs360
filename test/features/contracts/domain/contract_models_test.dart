import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/contracts/domain/contract_asset_line_draft.dart';
import 'package:hs360/features/contracts/domain/contract_draft.dart';
import 'package:hs360/features/contracts/domain/contract_status.dart';
import 'package:hs360/features/contracts/domain/contract_summary.dart';
import 'package:hs360/features/contracts/domain/contract_type.dart';
import 'package:hs360/features/contracts/domain/trial_conversion_draft.dart';

void main() {
  group('ContractType', () {
    test('round-trips db values', () {
      expect(ContractType.trial.toDb(), 'trial');
      expect(ContractType.fromDb('rental'), ContractType.rental);
    });
  });

  group('ContractStatus', () {
    test('parses terminated_early', () {
      expect(
        ContractStatus.fromDb('terminated_early'),
        ContractStatus.terminatedEarly,
      );
    });
  });

  group('ContractDraft payloads', () {
    test('rental payload uses string money', () {
      final payload = ContractDraft(
        type: ContractType.rental,
        customerId: 'cust-1',
        serviceLocationId: 'loc-1',
        startDate: DateTime(2026, 7, 1),
        monthlyRentalValue: Decimal.parse('150.000'),
        assetLines: const [
          ContractAssetLineDraft(productId: 'prod-1', productUnitId: 'unit-1'),
        ],
      ).toRentalPayload();

      expect(payload['monthly_rental_value'], '150');
      expect(payload['asset_lines'], isA<List>());
    });

    test('conversion payload includes trial id', () {
      final payload = TrialConversionDraft(
        trialContractId: 'trial-1',
        monthlyRentalValue: Decimal.fromInt(200),
      ).toPayload();

      expect(payload['trial_contract_id'], 'trial-1');
      expect(payload['monthly_rental_value'], '200');
    });
  });

  group('ContractSummary', () {
    test('parses list row', () {
      final summary = ContractSummary.fromListRow({
        'id': 'con-1',
        'contract_number': 'CON-001',
        'type': 'rental',
        'status': 'active',
        'start_date': '2026-07-01',
        'end_date': '2027-07-01',
        'customer_id': 'cust-1',
        'customer_name_ar': 'عميل',
        'customer_name_en': 'Customer',
        'service_location_id': 'loc-1',
        'monthly_rental_value': '120.000',
        'min_profit_overridden': false,
      });

      expect(summary.type, ContractType.rental);
      expect(summary.status, ContractStatus.active);
      expect(summary.monthlyRentalValue, Decimal.parse('120.000'));
    });
  });
}
