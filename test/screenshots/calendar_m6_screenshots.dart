// Supporting (NOT live-app) screenshot harness for the Phase 7 M6 calendar
// redesign. Renders CalendarScreen through AppShell with bundled Noto fonts
// and FakeCalendarRepository sample data, then writes PNGs to build/screenshots/.
//
// These are supporting renders only. Visual acceptance still requires live
// macOS app screenshots in Arabic from an authenticated session.
//
// Run: flutter test test/screenshots/calendar_m6_screenshots.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/theme/app_theme.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/calendar/data/calendar_repository.dart';
import 'package:hs360/features/calendar/domain/calendar_available_actions.dart';
import 'package:hs360/features/calendar/domain/calendar_enums.dart';
import 'package:hs360/features/calendar/presentation/calendar_controller.dart';
import 'package:hs360/features/calendar/presentation/calendar_screen.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../features/calendar/fake_calendar_repository.dart';

final _rootKey = GlobalKey();
const _desktop = Size(1280, 900);
const _narrow = Size(1000, 900);

void main() {
  setUpAll(_loadFonts);

  late CalendarClock previous;

  setUp(() {
    previous = calendarClock;
    calendarClock = () => DateTime(2026, 7, 14);
  });

  tearDown(() => calendarClock = previous);

  testWidgets('calendar desktop (AR RTL)', (tester) async {
    await _pump(
      tester,
      size: _desktop,
      locale: const Locale('ar'),
      repo: _richRepo(),
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, 'calendar_desktop_ar_rtl');
  });

  testWidgets('calendar desktop (EN LTR)', (tester) async {
    await _pump(
      tester,
      size: _desktop,
      locale: const Locale('en'),
      repo: _richRepo(),
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, 'calendar_desktop_en_ltr');
  });

  testWidgets('calendar narrow (AR)', (tester) async {
    await _pump(
      tester,
      size: _narrow,
      locale: const Locale('ar'),
      repo: _richRepo(),
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, 'calendar_narrow_ar');
  });

  testWidgets('calendar filter popover (AR)', (tester) async {
    await _pump(
      tester,
      size: _desktop,
      locale: const Locale('ar'),
      repo: _richRepo(),
    );
    await tester.tap(find.byKey(const Key('calendar-filter-funnel')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('calendar-filter-popover')), findsOneWidget);
    expect(tester.takeException(), isNull);
    await _capture(tester, 'calendar_filter_popover_ar');
  });

  testWidgets('calendar event actions (AR)', (tester) async {
    await _pump(
      tester,
      size: _desktop,
      locale: const Locale('ar'),
      repo: _richRepo(),
    );
    await _revealAgenda(tester);
    await tester.tap(find.byKey(const Key('calendar-event-ink-evt-1')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const Key('calendar-event-actions-evt-1')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
    await _capture(tester, 'calendar_event_actions_ar');
  });
}

FakeCalendarRepository _richRepo() {
  final events = [
    sampleCalendarEvent(
      id: 'evt-1',
      titleAr: 'تعبئة زيت المحرك - موعد دوري',
      titleEn: 'Engine oil refill — scheduled visit',
      customerId: 'cust-1',
      customerNameAr: 'مؤسسة النخبة لقطع غيار السيارات',
      customerNameEn: 'Elite Auto Parts',
      contractId: 'ct-1',
      contractNumber: 'CT-2026-014',
      serviceLocationName: 'ورشة الشويخ الصناعية',
      assignedAgentNameAr: 'أحمد الكندري',
      assignedAgentNameEn: 'Ahmad Al-Kandari',
      directionsAvailable: true,
      availableActions: const CalendarAvailableActions(
        canViewCustomer: true,
        canViewContract: true,
        canAssign: false,
        canReschedule: false,
        canCreateManual: false,
        canOpenDirections: true,
      ),
    ),
    sampleCalendarEvent(
      id: 'evt-2',
      type: CalendarEventType.billingDue,
      status: CalendarEventStatus.pending,
      titleAr: 'فاتورة صيانة دورية',
      titleEn: 'Periodic maintenance invoice',
      customerId: 'cust-2',
      customerNameAr: 'ورشة الفهد للصيانة',
      customerNameEn: 'Al-Fahad Workshop',
      assignedAgentNameAr: 'سارة العتيبي',
      assignedAgentNameEn: 'Sara Al-Otaibi',
    ),
    sampleCalendarEvent(
      id: 'evt-3',
      type: CalendarEventType.custom,
      status: CalendarEventStatus.pending,
      titleAr: 'زيارة تفتيش غير مجدولة',
      titleEn: 'Unscheduled inspection visit',
      customerNameAr: 'شركة المسار للنقل',
      customerNameEn: 'Al-Masar Transport',
    ),
  ];

  return FakeCalendarRepository(
    listResult: sampleEventList(
      inRangeRows: events,
      overdueRows: [
        sampleCalendarEvent(
          id: 'od-1',
          scheduledDate: DateTime(2026, 6, 20),
          originalDueDate: DateTime(2026, 6, 20),
          titleAr: 'تعبئة متأخرة — محطة الواحة',
          titleEn: 'Overdue refill — Al-Waha Station',
          customerNameAr: 'محطة الواحة',
          customerNameEn: 'Al-Waha Station',
          isOverdue: true,
          overdueDays: 24,
          overdueState: CalendarOverdueState.overdue,
        ),
      ],
    ),
    eventCountForDate: (d) {
      if (d.day == 14) return 3;
      if (d.day == 15) return 1;
      if (d.day == 20) return 2;
      return 0;
    },
  );
}

Future<void> _revealAgenda(WidgetTester tester) async {
  for (var i = 0; i < 30; i++) {
    if (find.byKey(const Key('calendar-agenda-date')).evaluate().isNotEmpty) {
      return;
    }
    final list = find.byType(Scrollable).first;
    await tester.drag(list, const Offset(0, -500));
    await tester.pumpAndSettle();
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required Size size,
  required Locale locale,
  required FakeCalendarRepository repo,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final base = AppTheme.light();
  final theme = base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: 'NotoSans',
      fontFamilyFallback: const ['NotoSansArabic'],
    ),
    primaryTextTheme: base.primaryTextTheme.apply(
      fontFamily: 'NotoSans',
      fontFamilyFallback: const ['NotoSansArabic'],
    ),
  );

  await tester.pumpWidget(
    RepaintBoundary(
      key: _rootKey,
      child: ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _TestAuth(
              _session({
                'calendar.view',
                'customers.view',
                'contracts.view',
              }),
            ),
          ),
          calendarRepositoryProvider.overrideWith((ref) => repo),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: theme,
          home: const CalendarScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary =
      _rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('build/screenshots')..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _loadFonts() async {
  const families = {
    'NotoSans': [
      'assets/fonts/noto/NotoSans-Regular.ttf',
      'assets/fonts/noto/NotoSans-Bold.ttf',
    ],
    'NotoSansArabic': [
      'assets/fonts/noto/NotoSansArabic-Regular.ttf',
      'assets/fonts/noto/NotoSansArabic-Bold.ttf',
    ],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final asset in entry.value) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
}

class _TestAuth extends AuthController {
  _TestAuth(this.session);
  final AppSession? session;
  @override
  FutureOr<AppSession?> build() => session;
}

AppSession _session(Set<String> permissions) {
  return AppSession(
    userId: 'u',
    email: 'e@test.com',
    tenantId: 't',
    tenantUserId: 'tu',
    accountType: 'user',
    displayName: 'مستخدم تجريبي',
    preferredLocale: 'ar',
    permissions: AppPermissions(isManager: false, permissions: permissions),
  );
}
