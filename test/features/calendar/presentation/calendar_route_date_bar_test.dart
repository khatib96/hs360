import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/calendar/presentation/widgets/calendar_route_date_bar.dart';
import 'package:hs360/l10n/app_localizations.dart';

void main() {
  Future<void> pumpArRtl(
    WidgetTester tester, {
    required Size size,
    required ValueChanged<DateTime> onSelectDate,
    DateTime? selectedDate,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('ar'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: CalendarRouteDateBar(
              selectedDate: selectedDate ?? DateTime(2026, 7, 14),
              onSelectDate: onSelectDate,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  for (final size in const [Size(360, 800), Size(412, 900)]) {
    testWidgets(
      'AR RTL ${size.width.toInt()} shows prev/next day icons and navigates',
      (tester) async {
        DateTime? selected;
        await pumpArRtl(
          tester,
          size: size,
          onSelectDate: (d) => selected = d,
        );

        expect(find.byKey(const Key('calendar-route-prev-day')), findsOneWidget);
        expect(find.byKey(const Key('calendar-route-next-day')), findsOneWidget);
        expect(
          find.byKey(const Key('calendar-route-prev-day-icon')),
          findsOneWidget,
        );
        expect(
          find.byKey(const Key('calendar-route-next-day-icon')),
          findsOneWidget,
        );

        final prevIcon = tester.widget<Icon>(
          find.byKey(const Key('calendar-route-prev-day-icon')),
        );
        final nextIcon = tester.widget<Icon>(
          find.byKey(const Key('calendar-route-next-day-icon')),
        );
        expect(prevIcon.icon, Icons.chevron_left);
        expect(nextIcon.icon, Icons.chevron_right);

        await tester.tap(find.byKey(const Key('calendar-route-prev-day')));
        await tester.pumpAndSettle();
        expect(selected, DateTime(2026, 7, 13));

        await tester.tap(find.byKey(const Key('calendar-route-next-day')));
        await tester.pumpAndSettle();
        expect(selected, DateTime(2026, 7, 15));
      },
    );
  }
}
