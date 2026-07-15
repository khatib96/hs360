import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/calendar_event_participant.dart';
import '../calendar_labels.dart';

/// Participant search, selected chips, and candidate checklist.
class CalendarManualParticipantSection extends StatelessWidget {
  const CalendarManualParticipantSection({
    required this.searchController,
    required this.selectedParticipants,
    required this.candidates,
    required this.locale,
    required this.onSearch,
    required this.onToggleParticipant,
    super.key,
  });

  final TextEditingController searchController;
  final Map<String, CalendarEventParticipant> selectedParticipants;
  final List<CalendarEventParticipant> candidates;
  final String locale;
  final ValueChanged<String> onSearch;
  final void Function(CalendarEventParticipant participant, bool selected)
  onToggleParticipant;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        Text(l10n.calendarParticipants),
        TextField(
          key: const Key('calendar-manual-participant-search'),
          controller: searchController,
          decoration: InputDecoration(
            hintText: l10n.calendarParticipantsSearch,
            suffixIcon: IconButton(
              icon: const Icon(Icons.search),
              onPressed: () => onSearch(searchController.text),
            ),
          ),
          onSubmitted: onSearch,
        ),
        Wrap(
          spacing: 6,
          children: [
            for (final p in selectedParticipants.values)
              Chip(
                label: Text(
                  calendarPersonName(
                        languageCode: locale,
                        nameAr: p.nameAr,
                        nameEn: p.nameEn,
                      ) ??
                      p.employeeId,
                ),
                onDeleted: () => onToggleParticipant(p, false),
              ),
          ],
        ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 140),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final p in candidates)
                CheckboxListTile(
                  dense: true,
                  value: selectedParticipants.containsKey(p.employeeId),
                  title: Text(
                    calendarPersonName(
                          languageCode: locale,
                          nameAr: p.nameAr,
                          nameEn: p.nameEn,
                        ) ??
                        p.employeeId,
                  ),
                  onChanged: (selected) =>
                      onToggleParticipant(p, selected == true),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
