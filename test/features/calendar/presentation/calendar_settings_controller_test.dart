import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/calendar/data/calendar_settings_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_settings.dart';
import 'package:hs360/features/calendar/presentation/calendar_settings_controller.dart';

import '../fake_calendar_settings_repository.dart';

class _TestAuthController extends AuthController {
  _TestAuthController(this._session);
  final AppSession? _session;

  @override
  FutureOr<AppSession?> build() => _session;
}

AppSession _session({Set<String> permissions = const {}}) {
  return AppSession(
    userId: 'user-1',
    email: 'test@example.com',
    tenantId: 'tenant-1',
    tenantUserId: 'tu-1',
    accountType: 'user',
    displayName: 'Test User',
    preferredLocale: 'en',
    permissions: AppPermissions(isManager: false, permissions: permissions),
  );
}

List<WorkingDayRow> _validDays() {
  return List.generate(
    7,
    (index) =>
        WorkingDayRow(isoWeekday: index + 1, mode: TenantWorkingDayMode.dayOff),
  );
}

ProviderContainer _container({
  required AppSession session,
  required FakeCalendarSettingsRepository repo,
}) {
  return ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(() => _TestAuthController(session)),
      calendarSettingsRepositoryProvider.overrideWith((ref) => repo),
    ],
  );
}

Future<void> _waitForLoad(ProviderContainer container) async {
  await container.read(authControllerProvider.future);
  await container.read(calendarSettingsControllerProvider.notifier).load();
}

void main() {
  test('load denies without permission', () async {
    final container = _container(
      session: _session(),
      repo: FakeCalendarSettingsRepository(),
    );
    addTearDown(container.dispose);

    await _waitForLoad(container);
    final state = container.read(calendarSettingsControllerProvider);
    expect(state.permissionDenied, isTrue);
    expect(state.isLoading, isFalse);
  });

  test('load fetches settings for viewer', () async {
    final repo = FakeCalendarSettingsRepository(
      settings: CalendarSettings(
        timezoneName: 'UTC',
        canEdit: false,
        days: _validDays(),
      ),
    );
    final container = _container(
      session: _session(permissions: {'settings.calendar.view'}),
      repo: repo,
    );
    addTearDown(container.dispose);

    await _waitForLoad(container);
    final state = container.read(calendarSettingsControllerProvider);
    expect(state.permissionDenied, isFalse);
    expect(state.timezoneName, 'UTC');
    expect(state.canEdit, isFalse);
    expect(repo.fetchCount, greaterThanOrEqualTo(1));
  });

  test('save validates before calling repository', () async {
    final repo = FakeCalendarSettingsRepository(
      settings: CalendarSettings(
        timezoneName: 'Asia/Kuwait',
        canEdit: true,
        days: CalendarSettings.defaultUnreviewedDays(),
      ),
    );
    final container = _container(
      session: _session(permissions: {'settings.calendar.edit'}),
      repo: repo,
    );
    addTearDown(container.dispose);

    await _waitForLoad(container);
    final notifier = container.read(
      calendarSettingsControllerProvider.notifier,
    );

    final saved = await notifier.save();
    expect(saved, isFalse);
    expect(repo.updateCount, 0);
  });

  test('save persists valid configuration', () async {
    final repo = FakeCalendarSettingsRepository(
      settings: CalendarSettings(
        timezoneName: 'Asia/Kuwait',
        canEdit: true,
        days: _validDays(),
      ),
    );
    final container = _container(
      session: _session(permissions: {'settings.calendar.edit'}),
      repo: repo,
    );
    addTearDown(container.dispose);

    await _waitForLoad(container);
    final notifier = container.read(
      calendarSettingsControllerProvider.notifier,
    );

    final saved = await notifier.save();
    expect(saved, isTrue);
    expect(repo.updateCount, 1);
    expect(
      container.read(calendarSettingsControllerProvider).saveSuccess,
      isTrue,
    );
    expect(
      container
          .read(calendarSettingsControllerProvider)
          .workingScheduleConfigured,
      isTrue,
    );
  });

  test('save surfaces repository validation error', () async {
    final repo = FakeCalendarSettingsRepository(
      settings: CalendarSettings(
        timezoneName: 'Asia/Kuwait',
        canEdit: true,
        days: _validDays(),
      ),
      updateError: const FinanceException(
        code: FinanceException.validationFailed,
      ),
    );
    final container = _container(
      session: _session(permissions: {'settings.calendar.edit'}),
      repo: repo,
    );
    addTearDown(container.dispose);

    await _waitForLoad(container);
    final notifier = container.read(
      calendarSettingsControllerProvider.notifier,
    );

    final saved = await notifier.save();
    expect(saved, isFalse);
    expect(
      container.read(calendarSettingsControllerProvider).errorCode,
      FinanceException.validationFailed,
    );
  });

  test('searchTimezones returns filtered results', () async {
    final repo = FakeCalendarSettingsRepository();
    final container = _container(
      session: _session(permissions: {'settings.calendar.view'}),
      repo: repo,
    );
    addTearDown(container.dispose);

    await _waitForLoad(container);
    final notifier = container.read(
      calendarSettingsControllerProvider.notifier,
    );

    final results = await notifier.searchTimezones('dubai');
    expect(results, ['Asia/Dubai']);
  });

  test('updateTimezone marks state dirty', () async {
    final repo = FakeCalendarSettingsRepository(
      settings: CalendarSettings(
        timezoneName: 'Asia/Kuwait',
        canEdit: true,
        days: _validDays(),
      ),
    );
    final container = _container(
      session: _session(permissions: {'settings.calendar.edit'}),
      repo: repo,
    );
    addTearDown(container.dispose);

    await _waitForLoad(container);
    final notifier = container.read(
      calendarSettingsControllerProvider.notifier,
    );
    notifier.updateTimezone('Asia/Dubai');

    expect(container.read(calendarSettingsControllerProvider).isDirty, isTrue);
  });
}
