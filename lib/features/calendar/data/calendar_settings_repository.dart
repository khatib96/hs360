import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/finance_exception.dart';
import '../../../core/network/supabase_providers.dart';
import '../../auth/domain/app_session.dart';
import '../domain/calendar_permissions.dart';
import '../domain/calendar_settings.dart';
import 'calendar_settings_rpc_mapper.dart';

part 'calendar_settings_repository.g.dart';

@Riverpod(keepAlive: true)
CalendarSettingsRepository calendarSettingsRepository(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return CalendarSettingsRepository(client);
}

class CalendarSettingsRepository {
  CalendarSettingsRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) throw FinanceException.notConfigured();
    return client;
  }

  void _assertCanView(AppSession session) {
    if (!canViewCalendarSettings(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
  }

  void _assertCanEdit(AppSession session) {
    if (!canEditCalendarSettings(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
  }

  Future<CalendarSettings> fetchSettings(AppSession session) async {
    _assertCanView(session);
    try {
      final result = await _requireClient.rpc('get_calendar_settings');
      return mapCalendarSettingsFromRpc(
        Map<String, dynamic>.from(result as Map),
      );
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<CalendarSettings> updateSettings(
    AppSession session, {
    required String timezoneName,
    required bool remindEventWorkdayStart,
    required bool remindPreviousWorkdayStart,
    required List<WorkingDayRow> days,
  }) async {
    _assertCanEdit(session);
    try {
      final result = await _requireClient.rpc(
        'update_calendar_settings',
        params: {
          'p_data': mapCalendarSettingsToUpdatePayload(
            timezoneName: timezoneName,
            remindEventWorkdayStart: remindEventWorkdayStart,
            remindPreviousWorkdayStart: remindPreviousWorkdayStart,
            days: days,
          ),
        },
      );
      return mapCalendarSettingsFromRpc(
        Map<String, dynamic>.from(result as Map),
      );
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<List<String>> listTimezones(
    AppSession session, {
    String? search,
  }) async {
    _assertCanView(session);
    try {
      final rows = await _requireClient.rpc(
        'list_calendar_timezones',
        params: {'p_search': search},
      );
      return mapTimezoneListFromRpc(rows);
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }
}
