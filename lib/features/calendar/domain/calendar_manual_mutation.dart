import 'calendar_date.dart';
import 'calendar_enums.dart';
import 'calendar_event.dart';
import 'calendar_meeting_mode.dart';

/// Soft-conflict acknowledgements for manual create/update payloads.
class CalendarManualAcknowledgements {
  const CalendarManualAcknowledgements({
    this.acknowledgeOverlap = false,
    this.acknowledgeNonWorkingDay = false,
    this.acknowledgeScheduleUnconfigured = false,
    this.acknowledgeOutsideWorkingWindow = false,
    this.dayOffOverrideReason,
  });

  final bool acknowledgeOverlap;
  final bool acknowledgeNonWorkingDay;
  final bool acknowledgeScheduleUnconfigured;
  final bool acknowledgeOutsideWorkingWindow;
  final String? dayOffOverrideReason;

  Map<String, dynamic> toRpcPayload() {
    final map = <String, dynamic>{};
    if (acknowledgeOverlap) map['acknowledge_overlap'] = true;
    if (acknowledgeNonWorkingDay) map['acknowledge_non_working_day'] = true;
    if (acknowledgeScheduleUnconfigured) {
      map['acknowledge_schedule_unconfigured'] = true;
    }
    if (acknowledgeOutsideWorkingWindow) {
      map['acknowledge_outside_working_window'] = true;
    }
    final reason = dayOffOverrideReason?.trim();
    if (reason != null && reason.isNotEmpty) {
      map['day_off_override_reason'] = reason;
    }
    return map;
  }

  CalendarManualAcknowledgements copyWith({
    bool? acknowledgeOverlap,
    bool? acknowledgeNonWorkingDay,
    bool? acknowledgeScheduleUnconfigured,
    bool? acknowledgeOutsideWorkingWindow,
    String? dayOffOverrideReason,
    bool clearDayOffOverrideReason = false,
  }) {
    return CalendarManualAcknowledgements(
      acknowledgeOverlap: acknowledgeOverlap ?? this.acknowledgeOverlap,
      acknowledgeNonWorkingDay:
          acknowledgeNonWorkingDay ?? this.acknowledgeNonWorkingDay,
      acknowledgeScheduleUnconfigured:
          acknowledgeScheduleUnconfigured ??
          this.acknowledgeScheduleUnconfigured,
      acknowledgeOutsideWorkingWindow:
          acknowledgeOutsideWorkingWindow ??
          this.acknowledgeOutsideWorkingWindow,
      dayOffOverrideReason: clearDayOffOverrideReason
          ? null
          : (dayOffOverrideReason ?? this.dayOffOverrideReason),
    );
  }
}

/// Optional timed window input (local HH:mm). Timezone is resolved server-side.
class CalendarManualTimeWindowInput {
  const CalendarManualTimeWindowInput({
    required this.startLocal,
    required this.endLocal,
  });

  final String startLocal;
  final String endLocal;

  Map<String, dynamic> toRpcPayload() => {
    'start_local': startLocal,
    'end_local': endLocal,
  };
}

/// Business payload for create/update manual calendar events.
class CalendarManualEventData {
  const CalendarManualEventData({
    required this.type,
    required this.scheduledDate,
    required this.titleAr,
    this.titleEn,
    this.notes,
    this.timeWindow,
    this.customerId,
    this.serviceLocationId,
    this.contractId,
    this.freeTextTeam,
    this.freeTextLocation,
    this.participantEmployeeIds = const [],
    this.meetingMode,
    this.meetingUrl,
    this.acknowledgements = const CalendarManualAcknowledgements(),
  });

  final CalendarEventType type;
  final DateTime scheduledDate;
  final String titleAr;
  final String? titleEn;
  final String? notes;
  final CalendarManualTimeWindowInput? timeWindow;
  final String? customerId;
  final String? serviceLocationId;
  final String? contractId;
  final String? freeTextTeam;
  final String? freeTextLocation;
  final List<String> participantEmployeeIds;
  final CalendarMeetingMode? meetingMode;
  final String? meetingUrl;
  final CalendarManualAcknowledgements acknowledgements;

  Map<String, dynamic> toCreateRpcPayload() {
    final map = <String, dynamic>{
      'type': type.rpcValue,
      'scheduled_date': formatCalendarDateOnly(scheduledDate),
      'title_ar': titleAr,
      'time_window': timeWindow?.toRpcPayload(),
      'participant_employee_ids': participantEmployeeIds,
    };
    final titleEnTrim = titleEn?.trim();
    if (titleEnTrim != null && titleEnTrim.isNotEmpty) {
      map['title_en'] = titleEnTrim;
    }
    final notesTrim = notes?.trim();
    if (notesTrim != null && notesTrim.isNotEmpty) {
      map['notes'] = notesTrim;
    }
    if (customerId != null) map['customer_id'] = customerId;
    if (serviceLocationId != null) {
      map['service_location_id'] = serviceLocationId;
    }
    if (contractId != null) map['contract_id'] = contractId;
    final team = freeTextTeam?.trim();
    if (team != null && team.isNotEmpty) map['free_text_team'] = team;
    final location = freeTextLocation?.trim();
    if (location != null && location.isNotEmpty) {
      map['free_text_location'] = location;
    }
    if (meetingMode != null) map['meeting_mode'] = meetingMode!.rpcValue;
    if (meetingUrl != null) map['meeting_url'] = meetingUrl;
    final acks = acknowledgements.toRpcPayload();
    if (acks.isNotEmpty) map['acknowledgements'] = acks;
    return map;
  }

  /// Update overlay payload (type/date are immutable server-side).
  Map<String, dynamic> toUpdateRpcPayload() {
    final map = Map<String, dynamic>.from(toCreateRpcPayload());
    map.remove('type');
    map.remove('scheduled_date');
    return map;
  }

  CalendarManualEventData copyWith({
    CalendarManualAcknowledgements? acknowledgements,
  }) {
    return CalendarManualEventData(
      type: type,
      scheduledDate: scheduledDate,
      titleAr: titleAr,
      titleEn: titleEn,
      notes: notes,
      timeWindow: timeWindow,
      customerId: customerId,
      serviceLocationId: serviceLocationId,
      contractId: contractId,
      freeTextTeam: freeTextTeam,
      freeTextLocation: freeTextLocation,
      participantEmployeeIds: participantEmployeeIds,
      meetingMode: meetingMode,
      meetingUrl: meetingUrl,
      acknowledgements: acknowledgements ?? this.acknowledgements,
    );
  }
}

/// Soft conflict payload when confirmation is required.
class CalendarManualConflictInfo {
  const CalendarManualConflictInfo({
    required this.scheduleWarnings,
    required this.overlapWarnings,
    required this.overlapTotalCount,
  });

  final List<Map<String, dynamic>> scheduleWarnings;
  final List<Map<String, dynamic>> overlapWarnings;
  final int overlapTotalCount;
}

/// Result of create/update manual calendar event RPCs.
sealed class CalendarManualMutationResult {
  const CalendarManualMutationResult();
}

class CalendarManualMutationOk extends CalendarManualMutationResult {
  const CalendarManualMutationOk(this.event);

  final CalendarEvent event;
}

class CalendarManualMutationConfirmationRequired
    extends CalendarManualMutationResult {
  const CalendarManualMutationConfirmationRequired(this.conflicts);

  final CalendarManualConflictInfo conflicts;
}
