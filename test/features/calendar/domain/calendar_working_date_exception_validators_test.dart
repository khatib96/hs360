import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/calendar/domain/calendar_settings.dart';
import 'package:hs360/features/calendar/domain/calendar_working_date_exception.dart';
import 'package:hs360/features/calendar/domain/calendar_working_date_exception_validators.dart';

void main() {
  group(
    'CalendarWorkingDateExceptionValidators.validate — kind/date/title',
    () {
      test('valid holiday payload passes', () {
        final result = CalendarWorkingDateExceptionValidators.validate(
          kind: CalendarWorkingDateExceptionKind.officialHoliday,
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 1),
          titleAr: 'عيد',
        );
        expect(result.isValid, isTrue);
      });

      test('missing kind is rejected', () {
        final result = CalendarWorkingDateExceptionValidators.validate(
          kind: null,
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 1),
          titleAr: 'عيد',
        );
        expect(
          result.codes,
          contains(CalendarWorkingDateExceptionValidators.kindRequired),
        );
      });

      test('missing dates are rejected independently', () {
        final result = CalendarWorkingDateExceptionValidators.validate(
          kind: CalendarWorkingDateExceptionKind.officialHoliday,
          startDate: null,
          endDate: null,
          titleAr: 'عيد',
        );
        expect(
          result.codes,
          containsAll([
            CalendarWorkingDateExceptionValidators.dateFromRequired,
            CalendarWorkingDateExceptionValidators.dateToRequired,
          ]),
        );
      });

      test('end before start is rejected', () {
        final result = CalendarWorkingDateExceptionValidators.validate(
          kind: CalendarWorkingDateExceptionKind.officialHoliday,
          startDate: DateTime(2026, 8, 5),
          endDate: DateTime(2026, 8, 1),
          titleAr: 'عيد',
        );
        expect(
          result.codes,
          contains(CalendarWorkingDateExceptionValidators.dateRangeInvalid),
        );
      });

      test('span over 366 inclusive days is rejected', () {
        final result = CalendarWorkingDateExceptionValidators.validate(
          kind: CalendarWorkingDateExceptionKind.officialHoliday,
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2027, 1, 3),
          titleAr: 'عيد',
        );
        expect(
          result.codes,
          contains(CalendarWorkingDateExceptionValidators.dateRangeTooLong),
        );
      });

      test('exactly 366 inclusive days is accepted', () {
        final result = CalendarWorkingDateExceptionValidators.validate(
          kind: CalendarWorkingDateExceptionKind.officialHoliday,
          startDate: DateTime(2026, 1, 1),
          endDate: DateTime(2027, 1, 1),
          titleAr: 'عيد',
        );
        expect(result.isValid, isTrue);
      });

      test('missing both titles is rejected', () {
        final result = CalendarWorkingDateExceptionValidators.validate(
          kind: CalendarWorkingDateExceptionKind.officialHoliday,
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 1),
        );
        expect(
          result.codes,
          contains(CalendarWorkingDateExceptionValidators.titleRequired),
        );
      });

      test('title_en alone satisfies the title requirement', () {
        final result = CalendarWorkingDateExceptionValidators.validate(
          kind: CalendarWorkingDateExceptionKind.officialHoliday,
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 1),
          titleEn: 'Holiday',
        );
        expect(result.isValid, isTrue);
      });

      test('title_ar over 200 chars is rejected', () {
        final result = CalendarWorkingDateExceptionValidators.validate(
          kind: CalendarWorkingDateExceptionKind.officialHoliday,
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 1),
          titleAr: 'ع' * 201,
        );
        expect(
          result.codes,
          contains(CalendarWorkingDateExceptionValidators.titleArTooLong),
        );
      });

      test('notes over 2000 chars is rejected', () {
        final result = CalendarWorkingDateExceptionValidators.validate(
          kind: CalendarWorkingDateExceptionKind.officialHoliday,
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 1),
          titleAr: 'عيد',
          notes: 'x' * 2001,
        );
        expect(
          result.codes,
          contains(CalendarWorkingDateExceptionValidators.notesTooLong),
        );
      });
    },
  );

  group('CalendarWorkingDateExceptionValidators.validate — matrix', () {
    for (final kind in [
      CalendarWorkingDateExceptionKind.officialHoliday,
      CalendarWorkingDateExceptionKind.companyClosure,
    ]) {
      test('$kind rejects a day_mode', () {
        final result = CalendarWorkingDateExceptionValidators.validate(
          kind: kind,
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 1),
          titleAr: 'عيد',
          dayMode: TenantWorkingDayMode.workingHours,
          workStart: '08:00',
          workEnd: '12:00',
        );
        expect(
          result.codes,
          containsAll([
            CalendarWorkingDateExceptionValidators.dayModeNotAllowed,
            CalendarWorkingDateExceptionValidators.workWindowNotAllowed,
          ]),
        );
      });

      test('$kind accepts no day_mode/window', () {
        final result = CalendarWorkingDateExceptionValidators.validate(
          kind: kind,
          startDate: DateTime(2026, 8, 1),
          endDate: DateTime(2026, 8, 1),
          titleAr: 'عيد',
        );
        expect(result.isValid, isTrue);
      });
    }

    test('exceptional_working_day requires a day_mode', () {
      final result = CalendarWorkingDateExceptionValidators.validate(
        kind: CalendarWorkingDateExceptionKind.exceptionalWorkingDay,
        startDate: DateTime(2026, 8, 8),
        endDate: DateTime(2026, 8, 8),
        titleAr: 'يوم عمل',
      );
      expect(
        result.codes,
        contains(CalendarWorkingDateExceptionValidators.dayModeRequired),
      );
    });

    test('exceptional_working_day 24_hours forbids a work window', () {
      final result = CalendarWorkingDateExceptionValidators.validate(
        kind: CalendarWorkingDateExceptionKind.exceptionalWorkingDay,
        startDate: DateTime(2026, 8, 8),
        endDate: DateTime(2026, 8, 8),
        titleAr: 'يوم عمل',
        dayMode: TenantWorkingDayMode.hours24,
        workStart: '08:00',
      );
      expect(
        result.codes,
        contains(CalendarWorkingDateExceptionValidators.workWindowNotAllowed),
      );
    });

    test('exceptional_working_day 24_hours with no window is valid', () {
      final result = CalendarWorkingDateExceptionValidators.validate(
        kind: CalendarWorkingDateExceptionKind.exceptionalWorkingDay,
        startDate: DateTime(2026, 8, 8),
        endDate: DateTime(2026, 8, 8),
        titleAr: 'يوم عمل',
        dayMode: TenantWorkingDayMode.hours24,
      );
      expect(result.isValid, isTrue);
    });

    test('working_hours requires both start and end', () {
      final result = CalendarWorkingDateExceptionValidators.validate(
        kind: CalendarWorkingDateExceptionKind.exceptionalWorkingDay,
        startDate: DateTime(2026, 8, 8),
        endDate: DateTime(2026, 8, 8),
        titleAr: 'يوم عمل',
        dayMode: TenantWorkingDayMode.workingHours,
        workStart: '08:00',
      );
      expect(
        result.codes,
        contains(CalendarWorkingDateExceptionValidators.workWindowRequired),
      );
    });

    test('working_hours rejects malformed HH:mm', () {
      final result = CalendarWorkingDateExceptionValidators.validate(
        kind: CalendarWorkingDateExceptionKind.exceptionalWorkingDay,
        startDate: DateTime(2026, 8, 8),
        endDate: DateTime(2026, 8, 8),
        titleAr: 'يوم عمل',
        dayMode: TenantWorkingDayMode.workingHours,
        workStart: '8:00',
        workEnd: '12:00',
      );
      expect(
        result.codes,
        contains(CalendarWorkingDateExceptionValidators.workWindowInvalid),
      );
    });

    test('working_hours rejects end not after start', () {
      final result = CalendarWorkingDateExceptionValidators.validate(
        kind: CalendarWorkingDateExceptionKind.exceptionalWorkingDay,
        startDate: DateTime(2026, 8, 8),
        endDate: DateTime(2026, 8, 8),
        titleAr: 'يوم عمل',
        dayMode: TenantWorkingDayMode.workingHours,
        workStart: '12:00',
        workEnd: '08:00',
      );
      expect(
        result.codes,
        contains(
          CalendarWorkingDateExceptionValidators.workWindowEndNotAfterStart,
        ),
      );
    });

    test('working_hours with a valid window is accepted', () {
      final result = CalendarWorkingDateExceptionValidators.validate(
        kind: CalendarWorkingDateExceptionKind.exceptionalWorkingDay,
        startDate: DateTime(2026, 8, 8),
        endDate: DateTime(2026, 8, 8),
        titleAr: 'يوم عمل',
        dayMode: TenantWorkingDayMode.workingHours,
        workStart: '08:00',
        workEnd: '12:00',
      );
      expect(result.isValid, isTrue);
    });
  });

  group('CalendarWorkingDateExceptionValidators.validateCancelReason', () {
    test('empty reason is rejected', () {
      final result =
          CalendarWorkingDateExceptionValidators.validateCancelReason('');
      expect(result.isValid, isFalse);
    });

    test('non-empty reason within bounds is accepted', () {
      final result =
          CalendarWorkingDateExceptionValidators.validateCancelReason(
            'Corrected by owner',
          );
      expect(result.isValid, isTrue);
    });
  });
}
