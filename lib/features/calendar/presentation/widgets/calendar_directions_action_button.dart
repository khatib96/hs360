import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../data/calendar_repository.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../calendar_directions_flow.dart';
import '../calendar_directions_providers.dart';

/// "Directions" button: loads the server target, then shows Open-with sheet.
///
/// Never auto-launches a map app.
class CalendarDirectionsActionButton extends ConsumerWidget {
  const CalendarDirectionsActionButton({
    required this.eventId,
    required this.onBeforeLaunch,
    super.key,
  });

  final String eventId;

  /// Called before presenting the chooser (typically pops the actions dialog).
  final VoidCallback onBeforeLaunch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    return OutlinedButton.icon(
      key: Key('calendar-directions-action-$eventId'),
      onPressed: () => _openDirections(context, ref, l10n),
      icon: const Icon(Icons.directions_outlined),
      label: Text(l10n.calendarDirectionsAction),
    );
  }

  Future<void> _openDirections(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
  ) async {
    onBeforeLaunch();
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.calendarDirectionsFailed)));
      }
      return;
    }
    try {
      final target = await ref
          .read(calendarRepositoryProvider)
          .getEventDirections(session, eventId);
      if (!context.mounted) return;
      await presentCalendarDirectionsChooser(
        context: context,
        target: target,
        resolver: ref.read(calendarMapAppResolverProvider),
        launcher: ref.read(calendarDirectionsLauncherProvider),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.calendarDirectionsFailed)));
      }
    }
  }
}
