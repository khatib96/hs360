part of 'calendar_m9_screenshots.dart';

final _rootKey = GlobalKey();
const _phone = Size(360, 800);

class _TestAuth extends AuthController {
  _TestAuth(this.session);
  final AppSession? session;
  @override
  FutureOr<AppSession?> build() => session;
}

AppSession _editSession() {
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
      permissions: const {'calendar.view', 'calendar.edit', 'calendar.create'},
    ),
  );
}

AppSession _assignedSession() {
  return AppSession(
    userId: 'u',
    email: 'e@test.com',
    tenantId: 't',
    tenantUserId: 'tu',
    accountType: 'user',
    displayName: 'Field User',
    preferredLocale: 'en',
    permissions: AppPermissions(
      isManager: false,
      permissions: const {'calendar.view_assigned'},
    ),
  );
}

CalendarAvailableActions _actions({
  bool canAssign = true,
  bool canReschedule = true,
  bool canOpenDirections = true,
}) {
  return CalendarAvailableActions(
    canViewCustomer: true,
    canViewContract: true,
    canAssign: canAssign,
    canReschedule: canReschedule,
    canCreateManual: false,
    canOpenDirections: canOpenDirections,
    canEditManual: false,
    canCancelManual: false,
    canMarkManualDone: false,
    canOpenMeetingLink: false,
  );
}

final _today = DateTime(2026, 7, 14);
final _otherDay = DateTime(2026, 7, 15);

int _eventCountForDate(DateTime d) {
  final day = DateTime(d.year, d.month, d.day);
  if (day == _today) return 2;
  if (day == _otherDay) return 1;
  return 0;
}

FakeCalendarRepository _repo({
  CalendarReadScope scope = CalendarReadScope.tenantWide,
}) {
  final unassigned = scope == CalendarReadScope.assignedOnly ? null : 2;
  return FakeCalendarRepository(
    filterAgendaToRequestedDate: true,
    rangeScope: scope,
    rangeUnassignedCount: unassigned,
    eventCountForDate: _eventCountForDate,
    listResult: sampleEventList(
      tenantLocalToday: _today,
      inRangeRows: [
        sampleCalendarEvent(
          id: 'evt-gen',
          scheduledDate: _today,
          titleAr: 'تعبئة مولدة',
          titleEn: 'Generated refill',
          customerNameAr: 'شركة النخيل',
          customerNameEn: 'Palm Gardens',
          serviceLocationName: 'Main site',
          contractNumber: 'C-100',
          directionsAvailable: true,
          availableActions: _actions(),
        ),
        sampleCalendarEvent(
          id: 'evt-timed',
          scheduledDate: _today,
          type: CalendarEventType.customerVisit,
          sourceKind: CalendarEventSourceKind.manual,
          titleAr: 'زيارة بوقت',
          titleEn: 'Timed visit',
          timeWindow: const CalendarTimeWindow(
            startLocal: '09:00',
            endLocal: '10:00',
            timezoneName: 'Asia/Kuwait',
          ),
        ),
        sampleCalendarEvent(
          id: 'evt-other-day',
          scheduledDate: _otherDay,
          titleEn: 'Next-day visit',
          titleAr: 'زيارة اليوم التالي',
          type: CalendarEventType.customerVisit,
          sourceKind: CalendarEventSourceKind.manual,
        ),
      ],
      overdueRows: [
        sampleCalendarEvent(
          id: 'od-1',
          scheduledDate: DateTime(2026, 6, 1),
          isOverdue: true,
          overdueDays: 20,
          overdueState: CalendarOverdueState.overdue,
          titleEn: 'Overdue item',
          titleAr: 'متأخر',
        ),
      ],
    ),
  );
}

FakeCalendarRepository _conflictRepo() {
  return FakeCalendarRepository(
    filterAgendaToRequestedDate: true,
    eventCountForDate: (d) =>
        DateTime(d.year, d.month, d.day) == _today ? 1 : 0,
    rangeUnassignedCount: 1,
    workingDayForDate: (d) =>
        sampleCalendarWorkingDay(date: d, dayMode: TenantWorkingDayMode.dayOff),
    listResult: sampleEventList(
      tenantLocalToday: _today,
      inRangeRows: [
        sampleCalendarEvent(
          id: 'evt-conflict',
          scheduledDate: _today,
          scheduleState: CalendarScheduleState.dayOffOverridden,
          workingDay: sampleCalendarWorkingDay(
            date: _today,
            dayMode: TenantWorkingDayMode.dayOff,
          ),
          titleEn: 'Conflict visit',
          titleAr: 'زيارة متعارضة',
        ),
      ],
      overdueRows: const [],
    ),
  );
}

