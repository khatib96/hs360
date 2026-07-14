import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/calendar/domain/calendar_enums.dart';

void main() {
  group('CalendarEventType', () {
    test('fromRpc round-trips all known values', () {
      for (final value in CalendarEventType.values) {
        expect(CalendarEventType.fromRpc(value.rpcValue), value);
      }
    });

    test('fromRpc returns null for unknown', () {
      expect(CalendarEventType.fromRpc('unknown_type'), isNull);
      expect(CalendarEventType.fromRpc(''), isNull);
    });
  });

  group('CalendarEventStatus', () {
    test('fromRpc round-trips all known values', () {
      for (final value in CalendarEventStatus.values) {
        expect(CalendarEventStatus.fromRpc(value.rpcValue), value);
      }
    });

    test('fromRpc returns null for unknown', () {
      expect(CalendarEventStatus.fromRpc('archived'), isNull);
    });
  });

  group('CalendarEventSourceKind', () {
    test('fromRpc round-trips all known values', () {
      for (final value in CalendarEventSourceKind.values) {
        expect(CalendarEventSourceKind.fromRpc(value.rpcValue), value);
      }
    });

    test('fromRpc returns null for unknown', () {
      expect(CalendarEventSourceKind.fromRpc('imported'), isNull);
    });
  });

  group('CalendarReadScope', () {
    test('fromRpc round-trips all known values', () {
      for (final value in CalendarReadScope.values) {
        expect(CalendarReadScope.fromRpc(value.rpcValue), value);
      }
    });

    test('fromRpc returns null for unknown', () {
      expect(CalendarReadScope.fromRpc('everyone'), isNull);
    });
  });

  group('CalendarScheduleState', () {
    test('fromRpc round-trips all known values', () {
      for (final value in CalendarScheduleState.values) {
        expect(CalendarScheduleState.fromRpc(value.rpcValue), value);
      }
    });

    test('fromRpc returns null for unknown', () {
      expect(CalendarScheduleState.fromRpc('holiday'), isNull);
    });
  });

  group('CalendarOverdueState', () {
    test('fromRpc round-trips all known values', () {
      for (final value in CalendarOverdueState.values) {
        expect(CalendarOverdueState.fromRpc(value.rpcValue), value);
      }
    });

    test('fromRpc returns null for unknown', () {
      expect(CalendarOverdueState.fromRpc('late'), isNull);
    });
  });

  group('CalendarOverdueOutsideRangeState', () {
    test('fromRpc round-trips all known values', () {
      for (final value in CalendarOverdueOutsideRangeState.values) {
        expect(CalendarOverdueOutsideRangeState.fromRpc(value.rpcValue), value);
      }
    });

    test('fromRpc returns null for unknown', () {
      expect(CalendarOverdueOutsideRangeState.fromRpc('missing'), isNull);
    });
  });
}
