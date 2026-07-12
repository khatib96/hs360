import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/contracts/data/contract_rpc_mapper.dart';

void main() {
  group('contract_rpc_mapper', () {
    test('mapContractPricingPreview omits sensitive fields when absent', () {
      final preview = mapContractPricingPreview({
        'monthly_rental_value': '120.000',
        'passes_min_profit': false,
        'below_min_profit': true,
        'requires_override': true,
        'can_override': false,
        'asset_lines': [
          {'product_id': 'prod-1', 'product_unit_id': 'unit-1'},
        ],
        'consumable_lines': [
          {
            'product_id': 'oil-1',
            'qty_per_refill': '2.000',
            'refill_frequency_months': 1,
          },
        ],
      });

      expect(preview.monthlyRentalValue, Decimal.parse('120.000'));
      expect(preview.assetMonthlyCost, isNull);
      expect(preview.expectedMonthlyProfit, isNull);
      expect(preview.assetLines.single.monthlyCost, isNull);
      expect(preview.consumableLines.single.monthlyCost, isNull);
    });

    test('mapContractPricingPreview parses sensitive fields when present', () {
      final preview = mapContractPricingPreview({
        'monthly_rental_value': '120.000',
        'asset_monthly_cost': '40.000',
        'expected_monthly_profit': '80.000',
        'asset_lines': [
          {
            'product_id': 'prod-1',
            'product_unit_id': 'unit-1',
            'source_unit_cost': '800.000',
            'monthly_cost': '40.000',
          },
        ],
        'consumable_lines': const [],
      });

      expect(preview.assetMonthlyCost, Decimal.parse('40.000'));
      expect(preview.expectedMonthlyProfit, Decimal.parse('80.000'));
      expect(
        preview.assetLines.single.sourceUnitCost,
        Decimal.parse('800.000'),
      );
    });

    test('mapRentalCollectionResult parses collect payload', () {
      final result = mapRentalCollectionResult({
        'invoice_id': 'inv-1',
        'voucher_id': 'vch-1',
        'coverage_months': ['2026-07'],
        'invoice_total': '120.000',
        'collected_amount': '120.000',
      });

      expect(result.invoiceId, 'inv-1');
      expect(result.voucherId, 'vch-1');
      expect(result.coverageMonths, ['2026-07']);
      expect(result.invoiceTotal, Decimal.parse('120.000'));
    });

    test('mapContractDetail tolerates optional keys', () {
      final detail = mapContractDetail({
        'id': 'con-1',
        'contract_number': 'CON-001',
        'type': 'rental',
        'status': 'active',
        'start_date': '2026-07-01',
        'customer_id': 'cust-1',
        'service_location_id': 'loc-1',
        'monthly_rental_value': '120.000',
        'asset_lines': [
          {'id': 'line-1', 'product_id': 'prod-1', 'product_unit_id': 'unit-1'},
        ],
      });

      expect(detail.id, 'con-1');
      expect(detail.snapshotMonthlyProfit, isNull);
      expect(detail.assetLines, hasLength(1));
      expect(detail.consumableLines, isEmpty);
    });

    test('mapContractDetail parses customer and lifecycle fields', () {
      final detail = mapContractDetail({
        'id': 'con-2',
        'contract_number': 'CON-002',
        'type': 'trial',
        'status': 'completed',
        'start_date': '2026-06-01',
        'customer_id': 'cust-2',
        'customer_name_en': 'Acme Corp',
        'customer_name_ar': 'أكمة',
        'service_location_id': 'loc-2',
        'service_location_name': 'Main Site',
        'monthly_rental_value': '100.000',
        'renewed_from_contract_id': 'con-0',
        'renewed_at': '2026-06-15',
        'extension_reason': 'Customer request',
        'returned_at': '2026-07-01',
        'return_reason': 'Trial ended',
        'trial_outcome': 'not_converted',
        'asset_lines': const [],
        'consumable_lines': const [],
      });

      expect(detail.customerNameEn, 'Acme Corp');
      expect(detail.customerNameAr, 'أكمة');
      expect(detail.serviceLocationName, 'Main Site');
      expect(detail.renewedFromContractId, 'con-0');
      expect(detail.extensionReason, 'Customer request');
      expect(detail.returnReason, 'Trial ended');
      expect(detail.trialOutcome, 'not_converted');
    });

    test('mapContractDetail parses total_contract_value', () {
      final detail = mapContractDetail({
        'id': 'con-3',
        'contract_number': 'CON-003',
        'type': 'rental',
        'status': 'active',
        'start_date': '2026-07-01',
        'customer_id': 'cust-1',
        'monthly_rental_value': '120.000',
        'total_contract_value': '1440.000',
        'asset_lines': const [],
        'consumable_lines': const [],
      });

      expect(detail.totalContractValue, Decimal.parse('1440.000'));
    });

    test(
      'mapContractDetail parses consumable current and scheduled fields',
      () {
        final detail = mapContractDetail({
          'id': 'con-4',
          'contract_number': 'CON-004',
          'type': 'rental',
          'status': 'active',
          'start_date': '2026-07-01',
          'customer_id': 'cust-1',
          'monthly_rental_value': '120.000',
          'asset_lines': const [],
          'consumable_lines': [
            {
              'id': 'line-oil-1',
              'product_id': 'oil-template',
              'qty_per_refill': '500.000',
              'refill_frequency_months': 1,
              'current_oil_product_id': 'oil-a',
              'current_oil_product_name_en': 'Oil A',
              'current_qty_per_refill': '500.000',
              'current_effective_from': '2026-07-01',
              'scheduled_oil_product_id': 'oil-b',
              'scheduled_oil_product_name_en': 'Oil B',
              'scheduled_qty_per_refill': '700.000',
              'scheduled_effective_from': '2026-08-01',
            },
          ],
        });

        final line = detail.consumableLines.single;
        expect(line.currentOilProductId, 'oil-a');
        expect(line.currentOilProductNameEn, 'Oil A');
        expect(line.currentQtyPerRefill, Decimal.parse('500.000'));
        expect(line.currentEffectiveFrom, DateTime(2026, 7, 1));
        expect(line.scheduledOilProductId, 'oil-b');
        expect(line.scheduledOilProductNameEn, 'Oil B');
        expect(line.scheduledQtyPerRefill, Decimal.parse('700.000'));
        expect(line.scheduledEffectiveFrom, DateTime(2026, 8, 1));
        expect(line.snapshotUnitCost, isNull);
      },
    );

    test('mapContractDetail parses contact location and signature fields', () {
      final detail = mapContractDetail({
        'id': 'con-5',
        'contract_number': 'CON-005',
        'type': 'rental',
        'status': 'active',
        'start_date': '2026-07-01',
        'customer_id': 'cust-1',
        'contact_person_name': 'Sara',
        'contact_phone': '+965 5000 0000',
        'contact_email': 'sara@example.com',
        'location_governorate': 'Hawalli',
        'location_area': 'Salmiya',
        'signature_url': 'https://example.com/sig.png',
        'asset_lines': [
          {
            'id': 'line-1',
            'product_id': 'prod-1',
            'snapshot_unit_primary': 'piece',
          },
        ],
        'consumable_lines': const [],
      });

      expect(detail.contactPersonName, 'Sara');
      expect(detail.contactPhone, '+965 5000 0000');
      expect(detail.contactEmail, 'sara@example.com');
      expect(detail.locationGovernorate, 'Hawalli');
      expect(detail.locationArea, 'Salmiya');
      expect(detail.signatureUrl, 'https://example.com/sig.png');
      expect(detail.assetLines.single.snapshotUnitPrimary, 'piece');
    });
  });
}