FakeCalendarRepository _exceptionalRepo() {
  return FakeCalendarRepository(
    filterAgendaToRequestedDate: true,
    eventCountForDate: (d) =>
        DateTime(d.year, d.month, d.day) == _today ? 1 : 0,
    rangeUnassignedCount: 1,
    workingDayForDate: (d) => sampleCalendarWorkingDay(
      date: d,
      dayMode: TenantWorkingDayMode.workingHours,
      workStart: '10:00',
      workEnd: '14:00',
      dateException: const CalendarDateExceptionRef(
        kind: CalendarWorkingDateExceptionKind.exceptionalWorkingDay,
        titleAr: 'دوام استثنائي للمخزون',
        titleEn: 'Inventory special hours',
      ),
    ),
    listResult: sampleEventList(
      tenantLocalToday: _today,
      inRangeRows: [sampleCalendarEvent(id: 'evt-1', scheduledDate: _today)],
      overdueRows: const [],
    ),
  );
}

FakeCalendarRepository _assignedOnlyRepo() {
  return FakeCalendarRepository(
    filterAgendaToRequestedDate: true,
    rangeScope: CalendarReadScope.assignedOnly,
    rangeUnassignedCount: null,
    eventCountForDate: (d) =>
        DateTime(d.year, d.month, d.day) == _today ? 1 : 0,
    listResult: sampleEventList(
      tenantLocalToday: _today,
      inRangeRows: [
        sampleCalendarEvent(
          id: 'evt-mine',
          scheduledDate: _today,
          titleEn: 'My assigned refill',
          titleAr: 'تعبئتي المعيّنة',
          customerNameEn: 'Palm Gardens',
          customerNameAr: 'شركة النخيل',
          assignedAgentId: 'tu',
          assignedAgentNameEn: 'Field User',
          assignedAgentNameAr: 'مستخدم ميداني',
          availableActions: _actions(canAssign: false, canReschedule: false),
        ),
      ],
      overdueRows: const [],
    ),
  );
}

FakeCalendarRepository _lockedRepo() {
  return FakeCalendarRepository(
    filterAgendaToRequestedDate: true,
    rangeScope: CalendarReadScope.assignedOnly,
    rangeUnassignedCount: null,
    eventCountForDate: (d) =>
        DateTime(d.year, d.month, d.day) == _today ? 1 : 0,
    listResult: sampleEventList(
      tenantLocalToday: _today,
      inRangeRows: [
        sampleCalendarEvent(
          id: 'evt-locked',
          scheduledDate: _today,
          availableActions: _actions(canAssign: false, canReschedule: false),
        ),
      ],
      overdueRows: const [],
    ),
  );
}

FakeCalendarRepository _emptyRepo() {
  return FakeCalendarRepository(
    filterAgendaToRequestedDate: true,
    rangeUnassignedCount: 0,
    eventCountForDate: (_) => 0,
    rangeResult: sampleRangeSummary(
      tenantLocalToday: _today,
      unassignedCount: 0,
      eventCountForDate: (_) => 0,
      overdueState: CalendarOverdueOutsideRangeState.available,
      overdueOutsideCount: 0,
    ),
    listResult: sampleEventList(
      tenantLocalToday: _today,
      inRangeRows: const [],
      overdueRows: const [],
    ),
  );
}

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

Future<void> _pumpMobile(
  WidgetTester tester, {
  required Locale locale,
  required FakeCalendarRepository repo,
  AppSession? session,
  Size size = _phone,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  // RepaintBoundary outside MaterialApp so Navigator overlays (sheets /
  // dialogs) are included in the capture — same pattern as M8 harness.
  await tester.pumpWidget(
    RepaintBoundary(
      key: _rootKey,
      child: ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _TestAuth(session ?? _editSession()),
          ),
          calendarRepositoryProvider.overrideWith((ref) => repo),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: locale,
          theme: _screenshotTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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
