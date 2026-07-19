import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/finance_exception.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/calendar_settings_repository.dart';
import '../domain/calendar_permissions.dart';
import '../domain/calendar_settings.dart';
import '../domain/calendar_settings_validator.dart';
import 'calendar_settings_state.dart';

part 'calendar_settings_controller.g.dart';

@riverpod
class CalendarSettingsController extends _$CalendarSettingsController {
  /// Bumped on every load and on identity change so a delayed response from
  /// a stale user/tenant/tenant-user cannot overwrite newer state.
  int _generation = 0;

  @override
  CalendarSettingsState build() {
    ref.listen(authControllerProvider, (previous, next) {
      final previousSession = previous?.valueOrNull;
      final nextSession = next.valueOrNull;
      if (nextSession == null) {
        _generation++;
        state = const CalendarSettingsState(
          isLoading: false,
          permissionDenied: true,
        );
        return;
      }
      if (_shouldReloadForSession(previousSession, nextSession)) {
        _generation++;
        state = const CalendarSettingsState(isLoading: true);
        load(force: true);
      }
    });
    Future.microtask(load);
    return const CalendarSettingsState(isLoading: true);
  }

  bool _shouldReloadForSession(AppSession? previous, AppSession next) {
    if (previous == null) return true;
    return previous.userId != next.userId ||
        previous.tenantId != next.tenantId ||
        previous.tenantUserId != next.tenantUserId;
  }

  Future<void> load({bool force = false}) async {
    if (!force && !state.isLoading && state.days.isNotEmpty) return;

    // Captured, not bumped: ordinary concurrent load() calls (e.g. the
    // implicit initial Future.microtask(load) racing an explicit caller)
    // share this generation and both may write. Only an identity change
    // (see the ref.listen above) bumps _generation to invalidate in-flight
    // stale-identity responses.
    final gen = _generation;
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null || !canViewCalendarSettings(session)) {
      if (gen != _generation) return;
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
      if (gen != _generation) return;
      state = CalendarSettingsState.fromSettings(
        settings,
      ).copyWith(canEdit: settings.canEdit, isDirty: false);
    } on FinanceException catch (e) {
      if (gen != _generation) return;
      state = state.copyWith(isLoading: false, errorCode: e.code);
    } catch (_) {
      if (gen != _generation) return;
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
    final gen = _generation;
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null || !canEditCalendarSettings(session)) {
      if (gen != _generation) return false;
      state = state.copyWith(permissionDenied: true);
      return false;
    }
    final capturedUserId = session.userId;
    final capturedTenantId = session.tenantId;
    final capturedTenantUserId = session.tenantUserId;

    final validation = CalendarSettingsValidator.validateForSave(
      timezoneName: state.timezoneName,
      days: state.days,
    );
    if (!validation.isValid) {
      if (gen != _generation) return false;
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
      if (!_isCurrentSave(gen, capturedUserId, capturedTenantId, capturedTenantUserId)) {
        return false;
      }
      state = CalendarSettingsState.fromSettings(
        settings,
      ).copyWith(isSaving: false, saveSuccess: true, isDirty: false);
      return true;
    } on FinanceException catch (e) {
      if (!_isCurrentSave(gen, capturedUserId, capturedTenantId, capturedTenantUserId)) {
        return false;
      }
      state = state.copyWith(isSaving: false, errorCode: e.code);
      return false;
    } catch (_) {
      if (!_isCurrentSave(gen, capturedUserId, capturedTenantId, capturedTenantUserId)) {
        return false;
      }
      state = state.copyWith(
        isSaving: false,
        errorCode: FinanceException.unknown,
      );
      return false;
    }
  }

  bool _isCurrentSave(
    int gen,
    String userId,
    String tenantId,
    String tenantUserId,
  ) {
    if (gen != _generation) return false;
    final current = ref.read(authControllerProvider).valueOrNull;
    return current != null &&
        current.userId == userId &&
        current.tenantId == tenantId &&
        current.tenantUserId == tenantUserId;
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
