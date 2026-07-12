import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/contracts/domain/contract_detail.dart';
import 'package:hs360/features/contracts/domain/contract_rental_collection_months.dart';
import 'package:hs360/features/contracts/domain/contract_status.dart';
import 'package:hs360/features/contracts/domain/contract_type.dart';

ContractDetail _rental({
  ContractStatus status = ContractStatus.active,
  DateTime? startDate,
  DateTime? endDate,
  DateTime? closedAt,
}) {
  return ContractDetail(
    id: 'rental-1',
    type: ContractType.rental,
    status: status,
    startDate: startDate ?? DateTime(2026, 7, 1),
    endDate: endDate,
    closedAt: closedAt,
    monthlyRentalValue: null,
  );
}

void main() {
  group('ContractRentalCollectionMonths', () {
    test('excludes covered month keys', () {
      final detail = _rental(endDate: DateTime(2026, 9, 30));
      final keys = ContractRentalCollectionMonths.buildEligibleMonthKeys(
        detail: detail,
        coveredMonthKeys: {'2026-07-01'},
        now: DateTime(2026, 7, 15),
      );

      expect(keys, contains('2026-08-01'));
      expect(keys, contains('2026-09-01'));
      expect(keys, isNot(contains('2026-07-01')));
    });

    test('allows prepay future month within fixed end date', () {
      final detail = _rental(
        startDate: DateTime(2026, 7, 1),
        endDate: DateTime(2027, 6, 30),
      );
      final keys = ContractRentalCollectionMonths.buildEligibleMonthKeys(
        detail: detail,
        coveredMonthKeys: const {},
        now: DateTime(2026, 7, 12),
      );

      expect(keys, contains('2026-08-01'));
      expect(keys, contains('2027-06-01'));
      expect(keys, isNot(contains('2027-07-01')));
    });

    test('terminal contract caps months at effective close date', () {
      final detail = _rental(
        status: ContractStatus.completed,
        startDate: DateTime(2026, 1, 1),
        endDate: DateTime(2026, 12, 31),
        closedAt: DateTime(2026, 3, 15),
      );
      final keys = ContractRentalCollectionMonths.buildEligibleMonthKeys(
        detail: detail,
        coveredMonthKeys: const {},
        now: DateTime(2026, 7, 12),
      );

      expect(keys, contains('2026-03-01'));
      expect(keys, isNot(contains('2026-04-01')));
    });

    test('open-ended contract caps display at current month plus twelve', () {
      final detail = _rental(startDate: DateTime(2026, 1, 1));
      final now = DateTime(2026, 7, 12);
      final keys = ContractRentalCollectionMonths.buildEligibleMonthKeys(
        detail: detail,
        coveredMonthKeys: const {},
        now: now,
      );

      expect(keys.first, '2026-01-01');
      expect(keys.last, '2027-07-01');
      expect(keys, isNot(contains('2027-08-01')));
    });
  });
}
