import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/finance_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/calendar_settings_repository.dart';
import '../domain/calendar_permissions.dart';
import '../domain/calendar_settings.dart';
import '../domain/calendar_settings_validator.dart';
import 'calendar_settings_state.dart';

part 'calendar_settings_controller.g.dart';

@riverpod
class CalendarSettingsController extends _$CalendarSettingsController {
  @override
  CalendarSettingsState build() {
    Future.microtask(load);
    return const CalendarSettingsState(isLoading: true);
  }

  Future<void> load({bool force = false}) async {
    if (!force && !state.isLoading && state.days.isNotEmpty) return;

    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null || !canViewCalendarSettings(session)) {
      state = const CalendarSettingsState(
        isLoading: false,
        permissionDenied: true,
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      saveSuccess: false,
    );
    try {
      final settings = await ref
          .read(calendarSettingsRepositoryProvider)
          .fetchSettings(session);
      state = CalendarSettingsState.fromSettings(
        settings,
      ).copyWith(canEdit: settings.canEdit, isDirty: false);
    } on FinanceException catch (e) {
      state = state.copyWith(isLoading: false, errorCode: e.code);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorCode: FinanceException.unknown,
      );
    }
  }

  void updateTimezone(String value) {
    state = state.copyWith(
      timezoneName: value,
      isDirty: true,
      saveSuccess: false,
      fieldErrors: {},
    );
  }

  void updateRemindEventWorkdayStart(bool value) {
    state = state.copyWith(
      remindEventWorkdayStart: value,
      isDirty: true,
      saveSuccess: false,
    );
  }

  void updateRemindPreviousWorkdayStart(bool value) {
    state = state.copyWith(
      remindPreviousWorkdayStart: value,
      isDirty: true,
      saveSuccess: false,
    );
  }

  void updateDay(int isoWeekday, WorkingDayRow day) {
    final days = [...state.days];
    final index = days.indexWhere((row) => row.isoWeekday == isoWeekday);
    if (index >= 0) {
      days[index] = day;
    } else {
      days.add(day);
    }
    days.sort((a, b) => a.isoWeekday.compareTo(b.isoWeekday));
    state = state.copyWith(days: days, isDirty: true, saveSuccess: false);
  }

  Future<bool> save() async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null || !canEditCalendarSettings(session)) {
      state = state.copyWith(permissionDenied: true);
      return false;
    }

    final validation = CalendarSettingsValidator.validateForSave(
      timezoneName: state.timezoneName,
      days: state.days,
    );
    if (!validation.isValid) {
      state = state.copyWith(fieldErrors: validation.fieldErrors);
      return false;
    }

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      fieldErrors: {},
      saveSuccess: false,
    );
    try {
      final settings = await ref
          .read(calendarSettingsRepositoryProvider)
          .updateSettings(
            session,
            timezoneName: state.timezoneName.trim(),
            remindEventWorkdayStart: state.remindEventWorkdayStart,
            remindPreviousWorkdayStart: state.remindPreviousWorkdayStart,
            days: state.days,
          );
      state = CalendarSettingsState.fromSettings(
        settings,
      ).copyWith(isSaving: false, saveSuccess: true, isDirty: false);
      return true;
    } on FinanceException catch (e) {
      state = state.copyWith(isSaving: false, errorCode: e.code);
      return false;
    } catch (_) {
      state = state.copyWith(
        isSaving: false,
        errorCode: FinanceException.unknown,
      );
      return false;
    }
  }

  Future<List<String>> searchTimezones(String query) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null || !canViewCalendarSettings(session)) {
      return const [];
    }
    try {
      return ref
          .read(calendarSettingsRepositoryProvider)
          .listTimezones(session, search: query.trim().isEmpty ? null : query);
    } catch (_) {
      return const [];
    }
  }
}
