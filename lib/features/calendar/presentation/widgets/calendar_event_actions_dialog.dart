import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/routing/app_routes.dart';
import '../../domain/calendar_enums.dart';
import '../../domain/calendar_event.dart';
import '../calendar_controller.dart';
import '../calendar_join_meeting.dart';
import '../calendar_labels.dart';
import 'calendar_assignment_dialog.dart';
import 'calendar_cancel_event_dialog.dart';
import 'calendar_directions_action_button.dart';
import 'calendar_reschedule_dialog.dart';

Future<void> showCalendarEventActionsDialog({
  required BuildContext context,
  required WidgetRef ref,
  required CalendarEvent event,
  VoidCallback? onChanged,
}) {
  final l10n = AppLocalizations.of(context)!;
  final locale = Localizations.localeOf(context).languageCode;
  final title = calendarEventTitle(event, locale);
  final customer = calendarPersonName(
    languageCode: locale,
    nameAr: event.customerNameAr,
    nameEn: event.customerNameEn,
  );
  final actions = event.availableActions;
  final canViewCustomer = actions.canViewCustomer && event.customerId != null;
  final canViewContract = actions.canViewContract && event.contractId != null;
  final isMeeting = event.type == CalendarEventType.internalMeeting;
  final markDoneLabel = isMeeting
      ? l10n.calendarCloseMeeting
      : l10n.calendarMarkManualDone;
  final showDirections = event.directionsAvailable && actions.canOpenDirections;

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      final scheme = Theme.of(dialogContext).colorScheme;
      final hasPrimaryActions =
          actions.canOpenMeetingLink ||
          showDirections ||
          actions.canAssign ||
          actions.canReschedule ||
          actions.canEditManual ||
          actions.canMarkManualDone ||
          actions.canCancelManual;

      return AlertDialog(
        key: Key('calendar-event-actions-${event.id}'),
        title: Row(
          children: [
            Expanded(child: Text(l10n.calendarEventActionsTitle)),
            IconButton(
              key: Key('calendar-event-actions-close-${event.id}'),
              tooltip: l10n.calendarEventActionsClose,
              onPressed: () => Navigator.of(dialogContext).pop(),
              icon: const Icon(Icons.close),
            ),
          ],
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  title,
                  style: Theme.of(dialogContext).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  calendarEventTypeLabel(l10n, event.type),
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
                Text(
                  calendarEventStatusLabel(l10n, event.status),
                  style: Theme.of(dialogContext).textTheme.bodySmall,
                ),
                if (customer != null) ...[
                  const SizedBox(height: 8),
                  Text('${l10n.calendarFilterCustomer}: $customer'),
                ],
                if (event.serviceLocationName != null)
                  Text(
                    '${l10n.calendarFilterServiceLocation}: '
                    '${event.serviceLocationName}',
                  ),
                if (event.contractNumber != null)
                  Text(
                    '${l10n.calendarFilterContract}: ${event.contractNumber}',
                  ),
                if (canViewCustomer || canViewContract) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      if (canViewCustomer)
                        TextButton(
                          key: Key('calendar-view-customer-${event.id}'),
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            context.push(
                              AppRoutes.customerDetailPath(event.customerId!),
                            );
                          },
                          child: Text(l10n.calendarViewCustomer),
                        ),
                      if (canViewContract)
                        TextButton(
                          key: Key('calendar-view-contract-${event.id}'),
                          onPressed: () {
                            Navigator.of(dialogContext).pop();
                            context.push(
                              AppRoutes.contractDetailPath(event.contractId!),
                            );
                          },
                          child: Text(l10n.calendarViewContract),
                        ),
                    ],
                  ),
                ],
                if (hasPrimaryActions) ...[
                  const SizedBox(height: 12),
                  if (actions.canOpenMeetingLink)
                    FilledButton.icon(
                      key: Key('calendar-join-meeting-${event.id}'),
                      onPressed: () async {
                        Navigator.of(dialogContext).pop();
                        final result = await joinCalendarMeeting(
                          event.meetingUrl,
                        );
                        if (!context.mounted) return;
                        final message = switch (result) {
                          JoinMeetingResult.opened => null,
                          JoinMeetingResult.invalidUrl =>
                            l10n.calendarJoinMeetingInvalid,
                          JoinMeetingResult.launchFailed =>
                            l10n.calendarJoinMeetingFailed,
                        };
                        if (message != null) {
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(message)));
                        }
                      },
                      icon: const Icon(Icons.videocam_outlined),
                      label: Text(l10n.calendarJoinMeeting),
                    ),
                  if (showDirections) ...[
                    const SizedBox(height: 8),
                    CalendarDirectionsActionButton(
                      eventId: event.id,
                      onBeforeLaunch: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                  if (actions.canAssign) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: Key('calendar-assign-${event.id}'),
                      onPressed: () async {
                        Navigator.of(dialogContext).pop();
                        final choice = await showCalendarAssignmentDialog(
                          context: context,
                          event: event,
                        );
                        if (choice == null || !context.mounted) return;
                        final ok = await ref
                            .read(calendarControllerProvider.notifier)
                            .assignCalendarEvent(
                              context,
                              event,
                              assignedAgentId: choice.agentId,
                            );
                        if (ok) onChanged?.call();
                      },
                      icon: const Icon(Icons.person_add_alt_outlined),
                      label: Text(l10n.calendarAssignAction),
                    ),
                  ],
                  if (actions.canReschedule) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: Key('calendar-reschedule-${event.id}'),
                      onPressed: () async {
                        Navigator.of(dialogContext).pop();
                        final input = await showCalendarRescheduleDialog(
                          context: context,
                          event: event,
                        );
                        if (input == null || !context.mounted) return;
                        final ok = await ref
                            .read(calendarControllerProvider.notifier)
                            .rescheduleCalendarEvent(
                              context,
                              event,
                              targetDate: input.targetDate,
                              reason: input.reason,
                            );
                        if (ok) onChanged?.call();
                      },
                      icon: const Icon(Icons.edit_calendar_outlined),
                      label: Text(l10n.calendarRescheduleAction),
                    ),
                  ],
                  if (actions.canEditManual) ...[
                    const SizedBox(height: 8),
                    OutlinedButton(
                      key: Key('calendar-edit-manual-${event.id}'),
                      onPressed: () async {
                        Navigator.of(dialogContext).pop();
                        final ok = await ref
                            .read(calendarControllerProvider.notifier)
                            .editManualEvent(context, event);
                        if (ok) onChanged?.call();
                      },
                      child: Text(l10n.calendarEditManual),
                    ),
                  ],
                  if (actions.canMarkManualDone) ...[
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      key: Key('calendar-mark-done-${event.id}'),
                      onPressed: () async {
                        final confirmed = await _confirmMarkDone(
                          dialogContext,
                          isMeeting: isMeeting,
                        );
                        if (!confirmed || !dialogContext.mounted) return;
                        Navigator.of(dialogContext).pop();
                        final ok = await ref
                            .read(calendarControllerProvider.notifier)
                            .markManualDone(event);
                        if (ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.calendarMutationMarkedDone),
                            ),
                          );
                          onChanged?.call();
                        }
                      },
                      child: Text(markDoneLabel),
                    ),
                  ],
                  if (actions.canCancelManual) ...[
                    const SizedBox(height: 8),
                    FilledButton(
                      key: Key('calendar-cancel-manual-${event.id}'),
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.error,
                        foregroundColor: scheme.onError,
                      ),
                      onPressed: () async {
                        Navigator.of(dialogContext).pop();
                        final reason = await showCalendarCancelEventDialog(
                          context: context,
                        );
                        if (reason == null || !context.mounted) return;
                        final ok = await ref
                            .read(calendarControllerProvider.notifier)
                            .cancelManualEvent(event, reason: reason);
                        if (ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(l10n.calendarMutationCancelled),
                            ),
                          );
                          onChanged?.call();
                        }
                      },
                      child: Text(l10n.calendarCancelManual),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<bool> _confirmMarkDone(
  BuildContext context, {
  required bool isMeeting,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showDialog<bool>(
    context: context,
    builder: (confirmContext) {
      return AlertDialog(
        key: const Key('calendar-mark-done-confirm-dialog'),
        title: Text(
          isMeeting
              ? l10n.calendarCloseMeetingConfirmTitle
              : l10n.calendarMarkDoneConfirmTitle,
        ),
        content: Text(
          isMeeting
              ? l10n.calendarCloseMeetingConfirmBody
              : l10n.calendarMarkDoneConfirmBody,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(confirmContext).pop(false),
            child: Text(l10n.financeActionCancel),
          ),
          FilledButton(
            key: const Key('calendar-mark-done-confirm-submit'),
            onPressed: () => Navigator.of(confirmContext).pop(true),
            child: Text(l10n.calendarMarkDoneConfirmAction),
          ),
        ],
      );
    },
  );
  return result == true;
}
