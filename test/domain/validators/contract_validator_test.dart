import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/domain/validators/contract_validator.dart';
import 'package:hs360/features/contracts/domain/contract_asset_line_draft.dart';
import 'package:hs360/features/contracts/domain/contract_draft.dart';
import 'package:hs360/features/contracts/domain/contract_type.dart';

void main() {
  final validator = ContractValidator();
  final startDate = DateTime(2026, 7, 1);

  ContractDraft rentalDraft({
    String? customerId = 'cust-1',
    String? serviceLocationId = 'loc-1',
    Decimal? monthlyRentalValue,
    List<ContractAssetLineDraft>? assetLines,
  }) {
    return ContractDraft(
      type: ContractType.rental,
      customerId: customerId,
      serviceLocationId: serviceLocationId,
      startDate: startDate,
      monthlyRentalValue: monthlyRentalValue ?? Decimal.fromInt(100),
      assetLines:
          assetLines ??
          const [
            ContractAssetLineDraft(
              productId: 'prod-1',
              productUnitId: 'unit-1',
            ),
          ],
    );
  }

  test('valid rental draft passes', () {
    expect(validator.validate(rentalDraft()).isValid, isTrue);
  });

  test('missing customer fails', () {
    final result = validator.validate(rentalDraft(customerId: null));
    expect(result.codes, contains(FinanceException.validationCustomerRequired));
  });

  test('missing service location fails', () {
    final result = validator.validate(rentalDraft(serviceLocationId: null));
    expect(
      result.codes,
      contains(FinanceException.validationServiceLocationRequired),
    );
  });

  test('missing asset lines fails', () {
    final result = validator.validate(rentalDraft(assetLines: const []));
    expect(
      result.codes,
      contains(FinanceException.validationAssetLinesRequired),
    );
  });

  test('serialized asset without unit fails', () {
    final result = validator.validate(
      rentalDraft(
        assetLines: const [
          ContractAssetLineDraft(productId: 'prod-1', productUnitId: ''),
        ],
      ),
    );
    expect(
      result.codes,
      contains(FinanceException.validationSerializedUnitRequired),
    );
  });

  test('invalid monthly rental value fails', () {
    final result = validator.validate(
      rentalDraft(monthlyRentalValue: Decimal.zero),
    );
    expect(
      result.codes,
      contains(FinanceException.validationMonthlyRentalInvalid),
    );
  });

  test('override without reason fails', () {
    final draft = rentalDraft().copyWithOverride(requestOverride: true);
    final result = validator.validate(draft);
    expect(
      result.codes,
      contains(FinanceException.validationOverrideReasonRequired),
    );
  });

  test('invalid billing day fails', () {
    final result = validator.validate(
      ContractDraft(
        type: ContractType.rental,
        customerId: 'cust-1',
        serviceLocationId: 'loc-1',
        startDate: startDate,
        monthlyRentalValue: Decimal.parse('100.000'),
        billingDay: 29,
        assetLines: const [
          ContractAssetLineDraft(productId: 'prod-1', productUnitId: 'unit-1'),
        ],
      ),
    );
    expect(
      result.codes,
      contains(FinanceException.validationBillingDayInvalid),
    );
  });
}

extension on ContractDraft {
  ContractDraft copyWithOverride({required bool requestOverride}) {
    return ContractDraft(
      type: type,
      customerId: customerId,
      serviceLocationId: serviceLocationId,
      startDate: startDate,
      monthlyRentalValue: monthlyRentalValue,
      requestOverride: requestOverride,
      assetLines: assetLines,
    );
  }
}
