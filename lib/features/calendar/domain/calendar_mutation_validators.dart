import 'calendar_date.dart';
import 'calendar_enums.dart';
import 'calendar_manual_mutation.dart';
import 'calendar_meeting_mode.dart';

/// Outcome of calendar mutation foundation validators (M7/M8).
class CalendarMutationValidationResult {
  const CalendarMutationValidationResult({this.codes = const []});

  const CalendarMutationValidationResult.valid() : codes = const [];

  final List<String> codes;

  bool get isValid => codes.isEmpty;
}

/// Client-side validators for manual calendar forms and mutation foundations.
class CalendarMutationValidators {
  static const dateRequired = 'date_required';
  static const dateInvalid = 'date_invalid';
  static const agentIdInvalid = 'agent_id_invalid';
  static const typeRequired = 'type_required';
  static const typeNotManual = 'type_not_manual';
  static const titleArRequired = 'title_ar_required';
  static const titleArTooLong = 'title_ar_too_long';
  static const titleEnTooLong = 'title_en_too_long';
  static const notesTooLong = 'notes_too_long';
  static const customerLinksForbidden = 'customer_links_forbidden';
  static const locationRequiresCustomer = 'location_requires_customer';
  static const meetingModeRequired = 'meeting_mode_required';
  static const meetingModeForbidden = 'meeting_mode_forbidden';
  static const meetingUrlRequired = 'meeting_url_required';
  static const meetingUrlInvalid = 'meeting_url_invalid';
  static const meetingLocationRequired = 'meeting_location_required';
  static const meetingUrlForbidden = 'meeting_url_forbidden';
  static const meetingLocationForbidden = 'meeting_location_forbidden';
  static const timeStartRequired = 'time_start_required';
  static const timeEndRequired = 'time_end_required';
  static const timeInvalid = 'time_invalid';
  static const timeEndNotAfterStart = 'time_end_not_after_start';
  static const cancelReasonRequired = 'cancel_reason_required';
  static const cancelReasonTooLong = 'cancel_reason_too_long';
  static const freeTextTooLong = 'free_text_too_long';
  static const uuidInvalid = 'uuid_invalid';

  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  static final _hhmmPattern = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');

  static final _httpsUrlPattern = RegExp(
    r'^https:\/\/[^\s/$.?#].[^\s]*$',
    caseSensitive: false,
  );

  /// Validates a date-only string for manual event create.
  static CalendarMutationValidationResult validateManualEventDate(
    String? value,
  ) {
    return _validateDateOnly(value);
  }

  /// Validates a date-only string for reschedule target date.
  static CalendarMutationValidationResult validateRescheduleTargetDate(
    String? value,
  ) {
    return _validateDateOnly(value);
  }

  /// When [agentId] is provided, requires a non-empty UUID-shaped string.
  static CalendarMutationValidationResult validateAssignmentAgentId(
    String? agentId,
  ) {
    if (agentId == null) {
      return const CalendarMutationValidationResult.valid();
    }
    final trimmed = agentId.trim();
    if (trimmed.isEmpty || !_uuidPattern.hasMatch(trimmed)) {
      return const CalendarMutationValidationResult(codes: [agentIdInvalid]);
    }
    return const CalendarMutationValidationResult.valid();
  }

  static CalendarMutationValidationResult validateCancelReason(String? reason) {
    final trimmed = reason?.trim() ?? '';
    if (trimmed.isEmpty) {
      return const CalendarMutationValidationResult(
        codes: [cancelReasonRequired],
      );
    }
    if (trimmed.length > 1000) {
      return const CalendarMutationValidationResult(
        codes: [cancelReasonTooLong],
      );
    }
    return const CalendarMutationValidationResult.valid();
  }

