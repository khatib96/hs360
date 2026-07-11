import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/contracts/presentation/contract_convert_draft_builder.dart';

void main() {
  group('conversion draft builder', () {
    test(
      'default end date is 12 months from conversion start with month-end clamp',
      () {
        final start = DateTime(2026, 1, 31);
        final end = defaultConversionEndDate(start);
        expect(end, DateTime(2027, 1, 31));
      },
    );

    test('month-end clamp applies when target month is shorter', () {
      final start = DateTime(2026, 1, 31);
      final end = _addMonthsForTest(start, 1);
      expect(end, DateTime(2026, 2, 28));
    });

    test('normalizeConversionStartDate strips time component', () {
      final normalized = normalizeConversionStartDate(
        DateTime(2026, 7, 12, 15, 30),
      );
      expect(normalized, DateTime(2026, 7, 12));
    });
  });
}

DateTime _addMonthsForTest(DateTime date, int months) {
  final monthIndex = date.month - 1 + months;
  final year = date.year + monthIndex ~/ 12;
  final month = monthIndex % 12 + 1;
  final day = date.day;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, day > lastDay ? lastDay : day);
}
