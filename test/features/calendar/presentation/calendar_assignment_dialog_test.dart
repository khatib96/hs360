import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/calendar/data/calendar_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_event.dart';
import 'package:hs360/features/calendar/presentation/calendar_assignment_lookup_controller.dart';
import 'package:hs360/features/calendar/presentation/widgets/calendar_assignment_dialog.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../fake_calendar_repository.dart';

class _TestAuthController extends AuthController {
  _TestAuthController(this.session);
  final AppSession? session;

  @override
  FutureOr<AppSession?> build() => session;
}

AppSession _session() {
  return AppSession(
    userId: 'user-1',
    email: 'test@example.com',
    tenantId: 'tenant-1',
    tenantUserId: 'tu-1',
    accountType: 'user',
    displayName: 'Test User',
    preferredLocale: 'en',
    permissions: AppPermissions(
      isManager: false,
      permissions: const {'calendar.view', 'calendar.edit'},
    ),
  );
}

CalendarAssignmentChoice? _lastChoice;
var _dialogClosed = false;

Future<void> _pumpAndOpen(
  WidgetTester tester, {
  required FakeCalendarRepository repo,
  required CalendarEvent event,
}) async {
  _lastChoice = null;
  _dialogClosed = false;
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith(
          () => _TestAuthController(_session()),
        ),
        calendarRepositoryProvider.overrideWith((ref) => repo),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () async {
                _lastChoice = await showCalendarAssignmentDialog(
                  context: context,
                  event: event,
                );
                _dialogClosed = true;
              },
              child: const Text('open'),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('lists candidates with an unassign option', (tester) async {
    final repo = FakeCalendarRepository(
      participantCandidates: [
        sampleParticipantCandidate(employeeId: 'emp-1', nameEn: 'Ahmad'),
        sampleParticipantCandidate(employeeId: 'emp-2', nameEn: 'Sara'),
      ],
    );
    await _pumpAndOpen(tester, repo: repo, event: sampleCalendarEvent());

    expect(find.byKey(const Key('calendar-assign-dialog')), findsOneWidget);
    expect(find.byKey(const Key('calendar-assign-unassign')), findsOneWidget);
    expect(
      find.byKey(const Key('calendar-assign-candidate-emp-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('calendar-assign-candidate-emp-2')),
      findsOneWidget,
    );
  });

  testWidgets('submit stays disabled until the selection changes', (
    tester,
  ) async {
    final repo = FakeCalendarRepository(
      participantCandidates: [
        sampleParticipantCandidate(employeeId: 'emp-1', nameEn: 'Ahmad'),
      ],
    );
    await _pumpAndOpen(tester, repo: repo, event: sampleCalendarEvent());

    final submit = find.byKey(const Key('calendar-assign-submit'));
    expect(tester.widget<FilledButton>(submit).onPressed, isNull);

    await tester.tap(find.byKey(const Key('calendar-assign-candidate-emp-1')));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);

    await tester.tap(submit);
    await tester.pumpAndSettle();
    expect(_dialogClosed, isTrue);
    expect(_lastChoice?.agentId, 'emp-1');
  });

  testWidgets(
    'currently assigned event supports unassign and shows current assignee',
    (tester) async {
      final repo = FakeCalendarRepository(
        participantCandidates: [
          sampleParticipantCandidate(employeeId: 'emp-1', nameEn: 'Ahmad'),
        ],
      );
      final event = sampleCalendarEvent(
        assignedAgentId: 'emp-9',
        assignedAgentNameAr: 'وكيل غير نشط',
        assignedAgentNameEn: 'Inactive Agent',
      );
      await _pumpAndOpen(tester, repo: repo, event: event);

      // Current assignee is not among active candidates: shown as current /
      // unavailable but still selectable.
      expect(
        find.byKey(const Key('calendar-assign-current-option')),
        findsOneWidget,
      );
      expect(
        find.text('Current assignee — unavailable (inactive)'),
        findsOneWidget,
      );

      final submit = find.byKey(const Key('calendar-assign-submit'));
      expect(tester.widget<FilledButton>(submit).onPressed, isNull);

      await tester.tap(find.byKey(const Key('calendar-assign-unassign')));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(submit).onPressed, isNotNull);

      await tester.tap(submit);
      await tester.pumpAndSettle();
      expect(_dialogClosed, isTrue);
      expect(_lastChoice, isNotNull);
      expect(_lastChoice!.agentId, isNull);
    },
  );

  testWidgets('shows capability warnings with locked priority', (tester) async {
    final repo = FakeCalendarRepository(
      participantCandidates: [
        sampleParticipantCandidate(
          employeeId: 'emp-no-cal',
          nameEn: 'No Calendar',
          hasCalendarAccess: false,
        ),
        sampleParticipantCandidate(
          employeeId: 'emp-no-tenant',
          nameEn: 'No Tenant',
          hasActiveTenantAccount: false,
          hasCalendarAccess: false,
        ),
        sampleParticipantCandidate(employeeId: 'emp-ok', nameEn: 'Reachable'),
      ],
    );
    await _pumpAndOpen(tester, repo: repo, event: sampleCalendarEvent());

    // Both unreachable candidates collapse to the highest-priority warning.
    expect(
      find.text(
        'No calendar access — assigned events will not be visible to them.',
      ),
      findsNWidgets(2),
    );
  });

  test('capability warning helper follows the locked priority order', () {
    final l10nEn = lookupAppLocalizations(const Locale('en'));

    expect(
      calendarAssignCapabilityWarning(
        l10nEn,
        sampleParticipantCandidate(
          hasAppAccount: false,
          hasActiveTenantAccount: false,
          hasCalendarAccess: false,
        ),
      ),
      l10nEn.calendarAssignWarningNoCalendarAccess,
    );
    expect(
      calendarAssignCapabilityWarning(
        l10nEn,
        sampleParticipantCandidate(
          hasAppAccount: false,
          hasActiveTenantAccount: false,
          hasCalendarAccess: true,
        ),
      ),
      l10nEn.calendarAssignWarningNoActiveAccount,
    );
    expect(
      calendarAssignCapabilityWarning(
        l10nEn,
        sampleParticipantCandidate(
          hasAppAccount: false,
          hasActiveTenantAccount: true,
          hasCalendarAccess: true,
        ),
      ),
      l10nEn.calendarAssignWarningNoAppAccount,
    );
    expect(
      calendarAssignCapabilityWarning(l10nEn, sampleParticipantCandidate()),
      isNull,
    );
  });

  testWidgets('search debounces and forwards the query', (tester) async {
    final repo = FakeCalendarRepository(
      participantCandidates: [
        sampleParticipantCandidate(employeeId: 'emp-1', nameEn: 'Ahmad'),
        sampleParticipantCandidate(employeeId: 'emp-2', nameEn: 'Sara'),
      ],
    );
    await _pumpAndOpen(tester, repo: repo, event: sampleCalendarEvent());
    final callsAfterOpen = repo.candidatesCount;

    await tester.enterText(
      find.byKey(const Key('calendar-assign-search')),
      'sa',
    );
    await tester.pump(const Duration(milliseconds: 100));
    // Still debouncing: no extra lookup yet.
    expect(repo.candidatesCount, callsAfterOpen);

    await tester.pump(const Duration(milliseconds: 250));
    await tester.pumpAndSettle();
    expect(repo.candidatesCount, callsAfterOpen + 1);
    expect(repo.lastCandidatesSearch, 'sa');
    expect(
      find.byKey(const Key('calendar-assign-candidate-emp-2')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('calendar-assign-candidate-emp-1')),
      findsNothing,
    );
  });

  testWidgets('lookup errors surface with retry', (tester) async {
    final repo = FakeCalendarRepository(
      participantCandidates: [sampleParticipantCandidate()],
    )..candidatesError = Exception('boom');
    await _pumpAndOpen(tester, repo: repo, event: sampleCalendarEvent());

    expect(find.byKey(const Key('calendar-assign-error')), findsOneWidget);

    repo.candidatesError = null;
    await tester.tap(find.byKey(const Key('calendar-assign-retry')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('calendar-assign-candidate-emp-1')),
      findsOneWidget,
    );
  });

  test('lookup state candidate list is frozen (mutations throw)', () async {
    final repo = FakeCalendarRepository(
      participantCandidates: [
        sampleParticipantCandidate(employeeId: 'emp-1', nameEn: 'Ahmad'),
      ],
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
    final sub = container.listen(
      calendarAssignmentLookupControllerProvider,
      (previous, next) {},
    );
    addTearDown(sub.close);

    // Let the initial microtask-scheduled load settle.
    for (
      var i = 0;
      i < 10 &&
          container.read(calendarAssignmentLookupControllerProvider).isLoading;
      i++
    ) {
      await Future<void>.delayed(Duration.zero);
    }

    final state = container.read(calendarAssignmentLookupControllerProvider);
    expect(state.candidates, hasLength(1));
    expect(() => state.candidates.clear(), throwsUnsupportedError);
    expect(() => state.candidates.removeAt(0), throwsUnsupportedError);
    expect(
      () => state.candidates.add(state.candidates.first),
      throwsUnsupportedError,
    );
  });
}
