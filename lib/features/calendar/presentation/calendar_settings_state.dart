import '../domain/calendar_settings.dart';

class CalendarSettingsState {
  const CalendarSettingsState({
    this.isLoading = false,
    this.isSaving = false,
    this.permissionDenied = false,
    this.canEdit = false,
    this.workingScheduleConfigured = false,
    this.timezoneName = '',
    this.legacyTimezoneSuggestion,
    this.remindEventWorkdayStart = true,
    this.remindPreviousWorkdayStart = true,
    this.days = const [],
    this.fieldErrors = const {},
    this.errorCode,
    this.saveSuccess = false,
    this.isDirty = false,
  });

  final bool isLoading;
  final bool isSaving;
  final bool permissionDenied;
  final bool canEdit;
  final bool workingScheduleConfigured;
  final String timezoneName;
  final String? legacyTimezoneSuggestion;
  final bool remindEventWorkdayStart;
  final bool remindPreviousWorkdayStart;
  final List<WorkingDayRow> days;
  final Map<String, String> fieldErrors;
  final String? errorCode;
  final bool saveSuccess;
  final bool isDirty;

  CalendarSettingsState copyWith({
    bool? isLoading,
    bool? isSaving,
    bool? permissionDenied,
    bool? canEdit,
    bool? workingScheduleConfigured,
    String? timezoneName,
    String? legacyTimezoneSuggestion,
    bool? remindEventWorkdayStart,
    bool? remindPreviousWorkdayStart,
    List<WorkingDayRow>? days,
    Map<String, String>? fieldErrors,
    String? errorCode,
    bool clearError = false,
    bool? saveSuccess,
    bool? isDirty,
  }) {
    return CalendarSettingsState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      canEdit: canEdit ?? this.canEdit,
      workingScheduleConfigured:
          workingScheduleConfigured ?? this.workingScheduleConfigured,
      timezoneName: timezoneName ?? this.timezoneName,
      legacyTimezoneSuggestion:
          legacyTimezoneSuggestion ?? this.legacyTimezoneSuggestion,
      remindEventWorkdayStart:
          remindEventWorkdayStart ?? this.remindEventWorkdayStart,
      remindPreviousWorkdayStart:
          remindPreviousWorkdayStart ?? this.remindPreviousWorkdayStart,
      days: days ?? this.days,
      fieldErrors: fieldErrors ?? this.fieldErrors,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      saveSuccess: saveSuccess ?? this.saveSuccess,
      isDirty: isDirty ?? this.isDirty,
    );
  }

  static CalendarSettingsState fromSettings(CalendarSettings settings) {
    return CalendarSettingsState(
      isLoading: false,
      canEdit: settings.canEdit,
      workingScheduleConfigured: settings.workingScheduleConfigured,
      timezoneName: settings.timezoneName ?? '',
      legacyTimezoneSuggestion: settings.legacyTimezoneSuggestion,
      remindEventWorkdayStart: settings.remindEventWorkdayStart,
      remindPreviousWorkdayStart: settings.remindPreviousWorkdayStart,
      days: settings.days,
    );
  }
}
