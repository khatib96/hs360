import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/calendar/domain/calendar_month_grid.dart';
import 'package:hs360/features/calendar/presentation/calendar_labels.dart';
import 'package:hs360/l10n/app_localizations.dart';

void main() {
  test('EN formats overflow count with plus', () {
    final l10n = lookupAppLocalizations(const Locale('en'));
    final text = calendarFormatCappedCount(
      l10n,
      CalendarCappedCount.fromRaw(150),
    );
    expect(text, contains('99'));
    expect(text, contains('+'));
  });

  test('AR formats overflow count with plus', () {
    final l10n = lookupAppLocalizations(const Locale('ar'));
    final text = calendarFormatCappedCount(
      l10n,
      CalendarCappedCount.fromRaw(150),
    );
    expect(text, contains('+'));
  });
}
