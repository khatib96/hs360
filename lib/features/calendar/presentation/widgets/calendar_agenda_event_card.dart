import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
import '../../domain/calendar_enums.dart';
import '../../domain/calendar_event.dart';
import '../calendar_labels.dart';
import 'calendar_event_actions_dialog.dart';

export 'calendar_event_actions_dialog.dart' show showCalendarEventActionsDialog;

/// Compact, keyboard-accessible agenda event row that opens an action menu.
class CalendarAgendaEventCard extends ConsumerWidget {
  const CalendarAgendaEventCard({
    required this.event,
    this.onChanged,
    super.key,
  });

  final CalendarEvent event;
  final VoidCallback? onChanged;

  Future<void> _openActions(BuildContext context, WidgetRef ref) {
    return showCalendarEventActionsDialog(
      context: context,
      ref: ref,
      event: event,
      onChanged: onChanged,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final title = calendarEventTitle(event, locale);
    final customer = calendarPersonName(
      languageCode: locale,
      nameAr: event.customerNameAr,
      nameEn: event.customerNameEn,
    );
    final agent = calendarPersonName(
      languageCode: locale,
      nameAr: event.assignedAgentNameAr,
      nameEn: event.assignedAgentNameEn,
    );
    final showDirections =
        event.directionsAvailable && event.availableActions.canOpenDirections;
    final timeWindow = event.timeWindow;

    return Card(
      key: Key('calendar-event-${event.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: FocusableActionDetector(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _openActions(context, ref);
              return null;
            },
          ),
        },
        child: InkWell(
          key: Key('calendar-event-ink-${event.id}'),
          onTap: () => _openActions(context, ref),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: Theme.of(context).textTheme.titleSmall,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      LucideIcons.ellipsis,
                      size: 18,
                      color: AppColors.neutral600,
                    ),
                  ],
                ),
                if (timeWindow != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    l10n.calendarTimeWindowLabel(
                      timeWindow.startLocal,
                      timeWindow.endLocal,
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _badge(
                      calendarEventTypeLabel(l10n, event.type),
                      AppColors.info,
                    ),
                    _badge(
                      calendarEventStatusLabel(l10n, event.status),
                      AppColors.neutral600,
                    ),
                    if (event.isOverdue)
                      _badge(
                        calendarOverdueStateLabel(l10n, event.overdueState),
                        AppColors.error,
                      ),
                    if (event.scheduleState ==
                        CalendarScheduleState.dayOffOverridden)
                      _badge(l10n.calendarDayOffConflict, AppColors.warning),
                    if (showDirections)
                      _badge(
                        l10n.calendarDirectionsAvailable,
                        AppColors.info,
                        icon: LucideIcons.map_pinned,
                        badgeKey: Key('calendar-directions-${event.id}'),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                if (customer != null)
                  Text(
                    customer,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (event.serviceLocationName != null)
                  Text(
                    event.serviceLocationName!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                if (event.contractNumber != null)
                  Text(
                    event.contractNumber!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                Text(
                  agent == null
                      ? l10n.calendarLabelUnassigned
                      : '${l10n.calendarLabelAssigned}: $agent',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _badge(String label, Color color, {IconData? icon, Key? badgeKey}) {
    return Container(
      key: badgeKey,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 4),
          ],
          Text(label, style: TextStyle(color: color, fontSize: 11)),
        ],
      ),
    );
  }
}
