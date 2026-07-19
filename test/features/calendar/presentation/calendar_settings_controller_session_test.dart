import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/calendar/data/calendar_settings_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_settings.dart';
import 'package:hs360/features/calendar/presentation/calendar_settings_controller.dart';

import '../fake_calendar_settings_repository.dart';

class _TestAuthController extends AuthController {
  _TestAuthController(this._session);
  AppSession? _session;

  @override
  FutureOr<AppSession?> build() => _session;

  void setSession(AppSession? session) {
    _session = session;
    state = AsyncData(session);
  }
}

AppSession _session({
  String userId = 'user-1',
  String tenantId = 'tenant-1',
  String tenantUserId = 'tu-1',
  Set<String> permissions = const {'settings.calendar.view'},
}) {
  return AppSession(
    userId: userId,
    email: 'test@example.com',
    tenantId: tenantId,
    tenantUserId: tenantUserId,
    accountType: 'user',
    displayName: 'Test User',
    preferredLocale: 'en',
    permissions: AppPermissions(isManager: false, permissions: permissions),
  );
}

/// [CalendarSettingsController] is a plain (non-keepAlive) provider. Without
/// a held subscription it would auto-dispose and rebuild between the
/// polling reads below instead of ever settling, so every test keeps one
/// alive via [keepAlive] for its duration.
ProviderContainer _container({
  required _TestAuthController auth,
  required FakeCalendarSettingsRepository repo,
}) {
  final container = ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(() => auth),
      calendarSettingsRepositoryProvider.overrideWith((ref) => repo),
    ],
  );
  final keepAlive = container.listen(
    calendarSettingsControllerProvider,
    (previous, next) {},
  );
  addTearDown(keepAlive.close);
  addTearDown(container.dispose);
  return container;
}

Future<void> _waitForLoad(ProviderContainer container) async {
  await container.read(authControllerProvider.future);
  for (var i = 0; i < 80; i++) {
    if (!container.read(calendarSettingsControllerProvider).isLoading) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('CalendarSettingsController stayed loading');
}

void main() {
  test(
    'identity change (tenantUserId only) resets and reloads settings',
    () async {
      final auth = _TestAuthController(_session(tenantUserId: 'tu-1'));
      final repo = FakeCalendarSettingsRepository(
        settings: CalendarSettings(
          timezoneName: 'Asia/Kuwait',
          canEdit: true,
          days: CalendarSettings.defaultUnreviewedDays(),
        ),
      );
      final container = _container(auth: auth, repo: repo);

      await _waitForLoad(container);
      expect(
        container.read(calendarSettingsControllerProvider).permissionDenied,
        isFalse,
      );
      final fetchesBefore = repo.fetchCount;

      // Same userId/tenantId, only tenantUserId changes (e.g. re-provisioned
      // membership row) — must still reset+reload like any other identity
      // change.
      auth.setSession(_session(tenantUserId: 'tu-2'));
      await _waitForLoad(container);

      expect(repo.fetchCount, greaterThan(fetchesBefore));
      expect(
        container.read(calendarSettingsControllerProvider).permissionDenied,
        isFalse,
      );
    },
  );

  test('session becoming null denies permission and stops loading', () async {
    final auth = _TestAuthController(_session());
    final repo = FakeCalendarSettingsRepository();
    final container = _container(auth: auth, repo: repo);

    await _waitForLoad(container);

    auth.setSession(null);
    await Future<void>.delayed(Duration.zero);

    final state = container.read(calendarSettingsControllerProvider);
    expect(state.permissionDenied, isTrue);
    expect(state.isLoading, isFalse);
  });

  test(
    'a delayed fetch from a stale tenant does not overwrite the new tenant state',
    () async {
      final auth = _TestAuthController(_session(tenantId: 'tenant-a'));
      final hold = Completer<void>();
      final repo = FakeCalendarSettingsRepository()
        ..holdFetchUntil = hold
        ..settingsForSession = (session) => CalendarSettings(
          timezoneName: session.tenantId == 'tenant-a'
              ? 'Asia/Kuwait'
              : 'Asia/Dubai',
          canEdit: true,
          days: CalendarSettings.defaultUnreviewedDays(),
        );
      final container = _container(auth: auth, repo: repo);

      // Kick the provider so its initial microtask load starts (and gates
      // on `hold`); the tenant-a result is already captured at this point,
      // like a real per-request read.
      container.read(calendarSettingsControllerProvider);
      await Future<void>.delayed(Duration.zero);
      expect(repo.fetchCount, 1);

      // Switch tenant before the first fetch resolves. This starts a
      // second, forced load() (its own request captures the tenant-b
      // result) and bumps the generation counter so the stale tenant-a
      // result is dropped once it resolves.
      auth.setSession(_session(tenantId: 'tenant-b'));
      await Future<void>.delayed(Duration.zero);

      // Let both gated fetches (tenant-a and tenant-b) resolve now.
      hold.complete();
      await _waitForLoad(container);

      final state = container.read(calendarSettingsControllerProvider);
      expect(state.timezoneName, 'Asia/Dubai');
      expect(repo.fetchCount, 2);
    },
  );

  test('delayed save after tenant switch does not write success into new identity', () async {
    final hold = Completer<void>();
    final auth = _TestAuthController(
      _session(permissions: const {'settings.calendar.view', 'settings.calendar.edit'}),
    );
    final repo = FakeCalendarSettingsRepository(
      settings: CalendarSettings(
        timezoneName: 'Asia/Kuwait',
        timezoneConfirmed: true,
        workingScheduleConfigured: true,
        canEdit: true,
        days: CalendarSettings.defaultUnreviewedDays()
            .map(
              (d) => d.isoWeekday >= 6
                  ? d.copyWith(mode: TenantWorkingDayMode.dayOff)
                  : d.copyWith(
                      mode: TenantWorkingDayMode.workingHours,
                      workStart: '08:00',
                      workEnd: '17:00',
                    ),
            )
            .toList(),
      ),
    )..holdUpdateUntil = hold;
    final container = _container(auth: auth, repo: repo);
    addTearDown(container.dispose);

    container.read(calendarSettingsControllerProvider);
    await _waitForLoad(container);

    final notifier = container.read(calendarSettingsControllerProvider.notifier);
    notifier.updateTimezone('Asia/Riyadh');
    final saveFuture = notifier.save();
    await Future<void>.delayed(Duration.zero);
    expect(repo.updateCount, 1);

    auth.setSession(
      _session(
        tenantId: 'tenant-b',
        permissions: const {'settings.calendar.view', 'settings.calendar.edit'},
      ),
    );
    await Future<void>.delayed(Duration.zero);
    hold.complete();
    final saved = await saveFuture;
    expect(saved, isFalse);

    final state = container.read(calendarSettingsControllerProvider);
    expect(state.saveSuccess, isFalse);
    // Stale save must not apply Asia/Riyadh into the new tenant's state.
    expect(state.timezoneName, isNot('Asia/Riyadh'));
  });
}
