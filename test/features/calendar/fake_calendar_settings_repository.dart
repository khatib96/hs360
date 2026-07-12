import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/features/calendar/data/calendar_settings_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_settings.dart';
import 'package:hs360/features/auth/domain/app_session.dart';

class FakeCalendarSettingsRepository extends CalendarSettingsRepository {
  FakeCalendarSettingsRepository({
    CalendarSettings? settings,
    this.fetchError,
    this.updateError,
    List<String>? timezones,
  }) : settings = settings ?? _defaultSettings(),
       timezones = timezones ?? const ['Asia/Kuwait', 'Asia/Dubai', 'UTC'],
       super(null);

  CalendarSettings settings;
  final Object? fetchError;
  final Object? updateError;
  final List<String> timezones;

  Map<String, dynamic>? lastUpdatePayload;
  String? lastTimezoneSearch;
  int fetchCount = 0;
  int updateCount = 0;

  static CalendarSettings _defaultSettings() {
    return CalendarSettings(
      timezoneName: 'Asia/Kuwait',
      timezoneConfirmed: true,
      workingScheduleConfigured: false,
      canEdit: true,
      days: CalendarSettings.defaultUnreviewedDays(),
    );
  }

  @override
  Future<CalendarSettings> fetchSettings(AppSession session) async {
    fetchCount++;
    final error = fetchError;
    if (error != null) {
      if (error is FinanceException) throw error;
      throw const FinanceException(code: FinanceException.unknown);
    }
    return settings;
  }

  @override
  Future<CalendarSettings> updateSettings(
    AppSession session, {
    required String timezoneName,
    required bool remindEventWorkdayStart,
    required bool remindPreviousWorkdayStart,
    required List<WorkingDayRow> days,
  }) async {
    updateCount++;
    final error = updateError;
    if (error != null) {
      if (error is FinanceException) throw error;
      throw const FinanceException(code: FinanceException.unknown);
    }
    settings = settings.copyWith(
      timezoneName: timezoneName,
      remindEventWorkdayStart: remindEventWorkdayStart,
      remindPreviousWorkdayStart: remindPreviousWorkdayStart,
      workingScheduleConfigured: true,
      days: days,
    );
    return settings;
  }

  @override
  Future<List<String>> listTimezones(
    AppSession session, {
    String? search,
  }) async {
    lastTimezoneSearch = search;
    if (search == null || search.isEmpty) return timezones;
    final query = search.toLowerCase();
    return timezones.where((tz) => tz.toLowerCase().contains(query)).toList();
  }
}