  /// Validates a manual create/update form model before RPC submit.
  ///
  /// When [setTimeEnabled] is false, any time-window input must be cleared
  /// (treated as null) by the caller before building the payload.
  static CalendarMutationValidationResult validateManualEventForm({
    required CalendarEventType? type,
    required String? titleAr,
    String? titleEn,
    String? notes,
    required bool setTimeEnabled,
    CalendarManualTimeWindowInput? timeWindow,
    String? customerId,
    String? serviceLocationId,
    String? contractId,
    String? freeTextTeam,
    String? freeTextLocation,
    CalendarMeetingMode? meetingMode,
    String? meetingUrl,
    List<String> participantEmployeeIds = const [],
  }) {
    final codes = <String>[];

    if (type == null) {
      codes.add(typeRequired);
    } else if (!type.isManualCreatable) {
      codes.add(typeNotManual);
    }

    final ar = titleAr?.trim() ?? '';
    if (ar.isEmpty) {
      codes.add(titleArRequired);
    } else if (ar.length > 500) {
      codes.add(titleArTooLong);
    }

    final en = titleEn?.trim();
    if (en != null && en.length > 500) codes.add(titleEnTooLong);

    final notesTrim = notes?.trim();
    if (notesTrim != null && notesTrim.length > 8000) codes.add(notesTooLong);

    final team = freeTextTeam?.trim();
    if (team != null && team.length > 500) codes.add(freeTextTooLong);
    final locationText = freeTextLocation?.trim();
    if (locationText != null && locationText.length > 500) {
      codes.add(freeTextTooLong);
    }

    for (final id in [
      customerId,
      serviceLocationId,
      contractId,
      ...participantEmployeeIds,
    ]) {
      if (id == null) continue;
      final trimmed = id.trim();
      if (trimmed.isEmpty || !_uuidPattern.hasMatch(trimmed)) {
        codes.add(uuidInvalid);
        break;
      }
    }

    if (type != null) {
      if (type.isInternalCategory) {
        if (customerId != null ||
            serviceLocationId != null ||
            contractId != null) {
          codes.add(customerLinksForbidden);
        }
      } else if (serviceLocationId != null && customerId == null) {
        codes.add(locationRequiresCustomer);
      }

      if (type == CalendarEventType.internalMeeting) {
        if (meetingMode == null) {
          codes.add(meetingModeRequired);
        } else if (meetingMode == CalendarMeetingMode.online) {
          final url = meetingUrl?.trim() ?? '';
          if (url.isEmpty) {
            codes.add(meetingUrlRequired);
          } else if (!isSafeHttpsUrl(url)) {
            codes.add(meetingUrlInvalid);
          }
          if (locationText != null && locationText.isNotEmpty) {
            codes.add(meetingLocationForbidden);
          }
        } else {
          if (locationText == null || locationText.isEmpty) {
            codes.add(meetingLocationRequired);
          }
          if (meetingUrl != null && meetingUrl.trim().isNotEmpty) {
            codes.add(meetingUrlForbidden);
          }
        }
      } else {
        if (meetingMode != null) codes.add(meetingModeForbidden);
        if (meetingUrl != null && meetingUrl.trim().isNotEmpty) {
          codes.add(meetingUrlForbidden);
        }
      }
    }

    if (setTimeEnabled) {
      final start = timeWindow?.startLocal.trim() ?? '';
      final end = timeWindow?.endLocal.trim() ?? '';
      if (start.isEmpty) codes.add(timeStartRequired);
      if (end.isEmpty) codes.add(timeEndRequired);
      if (start.isNotEmpty && !_hhmmPattern.hasMatch(start)) {
        codes.add(timeInvalid);
      }
      if (end.isNotEmpty && !_hhmmPattern.hasMatch(end)) {
        codes.add(timeInvalid);
      }
      if (_hhmmPattern.hasMatch(start) &&
          _hhmmPattern.hasMatch(end) &&
          !_isEndAfterStart(start, end)) {
        codes.add(timeEndNotAfterStart);
      }
    } else if (timeWindow != null) {
      // Callers must clear the window when the toggle is off.
      codes.add(timeInvalid);
    }

    return CalendarMutationValidationResult(codes: codes);
  }

  static bool isSafeHttpsUrl(String value) {
    final trimmed = value.trim();
    if (!_httpsUrlPattern.hasMatch(trimmed)) return false;
    final uri = Uri.tryParse(trimmed);
    return uri != null &&
        uri.hasScheme &&
        uri.scheme.toLowerCase() == 'https' &&
        uri.host.isNotEmpty;
  }

  static CalendarMutationValidationResult _validateDateOnly(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const CalendarMutationValidationResult(codes: [dateRequired]);
    }
    try {
      parseCalendarDateOnly(value.trim());
      return const CalendarMutationValidationResult.valid();
    } on FormatException {
      return const CalendarMutationValidationResult(codes: [dateInvalid]);
    }
  }

  static bool _isEndAfterStart(String start, String end) {
    final startParts = start.split(':');
    final endParts = end.split(':');
    final startMinutes =
        int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
    return endMinutes > startMinutes;
  }
}
