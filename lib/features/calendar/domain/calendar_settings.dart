enum TenantWorkingDayMode {
  unreviewed,
  dayOff,
  workingHours,
  hours24;

  static TenantWorkingDayMode? fromRpc(String? value) {
    return switch (value) {
      null => TenantWorkingDayMode.unreviewed,
      'day_off' => TenantWorkingDayMode.dayOff,
      'working_hours' => TenantWorkingDayMode.workingHours,
      '24_hours' => TenantWorkingDayMode.hours24,
      _ => null,
    };
  }

  String? toRpc() {
    return switch (this) {
      TenantWorkingDayMode.unreviewed => null,
      TenantWorkingDayMode.dayOff => 'day_off',
      TenantWorkingDayMode.workingHours => 'working_hours',
      TenantWorkingDayMode.hours24 => '24_hours',
    };
  }
}

class WorkingDayRow {
  const WorkingDayRow({
    required this.isoWeekday,
    this.mode = TenantWorkingDayMode.unreviewed,
    this.workStart = '',
    this.workEnd = '',
  });

  final int isoWeekday;
  final TenantWorkingDayMode mode;
  final String workStart;
  final String workEnd;

  WorkingDayRow copyWith({
    TenantWorkingDayMode? mode,
    String? workStart,
    String? workEnd,
  }) {
    return WorkingDayRow(
      isoWeekday: isoWeekday,
      mode: mode ?? this.mode,
      workStart: workStart ?? this.workStart,
      workEnd: workEnd ?? this.workEnd,
    );
  }
}

class CalendarSettings {
  const CalendarSettings({
    this.timezoneName,
    this.timezoneConfirmed = false,
    this.legacyTimezoneSuggestion,
    this.workingScheduleConfigured = false,
    this.remindEventWorkdayStart = true,
    this.remindPreviousWorkdayStart = true,
    this.canEdit = false,
    this.days = const [],
  });

  final String? timezoneName;
  final bool timezoneConfirmed;
  final String? legacyTimezoneSuggestion;
  final bool workingScheduleConfigured;
  final bool remindEventWorkdayStart;
  final bool remindPreviousWorkdayStart;
  final bool canEdit;
  final List<WorkingDayRow> days;

  CalendarSettings copyWith({
    String? timezoneName,
    bool? timezoneConfirmed,
    String? legacyTimezoneSuggestion,
    bool? workingScheduleConfigured,
    bool? remindEventWorkdayStart,
    bool? remindPreviousWorkdayStart,
    bool? canEdit,
    List<WorkingDayRow>? days,
  }) {
    return CalendarSettings(
      timezoneName: timezoneName ?? this.timezoneName,
      timezoneConfirmed: timezoneConfirmed ?? this.timezoneConfirmed,
      legacyTimezoneSuggestion:
          legacyTimezoneSuggestion ?? this.legacyTimezoneSuggestion,
      workingScheduleConfigured:
          workingScheduleConfigured ?? this.workingScheduleConfigured,
      remindEventWorkdayStart:
          remindEventWorkdayStart ?? this.remindEventWorkdayStart,
      remindPreviousWorkdayStart:
          remindPreviousWorkdayStart ?? this.remindPreviousWorkdayStart,
      canEdit: canEdit ?? this.canEdit,
      days: days ?? this.days,
    );
  }

  static List<WorkingDayRow> defaultUnreviewedDays() {
    return List.generate(7, (index) => WorkingDayRow(isoWeekday: index + 1));
  }
}
