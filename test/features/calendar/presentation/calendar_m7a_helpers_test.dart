import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/calendar/domain/calendar_enums.dart';
import 'package:hs360/features/calendar/domain/calendar_manual_mutation.dart';
import 'package:hs360/features/calendar/domain/calendar_meeting_mode.dart';
import 'package:hs360/features/calendar/domain/calendar_mutation_validators.dart';
import 'package:hs360/features/calendar/presentation/calendar_join_meeting.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  group('CalendarMutationValidators M7A', () {
    test('clears time when toggle off', () {
      final result = CalendarMutationValidators.validateManualEventForm(
        type: CalendarEventType.internalTask,
        titleAr: 'مهمة',
        setTimeEnabled: false,
        timeWindow: const CalendarManualTimeWindowInput(
          startLocal: '09:00',
          endLocal: '10:00',
        ),
      );
      expect(result.isValid, isFalse);
      expect(result.codes, contains('time_invalid'));
    });

    test('requires https for online meetings', () {
      final result = CalendarMutationValidators.validateManualEventForm(
        type: CalendarEventType.internalMeeting,
        titleAr: 'اجتماع',
        setTimeEnabled: false,
        meetingMode: CalendarMeetingMode.online,
        meetingUrl: 'http://insecure.example.com',
      );
      expect(result.codes, contains('meeting_url_invalid'));
      expect(
        CalendarMutationValidators.isSafeHttpsUrl('https://x.com/a'),
        isTrue,
      );
    });

    test('forbids customer links on internal categories', () {
      final result = CalendarMutationValidators.validateManualEventForm(
        type: CalendarEventType.internalTask,
        titleAr: 'مهمة',
        setTimeEnabled: false,
        customerId: '11111111-1111-1111-1111-111111111111',
      );
      expect(result.codes, contains('customer_links_forbidden'));
    });
  });

  group('joinCalendarMeeting', () {
    test('rejects invalid urls without launching', () async {
      var launched = false;
      final result = await joinCalendarMeeting(
        'ftp://bad',
        launcher: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
          launched = true;
          return true;
        },
      );
      expect(result, JoinMeetingResult.invalidUrl);
      expect(launched, isFalse);
    });

    test('opens safe https urls', () async {
      final result = await joinCalendarMeeting(
        'https://meet.example.com/room',
        launcher: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
          expect(uri.scheme, 'https');
          return true;
        },
      );
      expect(result, JoinMeetingResult.opened);
    });

    test('reports launch failure', () async {
      final result = await joinCalendarMeeting(
        'https://meet.example.com/room',
        launcher: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async =>
            false,
      );
      expect(result, JoinMeetingResult.launchFailed);
    });
  });
}
