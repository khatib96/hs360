import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/errors/calendar_exception.dart';
import '../../auth/domain/app_session.dart';
import '../data/calendar_repository.dart';
import '../domain/calendar_event.dart';
import '../domain/calendar_idempotency.dart';
import '../domain/calendar_permissions.dart';
import '../domain/calendar_schedule_mutation.dart';
import 'calendar_labels.dart';
import 'calendar_state.dart';
import 'widgets/calendar_conflict_confirm_dialog.dart';

/// Runs M8 assign/reschedule mutations with soft-conflict loops and
/// generation/session guards: results that land after logout or a tenant
/// switch are discarded without touching state or UI.
///
/// Mirrors [CalendarManualMutations]: a focused helper owned by
/// [CalendarController], not UI or repository logic.
class CalendarScheduleMutations {
  CalendarScheduleMutations({
    required this.readSession,
    required this.readRepo,
    required this.readState,
    required this.refresh,
  });

  final AppSession? Function() readSession;
  final CalendarRepository Function() readRepo;
  final CalendarState Function() readState;
  final Future<void> Function() refresh;

  var _generation = 0;

  /// Discards in-flight mutation results (logout / identity change).
  void invalidate() => _generation++;

  bool _isCurrent(int generation, AppSession captured) {
    if (generation != _generation) return false;
    final current = readSession();
    return current != null &&
        current.userId == captured.userId &&
        current.tenantId == captured.tenantId &&
        current.tenantUserId == captured.tenantUserId;
  }

  bool _eventVisible(String eventId) {
    final state = readState();
    return state.agendaEvents.any((e) => e.id == eventId) ||
        state.overdueEvents.any((e) => e.id == eventId);
  }

  /// Assigns [assignedAgentId] (null = unassign) to [event].
  Future<bool> assignEvent(
    BuildContext context,
    CalendarEvent event, {
    required String? assignedAgentId,
  }) async {
    final session = readSession();
    if (session == null || !canEditCalendarEvent(session)) return false;

    final generation = _generation;
    final idempotency = CalendarIdempotencySession();
    final wasVisible = _eventVisible(event.id);
    try {
      final result = await readRepo().assignCalendarEvent(
        session,
        eventId: event.id,
        expectedVersion: event.scheduleVersion,
        data: CalendarAssignmentData(assignedAgentId: assignedAgentId),
        idempotencyKey: idempotency.key,
      );
      if (!_isCurrent(generation, session)) return false;
      if (result is! CalendarScheduleMutationOk) return false;
      await refresh();
      if (!_isCurrent(generation, session)) return false;
      if (context.mounted) {
        final l10n = AppLocalizations.of(context)!;
        // Assigned-only scopes can lose visibility of the event they just
        // reassigned; keep the selected date and say so explicitly.
        final hidden = result.changed && wasVisible && !_eventVisible(event.id);
        _showSnackBar(
          context,
          hidden
              ? l10n.calendarAssignedEventHidden
              : l10n.calendarAssignSuccess,
        );
      }
      return true;
    } on CalendarException catch (e) {
      if (!_isCurrent(generation, session)) return false;
      if (e.code == CalendarException.staleVersion) {
        await refresh();
      }
      if (context.mounted) {
        _showSnackBar(
          context,
          calendarErrorMessage(AppLocalizations.of(context)!, e.code),
        );
      }
      return false;
    }
  }

  /// Reschedules [event] to [targetDate], looping on soft conflicts.
  Future<bool> rescheduleEvent(
    BuildContext context,
    CalendarEvent event, {
    required DateTime targetDate,
    required String reason,
  }) async {
    final session = readSession();
    if (session == null || !canEditCalendarEvent(session)) return false;

    final generation = _generation;
    final idempotency = CalendarIdempotencySession();
    var data = CalendarRescheduleData(
      scheduledDate: targetDate,
      reason: reason,
    );

    while (context.mounted) {
      try {
        final result = await readRepo().rescheduleCalendarEvent(
          session,
          eventId: event.id,
          expectedVersion: event.scheduleVersion,
          data: data,
          idempotencyKey: idempotency.key,
        );
        if (!_isCurrent(generation, session)) return false;
        if (result is CalendarScheduleMutationOk) {
          await refresh();
          if (!_isCurrent(generation, session)) return false;
          if (context.mounted) {
            _showSnackBar(
              context,
              AppLocalizations.of(context)!.calendarRescheduleSuccess,
            );
          }
          return true;
        }
        if (result is CalendarScheduleMutationConfirmationRequired) {
          // Soft confirmation is never persisted — reuse the same key.
          if (!context.mounted) return false;
          final acks = await showCalendarConflictConfirmDialog(
            context: context,
            conflicts: result.conflicts,
            initial: data.acknowledgements,
          );
          if (!_isCurrent(generation, session)) return false;
          if (acks == null) return false;
          data = data.copyWith(acknowledgements: acks);
          continue;
        }
        return false;
      } on CalendarException catch (e) {
        if (!_isCurrent(generation, session)) return false;
        if (!idempotency.shouldPreserveKeyOn(e)) {
          idempotency.regenerate();
        }
        if (e.code == CalendarException.staleVersion) {
          await refresh();
        }
        if (context.mounted) {
          _showSnackBar(
            context,
            calendarErrorMessage(AppLocalizations.of(context)!, e.code),
          );
        }
        return false;
      }
    }
    return false;
  }

  void _showSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }
}
