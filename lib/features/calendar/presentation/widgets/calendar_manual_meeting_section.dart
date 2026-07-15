import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/calendar_enums.dart';
import '../../domain/calendar_meeting_mode.dart';

/// Meeting mode / URL / free-text location fields driven by event type.
class CalendarManualMeetingSection extends StatelessWidget {
  const CalendarManualMeetingSection({
    required this.type,
    required this.meetingMode,
    required this.meetingUrl,
    required this.locationText,
    required this.team,
    required this.onMeetingModeChanged,
    super.key,
  });

  final CalendarEventType type;
  final CalendarMeetingMode? meetingMode;
  final TextEditingController meetingUrl;
  final TextEditingController locationText;
  final TextEditingController team;
  final ValueChanged<CalendarMeetingMode?> onMeetingModeChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (type == CalendarEventType.internalMeeting) ...[
          const SizedBox(height: 8),
          DropdownButtonFormField<CalendarMeetingMode>(
            key: const Key('calendar-manual-meeting-mode'),
            initialValue: meetingMode,
            decoration: InputDecoration(labelText: l10n.calendarMeetingMode),
            items: [
              DropdownMenuItem(
                value: CalendarMeetingMode.inPerson,
                child: Text(l10n.calendarMeetingModeInPerson),
              ),
              DropdownMenuItem(
                value: CalendarMeetingMode.online,
                child: Text(l10n.calendarMeetingModeOnline),
              ),
            ],
            onChanged: onMeetingModeChanged,
          ),
          if (meetingMode == CalendarMeetingMode.online) ...[
            const SizedBox(height: 8),
            TextField(
              key: const Key('calendar-manual-meeting-url'),
              controller: meetingUrl,
              decoration: InputDecoration(labelText: l10n.calendarMeetingUrl),
            ),
          ],
          if (meetingMode == CalendarMeetingMode.inPerson) ...[
            const SizedBox(height: 8),
            TextField(
              key: const Key('calendar-manual-meeting-location'),
              controller: locationText,
              decoration: InputDecoration(
                labelText: l10n.calendarManualLocation,
              ),
            ),
          ],
        ] else ...[
          const SizedBox(height: 8),
          TextField(
            key: const Key('calendar-manual-free-location'),
            controller: locationText,
            decoration: InputDecoration(labelText: l10n.calendarManualLocation),
          ),
        ],
        const SizedBox(height: 8),
        TextField(
          key: const Key('calendar-manual-team'),
          controller: team,
          decoration: InputDecoration(labelText: l10n.calendarManualTeam),
        ),
      ],
    );
  }
}
