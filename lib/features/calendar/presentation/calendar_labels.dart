import 'package:hs360/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../domain/calendar_enums.dart';
import '../domain/calendar_event.dart';
import '../domain/calendar_month_grid.dart';
import '../domain/calendar_settings.dart';
import '../domain/calendar_working_date_exception.dart';
import '../domain/calendar_working_date_exception_validators.dart';
import '../domain/calendar_working_day.dart';

String calendarEventTypeLabel(AppLocalizations l10n, CalendarEventType type) {
  return switch (type) {
    CalendarEventType.refillDue => l10n.calendarEventTypeRefillDue,
    CalendarEventType.billingDue => l10n.calendarEventTypeBillingDue,
    CalendarEventType.paymentDue => l10n.calendarEventTypePaymentDue,
    CalendarEventType.maintenanceDue => l10n.calendarEventTypeMaintenanceDue,
    CalendarEventType.followUp => l10n.calendarEventTypeFollowUp,
    CalendarEventType.trialEnding => l10n.calendarEventTypeTrialEnding,
    CalendarEventType.contractStart => l10n.calendarEventTypeContractStart,
    CalendarEventType.contractEnd => l10n.calendarEventTypeContractEnd,
    CalendarEventType.customerVisit => l10n.calendarEventTypeCustomerVisit,
    CalendarEventType.internalMeeting => l10n.calendarEventTypeInternalMeeting,
    CalendarEventType.internalTask => l10n.calendarEventTypeInternalTask,
    CalendarEventType.internalActivity =>
      l10n.calendarEventTypeInternalActivity,
    CalendarEventType.custom => l10n.calendarEventTypeCustom,
  };
}

String calendarEventStatusLabel(
  AppLocalizations l10n,
  CalendarEventStatus status,
) {
  return switch (status) {
    CalendarEventStatus.pending => l10n.calendarEventStatusPending,
    CalendarEventStatus.done => l10n.calendarEventStatusDone,
    CalendarEventStatus.missed => l10n.calendarEventStatusMissed,
    CalendarEventStatus.cancelled => l10n.calendarEventStatusCancelled,
    CalendarEventStatus.rescheduled => l10n.calendarEventStatusRescheduled,
  };
}

String calendarSourceKindLabel(
  AppLocalizations l10n,
  CalendarEventSourceKind kind,
) {
  return switch (kind) {
    CalendarEventSourceKind.manual => l10n.calendarSourceKindManual,
    CalendarEventSourceKind.contractGenerated =>
      l10n.calendarSourceKindContractGenerated,
  };
}

String calendarScheduleStateLabel(
  AppLocalizations l10n,
  CalendarScheduleState state,
) {
  return switch (state) {
    CalendarScheduleState.workingDay => l10n.calendarScheduleStateWorkingDay,
    CalendarScheduleState.nonWorkingDay =>
      l10n.calendarScheduleStateNonWorkingDay,
    CalendarScheduleState.scheduleUnconfigured =>
      l10n.calendarScheduleStateUnconfigured,
    CalendarScheduleState.dayOffOverridden =>
      l10n.calendarScheduleStateDayOffOverridden,
  };
}

String calendarWorkingDayModeLabel(
  AppLocalizations l10n,
  TenantWorkingDayMode mode,
) {
  return switch (mode) {
    TenantWorkingDayMode.unreviewed => l10n.calendarDayModeUnreviewed,
    TenantWorkingDayMode.dayOff => l10n.calendarDayModeDayOff,
    TenantWorkingDayMode.workingHours => l10n.calendarDayModeWorkingHours,
    TenantWorkingDayMode.hours24 => l10n.calendarDayMode24Hours,
  };
}

String calendarOverdueStateLabel(
  AppLocalizations l10n,
  CalendarOverdueState state,
) {
  return switch (state) {
    CalendarOverdueState.notApplicable =>
      l10n.calendarOverdueStateNotApplicable,
    CalendarOverdueState.scheduleUnconfigured =>
      l10n.calendarOverdueStateUnconfigured,
    CalendarOverdueState.overdue => l10n.calendarOverdueStateOverdue,
    CalendarOverdueState.notOverdue => l10n.calendarOverdueStateNotOverdue,
  };
}

String calendarEventTitle(CalendarEvent event, String languageCode) {
  if (languageCode == 'ar') return event.titleAr;
  return event.titleEn ?? event.titleAr;
}

String? calendarPersonName({
  required String languageCode,
  String? nameAr,
  String? nameEn,
}) {
  if (languageCode == 'ar') {
    return nameAr ?? nameEn;
  }
  return nameEn ?? nameAr;
}

