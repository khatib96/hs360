import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/contracts/domain/contract_detail.dart';
import 'package:hs360/features/contracts/domain/contract_status.dart';
import 'package:hs360/features/contracts/domain/contract_type.dart';
import 'package:hs360/features/contracts/presentation/contract_display_helpers.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../fake_contract_repository.dart';

void main() {
  group('billingMonthsBetween', () {
    test('one year equals 12 months', () {
      expect(
        billingMonthsBetween(DateTime(2026, 7, 9), DateTime(2027, 7, 9)),
        12,
      );
    });

    test('returns null when end is before start', () {
      expect(
        billingMonthsBetween(DateTime(2027, 7, 9), DateTime(2026, 7, 9)),
        isNull,
      );
    });
  });

  group('contractDurationMonths', () {
    test('uses end date for rental contracts', () {
      final detail = sampleContractDetail();
      expect(contractDurationMonths(detail), 12);
    });

    test('uses trial end when rental end is absent', () {
      final detail = ContractDetail(
        id: 'trial-1',
        type: ContractType.trial,
        status: ContractStatus.active,
        startDate: DateTime(2026, 7, 9),
        trialEndDate: DateTime(2026, 8, 9),
      );
      expect(contractDurationMonths(detail), 1);
    });
  });

  group('contractDisplayTotalValue', () {
    test('prefers stored total contract value', () {
      final detail = sampleContractDetail(
        totalContractValue: Decimal.parse('999.000'),
      );
      expect(contractDisplayTotalValue(detail), Decimal.parse('999.000'));
    });

    test('falls back to monthly times duration', () {
      final detail = sampleContractDetail(totalContractValue: null);
      expect(contractDisplayTotalValue(detail), Decimal.parse('1440.000'));
    });
  });

  group('buildContractProductRows', () {
    test('merges asset and consumable lines', () {
      final rows = buildContractProductRows(sampleContractDetail());
      expect(rows, hasLength(2));
      expect(rows.first.isAsset, isTrue);
      expect(rows.last.isAsset, isFalse);
    });
  });

  group('formatRemainingDays', () {
    test('formats positive remaining days', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(formatRemainingDays(l10n, 3), '3 days remaining');
    });

    test('formats overdue days as negative', () {
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(formatRemainingDays(l10n, -3), '-3 days');
      expect(isRemainingDaysOverdue(-3), isTrue);
    });
  });
}
