part of 'calendar_m7b_screenshots.dart';

// Shared fixtures/helpers for M7B working-date-exception screenshots.

final _rootKey = GlobalKey();
const _desktop = Size(1280, 900);
const _settingsNarrow = Size(480, 900);

// ---- Sessions ---------------------------------------------------------

class _TestAuth extends AuthController {
  _TestAuth(this.session);
  final AppSession? session;
  @override
  FutureOr<AppSession?> build() => session;
}

AppSession _settingsSession() {
  return AppSession(
    userId: 'u',
    email: 'e@test.com',
    tenantId: 't',
    tenantUserId: 'tu',
    accountType: 'user',
    displayName: 'Test User',
    preferredLocale: 'en',
    permissions: AppPermissions(
      isManager: false,
      permissions: const {'settings.calendar.edit'},
    ),
  );
}

AppSession _calendarSession() {
  return AppSession(
    userId: 'u',
    email: 'e@test.com',
    tenantId: 't',
    tenantUserId: 'tu',
    accountType: 'user',
    displayName: 'Test User',
    preferredLocale: 'en',
    permissions: AppPermissions(
      isManager: false,
      permissions: const {'calendar.view', 'calendar.create'},
    ),
  );
}

// ---- Sample working-date exceptions (shared across list/edit/cancel) --

WorkingDateException _holidayException() => sampleWorkingDateException(
  id: 'wde-holiday',
  kind: CalendarWorkingDateExceptionKind.officialHoliday,
  startDate: DateTime(2026, 7, 20),
  endDate: DateTime(2026, 7, 20),
  titleAr: 'عيد الأضحى',
  titleEn: 'Eid al-Adha',
);

WorkingDateException _closureException() => sampleWorkingDateException(
  id: 'wde-closure',
  kind: CalendarWorkingDateExceptionKind.companyClosure,
  startDate: DateTime(2026, 7, 25),
  endDate: DateTime(2026, 7, 27),
  titleAr: 'إغلاق الشركة - الصيانة السنوية',
  titleEn: 'Company closure — annual maintenance',
);

WorkingDateException _exceptionalHoursException() => sampleWorkingDateException(
  id: 'wde-exceptional-hours',
  kind: CalendarWorkingDateExceptionKind.exceptionalWorkingDay,
  startDate: DateTime(2026, 7, 30),
  endDate: DateTime(2026, 7, 30),
  titleAr: 'يوم عمل استثنائي - جرد',
  titleEn: 'Exceptional working day — inventory count',
  dayMode: TenantWorkingDayMode.workingHours,
  workStart: '08:00',
  workEnd: '13:00',
);

WorkingDateException _exceptional24hException() => sampleWorkingDateException(
  id: 'wde-exceptional-24h',
  kind: CalendarWorkingDateExceptionKind.exceptionalWorkingDay,
  startDate: DateTime(2026, 8, 1),
  endDate: DateTime(2026, 8, 1),
  titleAr: 'تشغيل على مدار الساعة',
  titleEn: '24-hour operation',
  dayMode: TenantWorkingDayMode.hours24,
);

FakeWorkingDateExceptionRepository _wdeRepo({Object? createError}) {
  return FakeWorkingDateExceptionRepository(
    listResult: sampleWorkingDateExceptionList(
      items: [
        _holidayException(),
        _closureException(),
        _exceptionalHoursException(),
        _exceptional24hException(),
      ],
    ),
    createError: createError,
  );
}

CalendarSettings _configuredCalendarSettings() {
  const window = (workStart: '08:00', workEnd: '17:00');
  return CalendarSettings(
    timezoneName: 'Asia/Kuwait',
    timezoneConfirmed: true,
    workingScheduleConfigured: true,
    canEdit: true,
    days: [
      for (final iso in [1, 2, 3, 4, 7])
        WorkingDayRow(
          isoWeekday: iso,
          mode: TenantWorkingDayMode.workingHours,
          workStart: window.workStart,
          workEnd: window.workEnd,
        ),
      for (final iso in [5, 6])
        WorkingDayRow(isoWeekday: iso, mode: TenantWorkingDayMode.dayOff),
    ],
  );
}

// ---- Settings screen pump/scroll/dialog helpers ------------------------