String calendarWorkingStatusText(
  AppLocalizations l10n,
  CalendarWorkingDay workingDay,
) {
  if (workingDay.isDayOff) {
    return calendarWorkingDayModeLabel(l10n, TenantWorkingDayMode.dayOff);
  }
  if (workingDay.is24Hours) {
    return calendarWorkingDayModeLabel(l10n, TenantWorkingDayMode.hours24);
  }
  if (workingDay.isUnreviewed || !workingDay.scheduleConfigured) {
    return calendarWorkingDayModeLabel(l10n, TenantWorkingDayMode.unreviewed);
  }
  final start = workingDay.workStart;
  final end = workingDay.workEnd;
  if (start != null && end != null) {
    return l10n.calendarWorkingWindow(start, end);
  }
  return calendarWorkingDayModeLabel(l10n, workingDay.dayMode);
}

String calendarFormatCappedCount(
  AppLocalizations l10n,
  CalendarCappedCount count,
) {
  final formatted = NumberFormat.decimalPattern().format(count.value);
  if (count.overflow) {
    return l10n.calendarCountOverflow(count.value);
  }
  return formatted;
}

String calendarWeekdayShort(AppLocalizations l10n, int materialIndex) {
  return switch (materialIndex % 7) {
    0 => l10n.calendarWeekdaySunday,
    1 => l10n.calendarWeekdayMonday,
    2 => l10n.calendarWeekdayTuesday,
    3 => l10n.calendarWeekdayWednesday,
    4 => l10n.calendarWeekdayThursday,
    5 => l10n.calendarWeekdayFriday,
    _ => l10n.calendarWeekdaySaturday,
  };
}

String calendarMonthName(AppLocalizations l10n, int month) {
  // Use existing weekday-style keys only for days; months via intl DateFormat.
  return DateFormat.MMMM(l10n.localeName).format(DateTime(2026, month));
}

String calendarLocalizedDate(AppLocalizations l10n, DateTime date) {
  return DateFormat.yMMMMEEEEd(l10n.localeName).format(date);
}

String calendarErrorMessage(AppLocalizations l10n, String code) {
  return switch (code) {
    'permission_denied' => l10n.calendarPermissionDenied,
    'validation_failed' => l10n.calendarErrorValidation,
    'invalid_cursor' => l10n.calendarErrorInvalidCursor,
    'tenant_not_found' => l10n.calendarErrorTenantNotFound,
    'malformed_response' => l10n.calendarErrorMalformed,
    'not_available' => l10n.calendarErrorUnavailable,
    'supabaseNotConfigured' => l10n.calendarErrorUnavailable,
    'stale_version' => l10n.calendarErrorStaleVersion,
    'calendar_local_time_nonexistent' => l10n.calendarErrorLocalTimeNonexistent,
    'calendar_local_time_ambiguous' => l10n.calendarErrorLocalTimeAmbiguous,
    'calendar_timezone_unconfigured' => l10n.calendarErrorTimezoneUnconfigured,
    'calendar_time_window_cross_date' => l10n.calendarErrorTimeWindowCrossDate,
    'idempotency_payload_mismatch' => l10n.calendarErrorIdempotencyMismatch,
    'working_date_exception_overlap' =>
      l10n.calendarErrorWorkingDateExceptionOverlap,
    'calendar_assignment_not_applicable' =>
      l10n.calendarErrorAssignmentNotApplicable,
    _ => l10n.calendarErrorUnknown,
  };
}

String calendarManualValidationMessage(AppLocalizations l10n, String code) {
  return switch (code) {
    'type_required' || 'type_not_manual' => l10n.calendarValidationTypeRequired,
    'title_ar_required' => l10n.calendarValidationTitleRequired,
    'meeting_mode_required' => l10n.calendarValidationMeetingModeRequired,
    'meeting_url_required' ||
    'meeting_url_invalid' => l10n.calendarValidationMeetingUrlRequired,
    'meeting_location_required' =>
      l10n.calendarValidationMeetingLocationRequired,
    'time_start_required' ||
    'time_end_required' ||
    'time_invalid' => l10n.calendarValidationTimeRequired,
    'time_end_not_after_start' => l10n.calendarValidationTimeOrder,
    'cancel_reason_required' => l10n.calendarCancelReasonRequired,
    'reschedule_reason_required' ||
    'reschedule_reason_too_long' => l10n.calendarRescheduleReasonRequired,
    _ => l10n.calendarErrorValidation,
  };
}

