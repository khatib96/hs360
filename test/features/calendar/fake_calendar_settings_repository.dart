import 'dart:async';

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

  /// When set, [fetchSettings] awaits this before returning — lets tests
  /// switch identity mid-flight to assert stale responses are discarded.
  Completer<void>? holdFetchUntil;
  AppSession? lastFetchSession;

  /// When set, overrides the returned settings per request, evaluated
  /// *before* the [holdFetchUntil] gate — mirrors a real per-tenant DB read
  /// tied to the request's session rather than a field mutated later.
  CalendarSettings Function(AppSession session)? settingsForSession;

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
    lastFetchSession = session;
    // Captured before the gate, like a real per-request DB read — a value
    // mutated on the fake *after* the call started must not leak in.
    final result = settingsForSession?.call(session) ?? settings;
    final gate = holdFetchUntil;
    if (gate != null) await gate.future;
    final error = fetchError;
    if (error != null) {
      if (error is FinanceException) throw error;
      throw const FinanceException(code: FinanceException.unknown);
    }
    return result;
  }

  /// When set, [updateSettings] awaits this before returning — lets tests
  /// switch identity mid-flight to assert stale saves are discarded.
  Completer<void>? holdUpdateUntil;
  AppSession? lastUpdateSession;

  @override
  Future<CalendarSettings> updateSettings(
    AppSession session, {
    required String timezoneName,
    required bool remindEventWorkdayStart,
    required bool remindPreviousWorkdayStart,
    required List<WorkingDayRow> days,
  }) async {
    updateCount++;
    lastUpdateSession = session;
    final gate = holdUpdateUntil;
    if (gate != null) await gate.future;
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
