import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/calendar_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/calendar/data/calendar_working_date_exception_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_working_date_exception.dart';
import 'package:hs360/features/calendar/presentation/calendar_working_date_exceptions_controller.dart';

import '../data/calendar_working_date_exception_test_helpers.dart';
import '../fake_working_date_exception_repository.dart';

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
  Set<String> permissions = const {},
  bool isManager = false,
  String tenantId = 'tenant-1',
}) {
  return AppSession(
    userId: 'user-1',
    email: 'test@example.com',
    tenantId: tenantId,
    tenantUserId: 'tu-1',
    accountType: isManager ? 'manager' : 'user',
    displayName: 'Test User',
    preferredLocale: 'en',
    permissions: AppPermissions(isManager: isManager, permissions: permissions),
  );
}

ProviderContainer _container({
  required AppSession? session,
  required FakeWorkingDateExceptionRepository repo,
}) {
  return ProviderContainer(
    overrides: [
      authControllerProvider.overrideWith(() => _TestAuthController(session)),
      calendarWorkingDateExceptionRepositoryProvider.overrideWith(
        (ref) => repo,
      ),
    ],
  );
}

Future<void> _waitForLoad(ProviderContainer container) async {
  container.read(calendarWorkingDateExceptionsControllerProvider);
  await Future<void>.delayed(Duration.zero);
  for (var i = 0; i < 50; i++) {
    final state = container.read(
      calendarWorkingDateExceptionsControllerProvider,
    );
    if (!state.isLoading) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('controller stayed loading');
}

void main() {
  test('load denies without settings.calendar.view', () async {
    final container = _container(
      session: _session(),
      repo: FakeWorkingDateExceptionRepository(),
    );
    addTearDown(container.dispose);

    await _waitForLoad(container);
    final state = container.read(
      calendarWorkingDateExceptionsControllerProvider,
    );
    expect(state.permissionDenied, isTrue);
    expect(state.isLoading, isFalse);
  });

  test('load fetches active exceptions for a viewer', () async {
    final repo = FakeWorkingDateExceptionRepository(
      listResult: sampleWorkingDateExceptionList(
        items: [sampleWorkingDateException(id: 'wde-1')],
      ),
    );
    final container = _container(
      session: _session(permissions: {'settings.calendar.view'}),
      repo: repo,
    );
    addTearDown(container.dispose);

    await _waitForLoad(container);
    final state = container.read(
      calendarWorkingDateExceptionsControllerProvider,
    );
    expect(state.permissionDenied, isFalse);
    expect(state.canEdit, isFalse);
    expect(state.items, hasLength(1));
    expect(repo.lastSession?.permissions.can('settings.calendar.view'), isTrue);
    expect(state.statusFilter, CalendarWorkingDateExceptionStatusFilter.active);
    expect(repo.lastDateFrom, DateTime(state.selectedYear));
    expect(repo.lastDateTo, DateTime(state.selectedYear, 12, 31));
    expect(
      () => state.items.add(sampleWorkingDateException(id: 'mutate')),
      throwsUnsupportedError,
    );
  });

  test('editor can still add when the bounded list request fails', () async {
    final repo = FakeWorkingDateExceptionRepository(
      listError: const CalendarException(
        code: CalendarException.validationFailed,
      ),
    );
    final container = _container(
      session: _session(permissions: {'settings.calendar.edit'}),
      repo: repo,
    );
    addTearDown(container.dispose);

    await _waitForLoad(container);
    final state = container.read(
      calendarWorkingDateExceptionsControllerProvider,
    );
    expect(state.canEdit, isTrue);
    expect(state.errorCode, CalendarException.validationFailed);
    expect(repo.lastDateFrom, isNotNull);
    expect(repo.lastDateTo, isNotNull);
  });

  test('setStatusFilter reloads with the new filter', () async {
    final repo = FakeWorkingDateExceptionRepository();
    final container = _container(
      session: _session(permissions: {'settings.calendar.view'}),
      repo: repo,
    );
    addTearDown(container.dispose);
    await _waitForLoad(container);

    final notifier = container.read(
      calendarWorkingDateExceptionsControllerProvider.notifier,
    );
    await notifier.setStatusFilter(
      CalendarWorkingDateExceptionStatusFilter.cancelled,
    );

    final state = container.read(
      calendarWorkingDateExceptionsControllerProvider,
    );
    expect(
      state.statusFilter,
      CalendarWorkingDateExceptionStatusFilter.cancelled,
    );
    expect(repo.listCount, greaterThanOrEqualTo(2));
  });

  test('setYear sends an explicit stable calendar-year window', () async {
    final repo = FakeWorkingDateExceptionRepository();
    final container = _container(
      session: _session(permissions: {'settings.calendar.view'}),
      repo: repo,
    );
    addTearDown(container.dispose);
    await _waitForLoad(container);

    final notifier = container.read(
      calendarWorkingDateExceptionsControllerProvider.notifier,
    );
    await notifier.setYear(2028);

    final state = container.read(
      calendarWorkingDateExceptionsControllerProvider,
    );
    expect(state.selectedYear, 2028);
    expect(repo.lastDateFrom, DateTime(2028));
    expect(repo.lastDateTo, DateTime(2028, 12, 31));
  });

  test('loadMore reuses the echoed first-page window and limit', () async {
    var call = 0;
    final repo = FakeWorkingDateExceptionRepository(
      listHandler:
          (
            session, {
            required status,
            kind,
            dateFrom,
            dateTo,
            cursor,
            limit,
          }) async {
            call++;
            expect(dateFrom, isNotNull);
            expect(dateTo, isNotNull);
            if (call == 1) {
              expect(cursor, isNull);
              expect(limit, isNull);
              return sampleWorkingDateExceptionList(
                items: [sampleWorkingDateException(id: 'page-1')],
                hasMore: true,
                nextCursor: 'cursor-1',
                status: status,
                dateFrom: dateFrom,
                dateTo: dateTo,
                limit: 50,
              );
            }
            expect(cursor, 'cursor-1');
            expect(limit, 50);
            return sampleWorkingDateExceptionList(
              items: [sampleWorkingDateException(id: 'page-2')],
              status: status,
              dateFrom: dateFrom,
              dateTo: dateTo,
              limit: 50,
            );
          },
    );
    final container = _container(
      session: _session(permissions: {'settings.calendar.view'}),
      repo: repo,
    );
    addTearDown(container.dispose);
    await _waitForLoad(container);

    await container
        .read(calendarWorkingDateExceptionsControllerProvider.notifier)
        .loadMore();

    final state = container.read(
      calendarWorkingDateExceptionsControllerProvider,
    );
    expect(state.items.map((item) => item.id), ['page-1', 'page-2']);
    expect(call, 2);
  });

  test('createException requires settings.calendar.edit', () async {
    final repo = FakeWorkingDateExceptionRepository();
    final container = _container(
      session: _session(permissions: {'settings.calendar.view'}),
      repo: repo,
    );
    addTearDown(container.dispose);
    await _waitForLoad(container);

    final notifier = container.read(
      calendarWorkingDateExceptionsControllerProvider.notifier,
    );
    final ok = await notifier.createException(sampleWorkingDateExceptionData());
    expect(ok, isFalse);
    expect(repo.createCount, 0);
    final state = container.read(
      calendarWorkingDateExceptionsControllerProvider,
    );
    expect(state.mutationErrorCode, CalendarException.permissionDenied);
  });

  test('createException succeeds and reloads the list', () async {
    final repo = FakeWorkingDateExceptionRepository();
    final container = _container(
      session: _session(permissions: {'settings.calendar.edit'}),
      repo: repo,
    );
    addTearDown(container.dispose);
    await _waitForLoad(container);

    final notifier = container.read(
      calendarWorkingDateExceptionsControllerProvider.notifier,
    );
    final ok = await notifier.createException(sampleWorkingDateExceptionData());
    expect(ok, isTrue);
    expect(repo.createCount, 1);
    expect(repo.listCount, greaterThanOrEqualTo(2));
    final state = container.read(
      calendarWorkingDateExceptionsControllerProvider,
    );
    expect(state.mutationErrorCode, isNull);
    expect(state.mutationSuccessCode, 'created');
  });

  test('createException surfaces an overlap failure', () async {
    final repo = FakeWorkingDateExceptionRepository(
      createError: const CalendarException(
        code: CalendarException.workingDateExceptionOverlap,
      ),
    );
    final container = _container(
      session: _session(permissions: {'settings.calendar.edit'}),
      repo: repo,
    );
    addTearDown(container.dispose);
    await _waitForLoad(container);

    final notifier = container.read(
      calendarWorkingDateExceptionsControllerProvider.notifier,
    );
    final ok = await notifier.createException(sampleWorkingDateExceptionData());
    expect(ok, isFalse);
    final state = container.read(
      calendarWorkingDateExceptionsControllerProvider,
    );
    expect(
      state.mutationErrorCode,
      CalendarException.workingDateExceptionOverlap,
    );
  });

  test('updateException reloads the list on stale_version', () async {
    final repo = FakeWorkingDateExceptionRepository(
      updateError: const CalendarException(
        code: CalendarException.staleVersion,
      ),
    );
    final container = _container(
      session: _session(permissions: {'settings.calendar.edit'}),
      repo: repo,
    );
    addTearDown(container.dispose);
    await _waitForLoad(container);
    final baselineListCount = repo.listCount;

    final notifier = container.read(
      calendarWorkingDateExceptionsControllerProvider.notifier,
    );
    final ok = await notifier.updateException(
      sampleWorkingDateException(),
      sampleWorkingDateExceptionData(),
    );
    expect(ok, isFalse);
    expect(repo.listCount, greaterThan(baselineListCount));
    final state = container.read(
      calendarWorkingDateExceptionsControllerProvider,
    );
    expect(state.mutationErrorCode, CalendarException.staleVersion);
  });

  test('cancelException succeeds and reloads the list', () async {
    final repo = FakeWorkingDateExceptionRepository();
    final container = _container(
      session: _session(permissions: {'settings.calendar.edit'}),
      repo: repo,
    );
    addTearDown(container.dispose);
    await _waitForLoad(container);

    final notifier = container.read(
      calendarWorkingDateExceptionsControllerProvider.notifier,
    );
    final ok = await notifier.cancelException(
      sampleWorkingDateException(),
      reason: 'no longer needed',
    );
    expect(ok, isTrue);
    expect(repo.cancelCount, 1);
    expect(repo.lastReason, 'no longer needed');
    final state = container.read(
      calendarWorkingDateExceptionsControllerProvider,
    );
    expect(state.mutationSuccessCode, 'cancelled');
  });

  test('tenant switch resets and reloads the list', () async {
    final repo = FakeWorkingDateExceptionRepository();
    final auth = _TestAuthController(
      _session(permissions: {'settings.calendar.view'}, tenantId: 'tenant-1'),
    );
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(() => auth),
        calendarWorkingDateExceptionRepositoryProvider.overrideWith(
          (ref) => repo,
        ),
      ],
    );
    addTearDown(container.dispose);
    await _waitForLoad(container);
    final firstListCount = repo.listCount;

    auth.setSession(
      _session(permissions: {'settings.calendar.view'}, tenantId: 'tenant-2'),
    );
    await Future<void>.delayed(Duration.zero);
    await _waitForLoad(container);

    expect(repo.listCount, greaterThan(firstListCount));
    expect(repo.lastSession?.tenantId, 'tenant-2');
  });

  test('slow old-tenant load cannot overwrite the new tenant', () async {
    final oldLoad = Completer<WorkingDateExceptionListResult>();
    final repo = FakeWorkingDateExceptionRepository(
      listHandler:
          (session, {required status, kind, dateFrom, dateTo, cursor, limit}) {
            if (session.tenantId == 'tenant-1') return oldLoad.future;
            return Future.value(
              sampleWorkingDateExceptionList(
                items: [sampleWorkingDateException(id: 'tenant-2-item')],
                status: status,
                dateFrom: dateFrom,
                dateTo: dateTo,
              ),
            );
          },
    );
    final auth = _TestAuthController(
      _session(permissions: {'settings.calendar.view'}, tenantId: 'tenant-1'),
    );
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(() => auth),
        calendarWorkingDateExceptionRepositoryProvider.overrideWith(
          (ref) => repo,
        ),
      ],
    );
    addTearDown(container.dispose);

    container.read(calendarWorkingDateExceptionsControllerProvider);
    await Future<void>.delayed(Duration.zero);
    auth.setSession(
      _session(permissions: {'settings.calendar.view'}, tenantId: 'tenant-2'),
    );
    await Future<void>.delayed(Duration.zero);
    await _waitForLoad(container);
    expect(
      container
          .read(calendarWorkingDateExceptionsControllerProvider)
          .items
          .single
          .id,
      'tenant-2-item',
    );

    oldLoad.complete(
      sampleWorkingDateExceptionList(
        items: [sampleWorkingDateException(id: 'tenant-1-item')],
        dateFrom: DateTime(DateTime.now().year),
        dateTo: DateTime(DateTime.now().year, 12, 31),
      ),
    );
    await Future<void>.delayed(Duration.zero);
    expect(
      container
          .read(calendarWorkingDateExceptionsControllerProvider)
          .items
          .single
          .id,
      'tenant-2-item',
    );
  });
}
