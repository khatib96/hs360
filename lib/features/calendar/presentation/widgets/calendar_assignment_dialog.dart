import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/calendar_event.dart';
import '../../domain/calendar_event_participant.dart';
import '../calendar_assignment_lookup_controller.dart';
import '../calendar_labels.dart';

/// Outcome of the assignment dialog; a null [agentId] means "unassign".
class CalendarAssignmentChoice {
  const CalendarAssignmentChoice({required this.agentId});

  final String? agentId;
}

/// Lets the user pick an active employee (or unassign). Returns null when
/// dismissed; submitting is disabled while the selection equals the current
/// assignee.
Future<CalendarAssignmentChoice?> showCalendarAssignmentDialog({
  required BuildContext context,
  required CalendarEvent event,
}) {
  return showDialog<CalendarAssignmentChoice>(
    context: context,
    builder: (_) => _AssignmentDialogBody(event: event),
  );
}

/// Highest-priority capability warning for a candidate, or null when fully
/// reachable. Order is locked: calendar access, active tenant account, app
/// account.
String? calendarAssignCapabilityWarning(
  AppLocalizations l10n,
  CalendarParticipantCandidate candidate,
) {
  if (!candidate.hasCalendarAccess) {
    return l10n.calendarAssignWarningNoCalendarAccess;
  }
  if (!candidate.hasActiveTenantAccount) {
    return l10n.calendarAssignWarningNoActiveAccount;
  }
  if (!candidate.hasAppAccount) {
    return l10n.calendarAssignWarningNoAppAccount;
  }
  return null;
}

class _AssignmentDialogBody extends ConsumerStatefulWidget {
  const _AssignmentDialogBody({required this.event});

  final CalendarEvent event;

  @override
  ConsumerState<_AssignmentDialogBody> createState() =>
      _AssignmentDialogBodyState();
}

class _AssignmentDialogBodyState extends ConsumerState<_AssignmentDialogBody> {
  final _searchController = TextEditingController();
  String? _selectedAgentId;

  @override
  void initState() {
    super.initState();
    _selectedAgentId = widget.event.assignedAgentId;
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  bool get _isUnchanged => _selectedAgentId == widget.event.assignedAgentId;

  void _select(String? agentId) {
    setState(() => _selectedAgentId = agentId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final lookup = ref.watch(calendarAssignmentLookupControllerProvider);
    final event = widget.event;

    final currentName = calendarPersonName(
      languageCode: locale,
      nameAr: event.assignedAgentNameAr,
      nameEn: event.assignedAgentNameEn,
    );
    final currentInCandidates =
        event.assignedAgentId != null &&
        lookup.candidates.any((c) => c.employeeId == event.assignedAgentId);

    return AlertDialog(
      key: const Key('calendar-assign-dialog'),
      title: Text(l10n.calendarAssignDialogTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              event.assignedAgentId == null
                  ? l10n.calendarAssignCurrentlyUnassigned
                  : l10n.calendarAssignCurrentAssignee(
                      currentName ?? event.assignedAgentId!,
                    ),
              key: const Key('calendar-assign-current'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextField(
              key: const Key('calendar-assign-search'),
              controller: _searchController,
              decoration: InputDecoration(
                hintText: l10n.calendarAssignSearchHint,
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: ref
                  .read(calendarAssignmentLookupControllerProvider.notifier)
                  .search,
            ),
            const SizedBox(height: 8),
            Flexible(
              child: _buildList(l10n, locale, lookup, currentInCandidates),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.financeActionCancel),
        ),
        FilledButton(
          key: const Key('calendar-assign-submit'),
          onPressed: _isUnchanged
              ? null
              : () => Navigator.of(
                  context,
                ).pop(CalendarAssignmentChoice(agentId: _selectedAgentId)),
          child: Text(l10n.calendarAssignSubmit),
        ),
      ],
    );
  }

  Widget _buildList(
    AppLocalizations l10n,
    String locale,
    CalendarAssignmentLookupState lookup,
    bool currentInCandidates,
  ) {
    if (lookup.errorCode != null) {
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            calendarErrorMessage(l10n, lookup.errorCode!),
            key: const Key('calendar-assign-error'),
          ),
          TextButton(
            key: const Key('calendar-assign-retry'),
            onPressed: ref
                .read(calendarAssignmentLookupControllerProvider.notifier)
                .retry,
            child: Text(l10n.calendarAssignRetry),
          ),
        ],
      );
    }
    if (lookup.isLoading) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(
          child: CircularProgressIndicator(key: Key('calendar-assign-loading')),
        ),
      );
    }

    final event = widget.event;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxHeight: 320),
      child: ListView(
        key: const Key('calendar-assign-candidate-list'),
        shrinkWrap: true,
        children: [
          _optionTile(
            key: const Key('calendar-assign-unassign'),
            title: l10n.calendarAssignUnassignOption,
            agentId: null,
          ),
          // The current assignee may be inactive (excluded from candidates):
          // keep it visible/selectable so "unchanged" stays representable.
          if (event.assignedAgentId != null && !currentInCandidates)
            _optionTile(
              key: const Key('calendar-assign-current-option'),
              title:
                  calendarPersonName(
                    languageCode: locale,
                    nameAr: event.assignedAgentNameAr,
                    nameEn: event.assignedAgentNameEn,
                  ) ??
                  event.assignedAgentId!,
              subtitle: l10n.calendarAssignCurrentUnavailable,
              agentId: event.assignedAgentId,
            ),
          if (lookup.candidates.isEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                l10n.calendarAssignNoResults,
                key: const Key('calendar-assign-empty'),
              ),
            ),
          for (final candidate in lookup.candidates)
            _optionTile(
              key: Key('calendar-assign-candidate-${candidate.employeeId}'),
              title:
                  calendarPersonName(
                    languageCode: locale,
                    nameAr: candidate.nameAr,
                    nameEn: candidate.nameEn,
                  ) ??
                  candidate.employeeId,
              subtitle: calendarAssignCapabilityWarning(l10n, candidate),
              subtitleIsWarning: true,
              agentId: candidate.employeeId,
            ),
        ],
      ),
    );
  }

  Widget _optionTile({
    required Key key,
    required String title,
    String? subtitle,
    bool subtitleIsWarning = false,
    required String? agentId,
  }) {
    final selected = _selectedAgentId == agentId;
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      key: key,
      dense: true,
      selected: selected,
      title: Text(title),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle,
              style: subtitleIsWarning ? TextStyle(color: scheme.error) : null,
            ),
      trailing: selected ? const Icon(Icons.check) : null,
      onTap: () => _select(agentId),
    );
  }
}
