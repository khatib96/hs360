import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/calendar_route_location_state.dart';
import '../../domain/calendar_route_point.dart';
import '../calendar_directions_flow.dart';
import '../calendar_directions_launcher.dart';
import '../calendar_directions_providers.dart';
import '../calendar_labels.dart';
import '../calendar_route_controller.dart';
import 'calendar_event_actions_dialog.dart';

/// Route View day event list; stays in sync with map marker selection.
///
/// Tapping a row selects it (syncs the map); the overflow button opens the
/// full event actions dialog (same dialog as the main Calendar screen).
class CalendarRoutePointList extends StatelessWidget {
  const CalendarRoutePointList({
    required this.points,
    required this.selectedEventId,
    required this.onSelectEvent,
    required this.onEventChanged,
    super.key,
  });

  final List<CalendarRoutePoint> points;
  final String? selectedEventId;
  final ValueChanged<String> onSelectEvent;
  final VoidCallback onEventChanged;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      final l10n = AppLocalizations.of(context)!;
      return Center(
        key: const Key('calendar-route-list-empty'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.calendarRouteEmptyDay, textAlign: TextAlign.center),
        ),
      );
    }

    return ListView.builder(
      key: const Key('calendar-route-point-list'),
      padding: const EdgeInsets.all(8),
      itemCount: points.length,
      itemBuilder: (context, index) {
        final point = points[index];
        return _CalendarRoutePointTile(
          key: ValueKey(point.event.id),
          point: point,
          selected: point.event.id == selectedEventId,
          onTap: () => onSelectEvent(point.event.id),
          onEventChanged: onEventChanged,
        );
      },
    );
  }
}

class _CalendarRoutePointTile extends ConsumerWidget {
  const _CalendarRoutePointTile({
    required this.point,
    required this.selected,
    required this.onTap,
    required this.onEventChanged,
    super.key,
  });

  final CalendarRoutePoint point;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onEventChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final event = point.event;
    final title = calendarEventTitle(event, locale);
    final locationUnavailable =
        point.locationState == CalendarRouteLocationState.missing ||
        point.locationState == CalendarRouteLocationState.invalid;
    final showDirections =
        event.directionsAvailable && event.availableActions.canOpenDirections;
    final scheme = Theme.of(context).colorScheme;

    return Card(
      key: Key('calendar-route-point-${event.id}'),
      color: selected ? scheme.primaryContainer : null,
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('calendar-route-point-ink-${event.id}'),
        onTap: onTap,
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
                  IconButton(
                    key: Key('calendar-route-point-actions-${event.id}'),
                    tooltip: l10n.calendarEventActionsTitle,
                    onPressed: () => showCalendarEventActionsDialog(
                      context: context,
                      ref: ref,
                      event: event,
                      onChanged: onEventChanged,
                    ),
                    icon: const Icon(Icons.more_vert),
                  ),
                ],
              ),
              if (event.serviceLocationName != null)
                Text(
                  event.serviceLocationName!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              if (locationUnavailable)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    l10n.calendarRouteLocationUnavailable,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: scheme.error),
                  ),
                ),
              if (showDirections)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OutlinedButton.icon(
                      key: Key('calendar-route-directions-${event.id}'),
                      onPressed: () => _openDirections(context, ref, l10n),
                      icon: const Icon(Icons.directions_outlined),
                      label: Text(l10n.calendarDirectionsAction),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openDirections(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    // Use the root navigator context so an await + route-list rebuild cannot
    // unmount the Directions button's element before the Open-with sheet opens.
    final host = Navigator.of(context, rootNavigator: true).context;
    final target = await ref
        .read(calendarRouteControllerProvider.notifier)
        .loadDirectionsTarget(point.event.id);
    if (!host.mounted) return;
    if (target == null) {
      ScaffoldMessenger.of(
        host,
      ).showSnackBar(SnackBar(content: Text(l10n.calendarDirectionsFailed)));
      return;
    }
    final result = await presentCalendarDirectionsChooser(
      context: host,
      target: target,
      resolver: ref.read(calendarMapAppResolverProvider),
      launcher: ref.read(calendarDirectionsLauncherProvider),
    );
    if (result == CalendarDirectionsResult.launchFailed && host.mounted) {
      // SnackBar already shown by the flow helper on launch failure.
    }
  }
}
