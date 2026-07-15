import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/errors/calendar_exception.dart';
import '../../auth/domain/app_session.dart';
import '../data/calendar_repository.dart';
import '../domain/calendar_event.dart';
import '../domain/calendar_idempotency.dart';
import '../domain/calendar_manual_mutation.dart';
import '../domain/calendar_permissions.dart';
import 'calendar_labels.dart';
import 'widgets/calendar_conflict_confirm_dialog.dart';
import 'widgets/calendar_manual_event_dialog.dart';

/// Runs M7A manual create/edit/cancel/done mutations with soft-conflict loops.
///
/// Mirrors [CalendarSectionLoader]: a focused helper owned by
/// [CalendarController], not UI or repository logic.
class CalendarManualMutations {
  CalendarManualMutations({
    required this.readSession,
    required this.readRepo,
    required this.refresh,
  });

  final AppSession? Function() readSession;
  final CalendarRepository Function() readRepo;
  final Future<void> Function() refresh;

  AppSession? get _session => readSession();

  /// Creates a manual event, prompting for soft-conflict acknowledgement when needed.
  Future<bool> createManualEvent(
    BuildContext context,
    CalendarManualEventData data,
  ) {
    return _runManualMutation(
      context: context,
      initialData: data,
      mutate: (session, payload, key) {
        return readRepo().createManualEvent(
          session,
          data: payload,
          idempotencyKey: key,
        );
      },
    );
  }

  /// Edits [event] through the form dialog and optimistic concurrency.
  Future<bool> editManualEvent(
    BuildContext context,
    CalendarEvent event,
  ) async {
    final form = await showCalendarManualEventDialog(
      context: context,
      scheduledDate: event.scheduledDate,
      existing: event,
    );
    if (form == null || !context.mounted) return false;
    return _runManualMutation(
      context: context,
      initialData: form.data,
      mutate: (session, payload, key) {
        return readRepo().updateManualEvent(
          session,
          eventId: event.id,
          expectedVersion: event.scheduleVersion,
          data: payload,
          idempotencyKey: key,
        );
      },
      onStaleVersion: refresh,
    );
  }

  Future<bool> cancelManualEvent(
    CalendarEvent event, {
    required String reason,
  }) async {
    final session = _session;
    if (session == null || !canEditCalendarEvent(session)) return false;
    final idempotency = CalendarIdempotencySession();
    try {
      await readRepo().cancelManualEvent(
        session,
        eventId: event.id,
        expectedVersion: event.scheduleVersion,
        reason: reason,
        idempotencyKey: idempotency.key,
      );
      await refresh();
      return true;
    } on CalendarException catch (e) {
      if (e.code == CalendarException.staleVersion) {
        await refresh();
      }
      return false;
    }
  }

  Future<bool> markManualDone(CalendarEvent event) async {
    final session = _session;
    if (session == null || !canEditCalendarEvent(session)) return false;
    final idempotency = CalendarIdempotencySession();
    try {
      await readRepo().markManualEventDone(
        session,
        eventId: event.id,
        expectedVersion: event.scheduleVersion,
        idempotencyKey: idempotency.key,
      );
      await refresh();
      return true;
    } on CalendarException catch (e) {
      if (e.code == CalendarException.staleVersion) {
        await refresh();
      }
      return false;
    }
  }

  Future<bool> _runManualMutation({
    required BuildContext context,
    required CalendarManualEventData initialData,
    required Future<CalendarManualMutationResult> Function(
      AppSession session,
      CalendarManualEventData data,
      String idempotencyKey,
    )
    mutate,
    Future<void> Function()? onStaleVersion,
  }) async {
    final session = _session;
    if (session == null) return false;

    final idempotency = CalendarIdempotencySession();
    var data = initialData;
    var submitting = false;

    while (context.mounted) {
      if (submitting) return false;
      submitting = true;
      try {
        final result = await mutate(session, data, idempotency.key);
        if (result is CalendarManualMutationOk) {
          idempotency.clear();
          await refresh();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  AppLocalizations.of(context)!.calendarMutationSuccess,
                ),
              ),
            );
          }
          return true;
        }
        if (result is CalendarManualMutationConfirmationRequired) {
          // Soft confirmation is never persisted — reuse the same key.
          submitting = false;
          if (!context.mounted) return false;
          final acks = await showCalendarConflictConfirmDialog(
            context: context,
            conflicts: result.conflicts,
            initial: data.acknowledgements,
          );
          if (acks == null) return false;
          data = data.copyWith(acknowledgements: acks);
          continue;
        }
        return false;
      } on CalendarException catch (e) {
        submitting = false;
        if (!idempotency.shouldPreserveKeyOn(e)) {
          idempotency.regenerate();
        }
        if (e.code == CalendarException.staleVersion) {
          await onStaleVersion?.call();
          await refresh();
        }
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                calendarErrorMessage(AppLocalizations.of(context)!, e.code),
              ),
            ),
          );
        }
        return false;
      }
    }
    return false;
  }
}
