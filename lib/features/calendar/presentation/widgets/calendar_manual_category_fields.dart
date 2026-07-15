import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/calendar_enums.dart';
import '../calendar_labels.dart';

/// Category, titles, and notes for the manual create/edit form.
class CalendarManualCategoryFields extends StatelessWidget {
  const CalendarManualCategoryFields({
    required this.type,
    required this.isEdit,
    required this.titleAr,
    required this.titleEn,
    required this.notes,
    required this.onTypeChanged,
    super.key,
  });

  final CalendarEventType type;
  final bool isEdit;
  final TextEditingController titleAr;
  final TextEditingController titleEn;
  final TextEditingController notes;
  final ValueChanged<CalendarEventType?> onTypeChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<CalendarEventType>(
          key: const Key('calendar-manual-type'),
          initialValue: type,
          decoration: InputDecoration(labelText: l10n.calendarManualCategory),
          items: [
            for (final item in CalendarEventType.manualCreatable)
              DropdownMenuItem(
                value: item,
                enabled: !isEdit,
                child: Text(calendarEventTypeLabel(l10n, item)),
              ),
          ],
          onChanged: isEdit ? null : onTypeChanged,
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('calendar-manual-title-ar'),
          controller: titleAr,
          decoration: InputDecoration(labelText: l10n.calendarManualTitleAr),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('calendar-manual-title-en'),
          controller: titleEn,
          decoration: InputDecoration(labelText: l10n.calendarManualTitleEn),
        ),
        const SizedBox(height: 8),
        TextField(
          key: const Key('calendar-manual-notes'),
          controller: notes,
          maxLines: 3,
          decoration: InputDecoration(labelText: l10n.calendarManualNotes),
        ),
      ],
    );
  }
}
