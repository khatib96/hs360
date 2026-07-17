import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/calendar/data/calendar_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_available_actions.dart';
import 'package:hs360/features/calendar/domain/calendar_enums.dart';
import 'package:hs360/features/calendar/domain/calendar_event.dart';
import 'package:hs360/features/calendar/presentation/widgets/calendar_event_actions_dialog.dart';
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

CalendarAvailableActions _actions({
  bool canAssign = false,
  bool canReschedule = false,
}) {
  return CalendarAvailableActions(
    canViewCustomer: false,
    canViewContract: false,
    canAssign: canAssign,
    canReschedule: canReschedule,
    canCreateManual: false,
    canOpenDirections: false,
    canEditManual: false,
    canCancelManual: false,
    canMarkManualDone: false,
    canOpenMeetingLink: false,
  );
}

Future<void> _pumpAndOpen(
  WidgetTester tester, {
  required FakeCalendarRepository repo,
  required CalendarEvent event,
}) async {
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
          body: Consumer(
            builder: (context, ref, _) => TextButton(
              onPressed: () => showCalendarEventActionsDialog(
                context: context,
                ref: ref,
                event: event,
              ),
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
  testWidgets('shows Assign and Reschedule when the RPC grants them', (
    tester,
  ) async {
    final event = sampleCalendarEvent(
      availableActions: _actions(canAssign: true, canReschedule: true),
    );
    await _pumpAndOpen(tester, repo: FakeCalendarRepository(), event: event);

    expect(find.byKey(Key('calendar-assign-${event.id}')), findsOneWidget);
    expect(find.byKey(Key('calendar-reschedule-${event.id}')), findsOneWidget);
  });

  testWidgets('hides Assign and Reschedule when not permitted', (tester) async {
    final event = sampleCalendarEvent(availableActions: _actions());
    await _pumpAndOpen(tester, repo: FakeCalendarRepository(), event: event);

    expect(find.byKey(Key('calendar-assign-${event.id}')), findsNothing);
    expect(find.byKey(Key('calendar-reschedule-${event.id}')), findsNothing);
  });

  testWidgets('Assign opens the assignment dialog', (tester) async {
    final event = sampleCalendarEvent(
      availableActions: _actions(canAssign: true),
    );
    final repo = FakeCalendarRepository(
      participantCandidates: [
        sampleParticipantCandidate(employeeId: 'emp-1', nameEn: 'Ahmad'),
      ],
    );
    await _pumpAndOpen(tester, repo: repo, event: event);

    await tester.tap(find.byKey(Key('calendar-assign-${event.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-assign-dialog')), findsOneWidget);
  });

  testWidgets('Reschedule opens the reschedule dialog', (tester) async {
    final event = sampleCalendarEvent(
      availableActions: _actions(canReschedule: true),
    );
    await _pumpAndOpen(tester, repo: FakeCalendarRepository(), event: event);

    await tester.tap(find.byKey(Key('calendar-reschedule-${event.id}')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-reschedule-dialog')), findsOneWidget);
  });

  testWidgets(
    'internal meeting: Assign hidden, Reschedule follows the server flag',
    (tester) async {
      // Server flags for an organizer-owned pending meeting: never assignable,
      // reschedulable by the organizer only.
      final event = sampleCalendarEvent(
        type: CalendarEventType.internalMeeting,
        sourceKind: CalendarEventSourceKind.manual,
        availableActions: _actions(canAssign: false, canReschedule: true),
      );
      await _pumpAndOpen(tester, repo: FakeCalendarRepository(), event: event);

      expect(find.byKey(Key('calendar-assign-${event.id}')), findsNothing);
      expect(
        find.byKey(Key('calendar-reschedule-${event.id}')),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'cancelled/completed/legacy rescheduled: Assign and Reschedule hidden',
    (tester) async {
      // The server never grants assign/reschedule on terminal or legacy
      // 'rescheduled' statuses; the dialog must follow the flags exactly.
      const statuses = [
        CalendarEventStatus.cancelled,
        CalendarEventStatus.done,
        CalendarEventStatus.rescheduled,
      ];
      for (final status in statuses) {
        final event = sampleCalendarEvent(
          id: 'event-${status.name}',
          status: status,
          availableActions: _actions(),
        );
        await _pumpAndOpen(
          tester,
          repo: FakeCalendarRepository(),
          event: event,
        );

        expect(
          find.byKey(Key('calendar-assign-${event.id}')),
          findsNothing,
          reason: 'assign visible for ${status.name}',
        );
        expect(
          find.byKey(Key('calendar-reschedule-${event.id}')),
          findsNothing,
          reason: 'reschedule visible for ${status.name}',
        );

        // Close the dialog before the next iteration.
        await tester.tapAt(const Offset(5, 5));
        await tester.pumpAndSettle();
      }
    },
  );
}
