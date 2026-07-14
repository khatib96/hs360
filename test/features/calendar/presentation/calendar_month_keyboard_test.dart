import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/calendar/domain/calendar_date.dart';
import 'package:hs360/features/calendar/domain/calendar_range_summary.dart';
import 'package:hs360/features/calendar/presentation/widgets/calendar_month_grid.dart';
import 'package:hs360/features/calendar/presentation/widgets/calendar_month_toolbar.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../fake_calendar_repository.dart';

Map<DateTime, CalendarDaySummary> _daysByDate({DateTime? from, DateTime? to}) {
  final summary = sampleRangeSummary(
    dateFrom: from ?? DateTime(2026, 6, 28),
    dateTo: to ?? DateTime(2026, 8, 1),
  );
  return {for (final day in summary.days) calendarDateOnly(day.date): day};
}

Widget _wrap(Widget child, {Locale locale = const Locale('en')}) {
  return MaterialApp(
    locale: locale,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: Directionality(
        textDirection: locale.languageCode == 'ar'
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: child,
      ),
    ),
  );
}

void main() {
  testWidgets('EN/LTR: arrow right +1 day, down +7, Enter selects', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    DateTime selected = DateTime(2026, 7, 14);
    await tester.pumpWidget(
      _wrap(
        CalendarMonthGrid(
          focusedMonth: DateTime(2026, 7),
          firstDayOfWeekIndex: 0,
          dateFrom: DateTime(2026, 6, 28),
          dateTo: DateTime(2026, 8, 1),
          selectedDate: selected,
          tenantLocalToday: DateTime(2026, 7, 14),
          daysByDate: _daysByDate(),
          isAligned: true,
          isLoading: false,
          onSelectDate: (d) => selected = d,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('calendar-day-2026-7-14')));
    await tester.pump();
    expect(selected, DateTime(2026, 7, 14));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(selected, DateTime(2026, 7, 15));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(selected, DateTime(2026, 7, 22));
  });

  testWidgets('AR/RTL: arrow left moves +1 calendar day', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    DateTime selected = DateTime(2026, 7, 14);
    await tester.pumpWidget(
      _wrap(
        locale: const Locale('ar'),
        CalendarMonthGrid(
          focusedMonth: DateTime(2026, 7),
          firstDayOfWeekIndex: 6,
          dateFrom: DateTime(2026, 6, 28),
          dateTo: DateTime(2026, 8, 1),
          selectedDate: selected,
          tenantLocalToday: DateTime(2026, 7, 14),
          daysByDate: _daysByDate(),
          isAligned: true,
          isLoading: false,
          onSelectDate: (d) => selected = d,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('calendar-day-2026-7-14')));
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(selected, DateTime(2026, 7, 15));
  });

  testWidgets('month grid exposes semantics', (tester) async {
    await tester.pumpWidget(
      _wrap(
        CalendarMonthGrid(
          focusedMonth: DateTime(2026, 7),
          firstDayOfWeekIndex: 0,
          dateFrom: DateTime(2026, 6, 28),
          dateTo: DateTime(2026, 8, 1),
          selectedDate: DateTime(2026, 7, 14),
          tenantLocalToday: DateTime(2026, 7, 14),
          daysByDate: _daysByDate(),
          isAligned: true,
          isLoading: false,
          onSelectDate: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final label = tester
        .getSemantics(find.byKey(const Key('calendar-day-2026-7-14')))
        .label;
    expect(label, isNotNull);
    expect(label, contains('2026'));
  });

  testWidgets('Prev/Next chevron glyphs swap for RTL vs LTR', (tester) async {
    await tester.pumpWidget(
      _wrap(
        CalendarMonthToolbar(
          focusedMonth: DateTime(2026, 7),
          onPrevious: () {},
          onNext: () {},
          onToday: () {},
          onMonthSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    Icon prevLtr = tester.widget(
      find.descendant(
        of: find.byKey(const Key('calendar-prev-month')),
        matching: find.byType(Icon),
      ),
    );
    Icon nextLtr = tester.widget(
      find.descendant(
        of: find.byKey(const Key('calendar-next-month')),
        matching: find.byType(Icon),
      ),
    );
    expect(prevLtr.icon, LucideIcons.chevron_left);
    expect(nextLtr.icon, LucideIcons.chevron_right);

    await tester.pumpWidget(
      _wrap(
        locale: const Locale('ar'),
        CalendarMonthToolbar(
          focusedMonth: DateTime(2026, 7),
          onPrevious: () {},
          onNext: () {},
          onToday: () {},
          onMonthSelected: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final prevRtl = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('calendar-prev-month')),
        matching: find.byType(Icon),
      ),
    );
    final nextRtl = tester.widget<Icon>(
      find.descendant(
        of: find.byKey(const Key('calendar-next-month')),
        matching: find.byType(Icon),
      ),
    );
    expect(prevRtl.icon, LucideIcons.chevron_right);
    expect(nextRtl.icon, LucideIcons.chevron_left);
  });

  testWidgets('month and year selectors emit direct navigation targets', (
    tester,
  ) async {
    DateTime? target;
    await tester.pumpWidget(
      _wrap(
        CalendarMonthToolbar(
          focusedMonth: DateTime(2026, 7),
          onPrevious: () {},
          onNext: () {},
          onToday: () {},
          onMonthSelected: (value) => target = value,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('calendar-month-selector')));
    await tester.pumpAndSettle();
    expect(find.byType(CheckedPopupMenuItem<int>), findsNWidgets(12));
    expect(find.text('January'), findsOneWidget);
    expect(find.text('December'), findsOneWidget);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    final monthSelector = tester.widget<PopupMenuButton<int>>(
      find.byKey(const Key('calendar-month-selector')),
    );
    monthSelector.onSelected!(8);
    expect(target, DateTime(2026, 8));

    await tester.tap(find.byKey(const Key('calendar-year-selector')));
    await tester.pumpAndSettle();
    expect(find.text('2000'), findsOneWidget);
    expect(find.text('2100'), findsOneWidget);
    await tester.tapAt(const Offset(4, 4));
    await tester.pumpAndSettle();

    final yearSelector = tester.widget<PopupMenuButton<int>>(
      find.byKey(const Key('calendar-year-selector')),
    );
    yearSelector.onSelected!(2030);
    expect(target, DateTime(2030, 7));
  });
}