Future<void> _pumpSettings(
  WidgetTester tester, {
  required Size size,
  required Locale locale,
  required FakeWorkingDateExceptionRepository wdeRepo,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    RepaintBoundary(
      key: _rootKey,
      child: ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _TestAuth(_settingsSession()),
          ),
          calendarSettingsRepositoryProvider.overrideWith(
            (ref) => FakeCalendarSettingsRepository(
              settings: _configuredCalendarSettings(),
            ),
          ),
          calendarWorkingDateExceptionRepositoryProvider.overrideWith(
            (ref) => wdeRepo,
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: _screenshotTheme(),
          home: const CalendarSettingsScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
  await _scrollSettingsTo(tester, const Key('calendar-wde-add'));
}

Future<void> _scrollSettingsTo(WidgetTester tester, Key key) async {
  final target = find.byKey(key, skipOffstage: false);
  final list = find.byKey(const Key('calendar-settings-list'));
  for (var i = 0; i < 30; i++) {
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      return;
    }
    await tester.drag(list, const Offset(0, -300));
    await tester.pumpAndSettle();
  }
  fail('Could not scroll to $key');
}

Future<void> _openCreateDialog(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('calendar-wde-add')));
  await tester.pumpAndSettle();
}

Future<void> _openEditDialog(WidgetTester tester, String id) async {
  await _scrollSettingsTo(tester, Key('calendar-wde-edit-$id'));
  await tester.tap(find.byKey(Key('calendar-wde-edit-$id')));
  await tester.pumpAndSettle();
}

Future<void> _openCancelDialog(WidgetTester tester, String id) async {
  await _scrollSettingsTo(tester, Key('calendar-wde-cancel-$id'));
  await tester.tap(find.byKey(Key('calendar-wde-cancel-$id')));
  await tester.pumpAndSettle();
}

AppLocalizations _dialogL10n(WidgetTester tester) {
  final dialog = find.byType(AlertDialog);
  final element = dialog.evaluate().isNotEmpty
      ? tester.element(dialog.first)
      : tester.element(find.byType(MaterialApp));
  return AppLocalizations.of(element)!;
}

