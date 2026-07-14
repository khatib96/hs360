import 'package:hs360/l10n/app_localizations.dart';

import '../domain/calendar_enums.dart';
import '../domain/calendar_settings.dart';

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
