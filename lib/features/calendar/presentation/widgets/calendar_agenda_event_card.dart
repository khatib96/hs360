import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/calendar_enums.dart';
import '../../domain/calendar_event.dart';
import '../calendar_labels.dart';

/// Compact, keyboard-accessible agenda event row that opens an action menu.
class CalendarAgendaEventCard extends StatelessWidget {
  const CalendarAgendaEventCard({required this.event, super.key});

  final CalendarEvent event;

  Future<void> _openActions(BuildContext context) {
    return showCalendarEventActionsDialog(context: context, event: event);
  }

  @override
  Widget build(BuildContext context) {
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

    return Card(
      key: Key('calendar-event-${event.id}'),
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: FocusableActionDetector(
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _openActions(context);
              return null;
            },
          ),
        },
        child: InkWell(
          key: Key('calendar-event-ink-${event.id}'),
          onTap: () => _openActions(context),
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

Future<void> showCalendarEventActionsDialog({
  required BuildContext context,
  required CalendarEvent event,
}) {
  final l10n = AppLocalizations.of(context)!;
  final locale = Localizations.localeOf(context).languageCode;
  final title = calendarEventTitle(event, locale);
  final customer = calendarPersonName(
    languageCode: locale,
    nameAr: event.customerNameAr,
    nameEn: event.customerNameEn,
  );
  final canViewCustomer =
      event.availableActions.canViewCustomer && event.customerId != null;
  final canViewContract =
      event.availableActions.canViewContract && event.contractId != null;

  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        key: Key('calendar-event-actions-${event.id}'),
        title: Text(l10n.calendarEventActionsTitle),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(dialogContext).textTheme.titleSmall),
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
                Text('${l10n.calendarFilterContract}: ${event.contractNumber}'),
              // M10 may add Directions here using a safe URI/coords contract.
            ],
          ),
        ),
        actions: [
          if (canViewCustomer)
            TextButton(
              key: Key('calendar-view-customer-${event.id}'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.push(AppRoutes.customerDetailPath(event.customerId!));
              },
              child: Text(l10n.calendarViewCustomer),
            ),
          if (canViewContract)
            TextButton(
              key: Key('calendar-view-contract-${event.id}'),
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.push(AppRoutes.contractDetailPath(event.contractId!));
              },
              child: Text(l10n.calendarViewContract),
            ),
          TextButton(
            key: Key('calendar-event-actions-close-${event.id}'),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.calendarEventActionsClose),
          ),
        ],
      );
    },
  );
}