Future<void> _selectKind(
  WidgetTester tester,
  CalendarWorkingDateExceptionKind kind,
) async {
  await tester.tap(find.byKey(const Key('calendar-wde-kind')));
  await tester.pumpAndSettle();
  final label = calendarWorkingDateExceptionKindLabel(
    _dialogL10n(tester),
    kind,
  );
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _selectDayMode(
  WidgetTester tester,
  TenantWorkingDayMode mode,
) async {
  final l10n = _dialogL10n(tester);
  final label = mode == TenantWorkingDayMode.hours24
      ? l10n.calendarWorkingDateExceptionDayMode24Hours
      : l10n.calendarWorkingDateExceptionDayModeLimitedHours;
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

/// Both start/end date pickers open on the current-month grid (the dialog's
/// `_pickDate` falls back to `DateTime.now()` until a date is chosen), so
/// `day` is always a plain day-of-month number, never a specific `DateTime`.
Future<void> _pickDate(WidgetTester tester, Key fieldKey, int day) async {
  await tester.tap(find.byKey(fieldKey));
  await tester.pumpAndSettle();
  await tester.tap(find.text('$day').last);
  await tester.pumpAndSettle();
  final okLabel = MaterialLocalizations.of(
    tester.element(find.byType(AlertDialog).first),
  ).okButtonLabel;
  await tester.tap(find.text(okLabel));
  await tester.pumpAndSettle();
}

Future<void> _fillCreateForm(
  WidgetTester tester, {
  required CalendarWorkingDateExceptionKind kind,
  required int startDay,
  required int endDay,
  required String titleAr,
  required String titleEn,
  TenantWorkingDayMode? dayMode,
  String? workStart,
  String? workEnd,
}) async {
  await _selectKind(tester, kind);
  await _pickDate(tester, const Key('calendar-wde-start-date'), startDay);
  await _pickDate(tester, const Key('calendar-wde-end-date'), endDay);
  await tester.enterText(
    find.byKey(const Key('calendar-wde-title-ar')),
    titleAr,
  );
  await tester.enterText(
    find.byKey(const Key('calendar-wde-title-en')),
    titleEn,
  );
  await tester.pumpAndSettle();
  if (dayMode != null) {
    await _selectDayMode(tester, dayMode);
    if (workStart != null) {
      await tester.enterText(
        find.byKey(const Key('calendar-wde-work-start')),
        workStart,
      );
    }
    if (workEnd != null) {
      await tester.enterText(
        find.byKey(const Key('calendar-wde-work-end')),
        workEnd,
      );
    }
    await tester.pumpAndSettle();
  }
}

// ---- Calendar month/agenda pump/select helpers -------------------------

CalendarWorkingDay _exceptionWorkingDay(
  DateTime date,
  CalendarDateExceptionRef exception,
) {
  return CalendarWorkingDay(
    tenantId: 'tenant-1',
    date: date,
    isoWeekday: date.weekday,
    scheduleConfigured: true,
    timezoneName: 'Asia/Kuwait',
    dayMode: TenantWorkingDayMode.dayOff,
    isUnreviewed: false,
    isDayOff: true,
    is24Hours: false,
    isWorkingHours: false,
    dateException: exception,
  );
}

final _holidayMarkerDate = DateTime(2026, 7, 20);
final _closureConflictDate = DateTime(2026, 7, 21);

FakeCalendarRepository _calendarRepoWithExceptions() {
  return FakeCalendarRepository(
    echoAgendaDate: true,
    workingDayForDate: (date) {
      if (date == _holidayMarkerDate) {
        return _exceptionWorkingDay(
          date,
          const CalendarDateExceptionRef(
            kind: CalendarWorkingDateExceptionKind.officialHoliday,
            titleAr: 'عيد الأضحى',
            titleEn: 'Eid al-Adha',
          ),
        );
      }
      if (date == _closureConflictDate) {
        return _exceptionWorkingDay(
          date,
          const CalendarDateExceptionRef(
            kind: CalendarWorkingDateExceptionKind.companyClosure,
            titleAr: 'إغلاق الشركة - الصيانة السنوية',
            titleEn: 'Company closure — annual maintenance',
          ),
        );
      }
      return sampleCalendarWorkingDay(date: date);
    },
    // A closure day with a scheduled event is a genuine conflict: the grid
    // shows the warning triangle instead of the plain exception glyph.
    eventCountForDate: (date) => date == _closureConflictDate ? 1 : 0,
  );
}

Future<void> _pumpCalendar(
  WidgetTester tester, {
  required Locale locale,
  required FakeCalendarRepository repo,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = _desktop;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.binding.setSurfaceSize(_desktop);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    RepaintBoundary(
      key: _rootKey,
      child: ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _TestAuth(_calendarSession()),
          ),
          calendarRepositoryProvider.overrideWith((ref) => repo),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: locale,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: _screenshotTheme(),
          home: const CalendarScreen(),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
}

Future<void> _selectDay(WidgetTester tester, DateTime date) async {
  await tester.tap(
    find.byKey(Key('calendar-day-${date.year}-${date.month}-${date.day}')),
  );
  await tester.pumpAndSettle();
  await _revealAgenda(tester);
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
  fail('Could not reveal agenda header');
}

// ---- Rendering plumbing (theme/fonts/capture), mirrors calendar_m6 -----

ThemeData _screenshotTheme() {
  final base = AppTheme.light();
  return base.copyWith(
    textTheme: base.textTheme.apply(
      fontFamily: 'NotoSans',
      fontFamilyFallback: const ['NotoSansArabic'],
    ),
    primaryTextTheme: base.primaryTextTheme.apply(
      fontFamily: 'NotoSans',
      fontFamilyFallback: const ['NotoSansArabic'],
    ),
  );
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
  const families = <String, List<String>>{
    'NotoSans': [
      'assets/fonts/noto/NotoSans-Regular.ttf',
      'assets/fonts/noto/NotoSans-Bold.ttf',
    ],
    'NotoSansArabic': [
      'assets/fonts/noto/NotoSansArabic-Regular.ttf',
      'assets/fonts/noto/NotoSansArabic-Bold.ttf',
    ],
    'MaterialIcons': ['assets/fonts/material/MaterialIcons-Regular.otf'],
    // IconData from flutter_lucide uses fontPackage, so tests must register
    // the package-prefixed family name used at paint time.
    'packages/flutter_lucide/lucide': ['assets/fonts/lucide/lucide.ttf'],
    'lucide': ['assets/fonts/lucide/lucide.ttf'],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final asset in entry.value) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
}
