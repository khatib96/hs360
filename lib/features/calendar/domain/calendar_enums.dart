/// Calendar event type (`calendar_event_type`).
enum CalendarEventType {
  refillDue,
  billingDue,
  paymentDue,
  maintenanceDue,
  followUp,
  trialEnding,
  contractStart,
  contractEnd,
  custom;

  static CalendarEventType? fromRpc(String value) {
    return switch (value) {
      'refill_due' => CalendarEventType.refillDue,
      'billing_due' => CalendarEventType.billingDue,
      'payment_due' => CalendarEventType.paymentDue,
      'maintenance_due' => CalendarEventType.maintenanceDue,
      'follow_up' => CalendarEventType.followUp,
      'trial_ending' => CalendarEventType.trialEnding,
      'contract_start' => CalendarEventType.contractStart,
      'contract_end' => CalendarEventType.contractEnd,
      'custom' => CalendarEventType.custom,
      _ => null,
    };
  }

  String get rpcValue => switch (this) {
    CalendarEventType.refillDue => 'refill_due',
    CalendarEventType.billingDue => 'billing_due',
    CalendarEventType.paymentDue => 'payment_due',
    CalendarEventType.maintenanceDue => 'maintenance_due',
    CalendarEventType.followUp => 'follow_up',
    CalendarEventType.trialEnding => 'trial_ending',
    CalendarEventType.contractStart => 'contract_start',
    CalendarEventType.contractEnd => 'contract_end',
    CalendarEventType.custom => 'custom',
  };
}

/// Calendar event status (`calendar_event_status` from migration 003).
enum CalendarEventStatus {
  pending,
  done,
  missed,
  cancelled,
  rescheduled;

  static CalendarEventStatus? fromRpc(String value) {
    return switch (value) {
      'pending' => CalendarEventStatus.pending,
      'done' => CalendarEventStatus.done,
      'missed' => CalendarEventStatus.missed,
      'cancelled' => CalendarEventStatus.cancelled,
      'rescheduled' => CalendarEventStatus.rescheduled,
      _ => null,
    };
  }

  String get rpcValue => switch (this) {
    CalendarEventStatus.pending => 'pending',
    CalendarEventStatus.done => 'done',
    CalendarEventStatus.missed => 'missed',
    CalendarEventStatus.cancelled => 'cancelled',
    CalendarEventStatus.rescheduled => 'rescheduled',
  };
}

/// Provenance kind (`calendar_event_source_kind`).
enum CalendarEventSourceKind {
  manual,
  contractGenerated;

  static CalendarEventSourceKind? fromRpc(String value) {
    return switch (value) {
      'manual' => CalendarEventSourceKind.manual,
      'contract_generated' => CalendarEventSourceKind.contractGenerated,
      _ => null,
    };
  }

  String get rpcValue => switch (this) {
    CalendarEventSourceKind.manual => 'manual',
    CalendarEventSourceKind.contractGenerated => 'contract_generated',
  };
}

/// Read ACL scope returned by calendar read RPCs.
enum CalendarReadScope {
  tenantWide,
  assignedOnly;

  static CalendarReadScope? fromRpc(String value) {
    return switch (value) {
      'tenant_wide' => CalendarReadScope.tenantWide,
      'assigned_only' => CalendarReadScope.assignedOnly,
      _ => null,
    };
  }

  String get rpcValue => switch (this) {
    CalendarReadScope.tenantWide => 'tenant_wide',
    CalendarReadScope.assignedOnly => 'assigned_only',
  };
}

/// Per-event schedule placement relative to the working calendar.
enum CalendarScheduleState {
  workingDay,
  nonWorkingDay,
  scheduleUnconfigured,
  dayOffOverridden;

  static CalendarScheduleState? fromRpc(String value) {
    return switch (value) {
      'working_day' => CalendarScheduleState.workingDay,
      'non_working_day' => CalendarScheduleState.nonWorkingDay,
      'schedule_unconfigured' => CalendarScheduleState.scheduleUnconfigured,
      'day_off_overridden' => CalendarScheduleState.dayOffOverridden,
      _ => null,
    };
  }

  String get rpcValue => switch (this) {
    CalendarScheduleState.workingDay => 'working_day',
    CalendarScheduleState.nonWorkingDay => 'non_working_day',
    CalendarScheduleState.scheduleUnconfigured => 'schedule_unconfigured',
    CalendarScheduleState.dayOffOverridden => 'day_off_overridden',
  };
}

/// Per-event overdue derivation state.
enum CalendarOverdueState {
  notApplicable,
  scheduleUnconfigured,
  overdue,
  notOverdue;

  static CalendarOverdueState? fromRpc(String value) {
    return switch (value) {
      'not_applicable' => CalendarOverdueState.notApplicable,
      'schedule_unconfigured' => CalendarOverdueState.scheduleUnconfigured,
      'overdue' => CalendarOverdueState.overdue,
      'not_overdue' => CalendarOverdueState.notOverdue,
      _ => null,
    };
  }

  String get rpcValue => switch (this) {
    CalendarOverdueState.notApplicable => 'not_applicable',
    CalendarOverdueState.scheduleUnconfigured => 'schedule_unconfigured',
    CalendarOverdueState.overdue => 'overdue',
    CalendarOverdueState.notOverdue => 'not_overdue',
  };
}

/// Summary bucket state for overdue events outside the visible range.
enum CalendarOverdueOutsideRangeState {
  scheduleUnconfigured,
  available;

  static CalendarOverdueOutsideRangeState? fromRpc(String value) {
    return switch (value) {
      'schedule_unconfigured' =>
        CalendarOverdueOutsideRangeState.scheduleUnconfigured,
      'available' => CalendarOverdueOutsideRangeState.available,
      _ => null,
    };
  }

  String get rpcValue => switch (this) {
    CalendarOverdueOutsideRangeState.scheduleUnconfigured =>
      'schedule_unconfigured',
    CalendarOverdueOutsideRangeState.available => 'available',
  };
}
