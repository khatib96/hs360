import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/calendar_exception.dart';
import 'package:hs360/features/calendar/data/calendar_read_rpc_parsers.dart';

import 'calendar_read_fixtures.dart';

Matcher _malformed() => isA<CalendarException>().having(
  (e) => e.code,
  'code',
  CalendarException.malformedResponse,
);

void main() {
  group('mapExecutionSummary', () {
    test('null OK', () {
      expect(mapExecutionSummary(null), isNull);
    });

    test('complete month-coverage OK', () {
      final summary = mapExecutionSummary(monthCoverageExecutionSummaryRpc())!;
      expect(summary.actualCompletionDate, DateTime(2026, 7, 10));
      expect(summary.actualQuantityDelivered, Decimal.parse('12.50'));
      expect(summary.quantityUnit, 'cylinder');
      expect(summary.contractedQuantityPerCycle, Decimal.parse('10.00'));
      expect(summary.coverageMonths, 1);
      expect(summary.coverageDays, isNull);
      expect(summary.calculatedNextDueDate, DateTime(2026, 8, 10));
      expect(summary.confirmedNextDueDate, DateTime(2026, 8, 12));
      expect(summary.nextDueOverridden, isTrue);
    });

    test('complete day-coverage OK', () {
      final summary = mapExecutionSummary(dayCoverageExecutionSummaryRpc())!;
      expect(summary.coverageMonths, isNull);
      expect(summary.coverageDays, 30);
      expect(summary.calculatedNextDueDate, DateTime(2026, 8, 9));
      expect(summary.confirmedNextDueDate, DateTime(2026, 8, 12));
    });

    test('missing quantity → malformed', () {
      final raw = validExecutionSummaryRpc()
        ..remove('actual_quantity_delivered');
      expect(() => mapExecutionSummary(raw), throwsA(_malformed()));
    });

    test('missing unit → malformed', () {
      final raw = validExecutionSummaryRpc()..remove('quantity_unit');
      expect(() => mapExecutionSummary(raw), throwsA(_malformed()));
    });

    test('empty unit → malformed', () {
      final raw = validExecutionSummaryRpc()..['quantity_unit'] = '';
      expect(() => mapExecutionSummary(raw), throwsA(_malformed()));
    });

    test('missing actual_completion_date → malformed', () {
      final raw = validExecutionSummaryRpc()..remove('actual_completion_date');
      expect(() => mapExecutionSummary(raw), throwsA(_malformed()));
    });

    test('missing confirmed_next_due_date → malformed', () {
      final raw = validExecutionSummaryRpc()..remove('confirmed_next_due_date');
      expect(() => mapExecutionSummary(raw), throwsA(_malformed()));
    });

    test('missing calculated_next_due_date → malformed', () {
      final raw = validExecutionSummaryRpc()
        ..remove('calculated_next_due_date');
      expect(() => mapExecutionSummary(raw), throwsA(_malformed()));
    });

    test('null calculated_next_due_date → malformed', () {
      final raw = validExecutionSummaryRpc()
        ..['calculated_next_due_date'] = null;
      expect(() => mapExecutionSummary(raw), throwsA(_malformed()));
    });

    test('invalid calculated_next_due_date → malformed', () {
      final raw = validExecutionSummaryRpc()
        ..['calculated_next_due_date'] = '2026-02-30';
      expect(() => mapExecutionSummary(raw), throwsA(_malformed()));
    });

    test('both coverage fields missing → malformed', () {
      final raw = validExecutionSummaryRpc(
        coverageMonths: null,
        coverageDays: null,
      );
      expect(raw.containsKey('coverage_months'), isFalse);
      expect(raw.containsKey('coverage_days'), isFalse);
      expect(() => mapExecutionSummary(raw), throwsA(_malformed()));
    });

    test('both coverage fields present → malformed', () {
      final raw = validExecutionSummaryRpc(coverageMonths: 1, coverageDays: 30);
      expect(() => mapExecutionSummary(raw), throwsA(_malformed()));
    });

    test('zero coverage_months → malformed', () {
      final raw = validExecutionSummaryRpc(
        coverageMonths: 0,
        coverageDays: null,
      );
      expect(() => mapExecutionSummary(raw), throwsA(_malformed()));
    });

    test('negative coverage_days → malformed', () {
      final raw = validExecutionSummaryRpc(
        coverageMonths: null,
        coverageDays: -1,
      );
      expect(() => mapExecutionSummary(raw), throwsA(_malformed()));
    });

    test('wrong quantity type → malformed', () {
      final raw = validExecutionSummaryRpc()
        ..['actual_quantity_delivered'] = true;
      expect(() => mapExecutionSummary(raw), throwsA(_malformed()));
    });

    test('wrong next_due_overridden type → malformed', () {
      final raw = validExecutionSummaryRpc()..['next_due_overridden'] = 'yes';
      expect(() => mapExecutionSummary(raw), throwsA(_malformed()));
    });
  });
}