String calendarWorkingDateExceptionKindLabel(
  AppLocalizations l10n,
  CalendarWorkingDateExceptionKind kind,
) {
  return switch (kind) {
    CalendarWorkingDateExceptionKind.officialHoliday =>
      l10n.calendarWorkingDateExceptionKindOfficialHoliday,
    CalendarWorkingDateExceptionKind.companyClosure =>
      l10n.calendarWorkingDateExceptionKindCompanyClosure,
    CalendarWorkingDateExceptionKind.exceptionalWorkingDay =>
      l10n.calendarWorkingDateExceptionKindExceptionalWorkingDay,
  };
}

String calendarWorkingDateExceptionStatusLabel(
  AppLocalizations l10n,
  CalendarWorkingDateExceptionStatus status,
) {
  return switch (status) {
    CalendarWorkingDateExceptionStatus.active =>
      l10n.calendarWorkingDateExceptionStatusActive,
    CalendarWorkingDateExceptionStatus.cancelled =>
      l10n.calendarWorkingDateExceptionStatusCancelled,
  };
}

String calendarWorkingDateExceptionStatusFilterLabel(
  AppLocalizations l10n,
  CalendarWorkingDateExceptionStatusFilter filter,
) {
  return switch (filter) {
    CalendarWorkingDateExceptionStatusFilter.active =>
      l10n.calendarWorkingDateExceptionsFilterActive,
    CalendarWorkingDateExceptionStatusFilter.cancelled =>
      l10n.calendarWorkingDateExceptionsFilterCancelled,
    CalendarWorkingDateExceptionStatusFilter.all =>
      l10n.calendarWorkingDateExceptionsFilterAll,
  };
}

/// Combined "kind – title" text used wherever a safe exception projection
/// (list row, agenda header, month marker, conflict dialog) is displayed.
String calendarDateExceptionKindTitleText(
  AppLocalizations l10n, {
  required CalendarWorkingDateExceptionKind kind,
  required String title,
}) {
  return l10n.calendarDateExceptionKindTitle(
    calendarWorkingDateExceptionKindLabel(l10n, kind),
    title,
  );
}

String calendarWorkingDateExceptionValidationMessage(
  AppLocalizations l10n,
  String code,
) {
  return switch (code) {
    CalendarWorkingDateExceptionValidators.kindRequired =>
      l10n.calendarWorkingDateExceptionValidationKindRequired,
    CalendarWorkingDateExceptionValidators.dateFromRequired ||
    CalendarWorkingDateExceptionValidators.dateToRequired =>
      l10n.calendarWorkingDateExceptionValidationDateRequired,
    CalendarWorkingDateExceptionValidators.dateInvalid =>
      l10n.calendarWorkingDateExceptionValidationDateInvalid,
    CalendarWorkingDateExceptionValidators.dateRangeInvalid =>
      l10n.calendarWorkingDateExceptionValidationDateRangeInvalid,
    CalendarWorkingDateExceptionValidators.dateRangeTooLong =>
      l10n.calendarWorkingDateExceptionValidationDateRangeTooLong,
    CalendarWorkingDateExceptionValidators.titleRequired =>
      l10n.calendarWorkingDateExceptionValidationTitleRequired,
    CalendarWorkingDateExceptionValidators.titleArTooLong ||
    CalendarWorkingDateExceptionValidators.titleEnTooLong =>
      l10n.calendarWorkingDateExceptionValidationTitleTooLong,
    CalendarWorkingDateExceptionValidators.notesTooLong =>
      l10n.calendarWorkingDateExceptionValidationNotesTooLong,
    CalendarWorkingDateExceptionValidators.dayModeRequired =>
      l10n.calendarWorkingDateExceptionValidationDayModeRequired,
    CalendarWorkingDateExceptionValidators.dayModeNotAllowed =>
      l10n.calendarWorkingDateExceptionValidationDayModeNotAllowed,
    CalendarWorkingDateExceptionValidators.workWindowRequired =>
      l10n.calendarWorkingDateExceptionValidationWorkWindowRequired,
    CalendarWorkingDateExceptionValidators.workWindowNotAllowed =>
      l10n.calendarWorkingDateExceptionValidationWorkWindowNotAllowed,
    CalendarWorkingDateExceptionValidators.workWindowInvalid =>
      l10n.calendarWorkingDateExceptionValidationWorkWindowInvalid,
    CalendarWorkingDateExceptionValidators.workWindowEndNotAfterStart =>
      l10n.calendarWorkingDateExceptionValidationWorkWindowOrder,
    'cancel_reason_required' => l10n.calendarCancelReasonRequired,
    _ => l10n.calendarErrorValidation,
  };
}
