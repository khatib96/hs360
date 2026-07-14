import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/calendar_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/calendar/data/calendar_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_filters.dart';
import 'package:hs360/features/calendar/presentation/calendar_controller.dart';

import '../fake_calendar_repository.dart';

class _TestAuthController extends AuthController {
  _TestAuthController(this._session);
  final AppSession _session;

  @override
  FutureOr<AppSession?> build() => _session;
}

AppSession _session() => AppSession(
  userId: 'user-1',
  email: 'test@example.com',
  tenantId: 'tenant-1',
  tenantUserId: 'tu-1',
  accountType: 'user',
  displayName: 'Test',
  preferredLocale: 'en',
  permissions: AppPermissions(
    isManager: false,
    permissions: const {'calendar.view'},
  ),
);

Future<void> _boot(ProviderContainer c) async {
  c.read(calendarControllerProvider);
  await c.read(calendarControllerProvider.notifier).ensureWeekStart(0);
  await Future<void>.delayed(Duration.zero);
  for (var i = 0; i < 40; i++) {
    final s = c.read(calendarControllerProvider);
    if (!s.isBusy) return;
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late CalendarClock previous;

  setUp(() {
    previous = calendarClock;
    calendarClock = () => DateTime(2026, 7, 14);
  });

  tearDown(() => calendarClock = previous);

  test('retrySummary preserves agenda and clears only summary error', () async {
    final repo = FakeCalendarRepository(
      rangeError: const CalendarException(code: CalendarException.notAvailable),
    );
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(
          () => _TestAuthController(_session()),
        ),
        calendarRepositoryProvider.overrideWith((ref) => repo),
      ],
    );
    addTearDown(container.dispose);

    await _boot(container);
    expect(
      container.read(calendarControllerProvider).summaryErrorCode,
      CalendarException.notAvailable,
    );
    expect(container.read(calendarControllerProvider).agendaEvents, isNotEmpty);

    repo.rangeError = null;
    await container.read(calendarControllerProvider.notifier).retrySummary();
    await Future<void>.delayed(Duration.zero);
    for (var i = 0; i < 40; i++) {
      if (!container.read(calendarControllerProvider).isBusy) break;
      await Future<void>.delayed(Duration.zero);
    }

    final state = container.read(calendarControllerProvider);
    expect(state.summaryErrorCode, isNull);
    expect(state.isSummaryQueryAligned, isTrue);
    expect(state.agendaEvents, isNotEmpty);
  });

  test('setFilters no-op when identity unchanged', () async {
    final repo = FakeCalendarRepository();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(
          () => _TestAuthController(_session()),
        ),
        calendarRepositoryProvider.overrideWith((ref) => repo),
      ],
    );
    addTearDown(container.dispose);

    await _boot(container);
    final before = repo.getRangeSummaryCount;
    await container
        .read(calendarControllerProvider.notifier)
        .setFilters(CalendarFilters.empty);
    expect(repo.getRangeSummaryCount, before);
  });

  test('concurrent retrySummary double-call protection', () async {
    final hold = Completer<void>();
    final repo = FakeCalendarRepository(
      rangeError: const CalendarException(code: CalendarException.notAvailable),
    );
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(
          () => _TestAuthController(_session()),
        ),
        calendarRepositoryProvider.overrideWith((ref) => repo),
      ],
    );
    addTearDown(container.dispose);

    await _boot(container);
    expect(
      container.read(calendarControllerProvider).summaryErrorCode,
      isNotNull,
    );

    repo
      ..rangeError = null
      ..holdSummaryUntil = hold;
    final first = container
        .read(calendarControllerProvider.notifier)
        .retrySummary();
    await Future<void>.delayed(Duration.zero);
    final summaryCallsWhileLoading = repo.getRangeSummaryCount;
    final second = container
        .read(calendarControllerProvider.notifier)
        .retrySummary();
    await Future<void>.delayed(Duration.zero);
    expect(repo.getRangeSummaryCount, summaryCallsWhileLoading);

    hold.complete();
    await first;
    await second;
    for (var i = 0; i < 40; i++) {
      if (!container.read(calendarControllerProvider).isBusy) break;
      await Future<void>.delayed(Duration.zero);
    }
    expect(container.read(calendarControllerProvider).summaryErrorCode, isNull);
  });

  test('changed filters clear days until aligned', () async {
    final hold = Completer<void>();
    final repo = FakeCalendarRepository()..holdSummaryUntil = hold;
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(
          () => _TestAuthController(_session()),
        ),
        calendarRepositoryProvider.overrideWith((ref) => repo),
      ],
    );
    addTearDown(container.dispose);

    final boot = container
        .read(calendarControllerProvider.notifier)
        .ensureWeekStart(0);
    await Future<void>.delayed(Duration.zero);
    hold.complete();
    await boot;
    for (var i = 0; i < 40; i++) {
      if (!container.read(calendarControllerProvider).isBusy) break;
      await Future<void>.delayed(Duration.zero);
    }
    expect(
      container.read(calendarControllerProvider).isSummaryQueryAligned,
      isTrue,
    );

    final hold2 = Completer<void>();
    repo.holdSummaryUntil = hold2;
    final apply = container
        .read(calendarControllerProvider.notifier)
        .setFilters(CalendarFilters(overdueOnly: true));
    await Future<void>.delayed(Duration.zero);
    expect(container.read(calendarControllerProvider).days, isEmpty);
    expect(
      container.read(calendarControllerProvider).isSummaryQueryAligned,
      isFalse,
    );
    hold2.complete();
    await apply;
  });
}
