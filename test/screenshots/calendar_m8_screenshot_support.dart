part of 'calendar_m8_screenshots.dart';

// Shared fixtures/helpers for M8 assignment/reschedule screenshots.

final _rootKey = GlobalKey();
const _desktop = Size(1280, 900);
// Dialogs are 420 logical px wide; 800 keeps them readable without overflow.
const _narrow = Size(800, 900);

const _assignableEventId = 'evt-assign';
const _meetingEventId = 'evt-meeting';
const _cancelledEventId = 'evt-cancelled';

// ---- Session ------------------------------------------------------------

class _TestAuth extends AuthController {
  _TestAuth(this.session);
  final AppSession? session;
  @override
  FutureOr<AppSession?> build() => session;
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
      permissions: const {'calendar.view', 'calendar.edit'},
    ),
  );
}

// ---- Fixtures -----------------------------------------------------------

CalendarAvailableActions _m8Actions() {
  return const CalendarAvailableActions(
    canViewCustomer: false,
    canViewContract: false,
    canAssign: true,
    canReschedule: true,
    canCreateManual: false,
    canOpenDirections: false,
    canEditManual: false,
    canCancelManual: false,
    canMarkManualDone: false,
    canOpenMeetingLink: false,
  );
}

CalendarEvent _assignableEvent() {
  return sampleCalendarEvent(
    id: _assignableEventId,
    titleAr: 'إعادة تعبئة - عميل النخيل',
    titleEn: 'Refill due — Palm Gardens client',
    customerNameAr: 'شركة النخيل',
    customerNameEn: 'Palm Gardens Co.',
    // Assigned to someone who is no longer an active candidate, so the
    // assignment dialog renders the "current (unavailable)" option.
    assignedAgentId: 'emp-old',
    assignedAgentNameAr: 'وكيل سابق',
    assignedAgentNameEn: 'Previous Agent',
    timeWindow: const CalendarTimeWindow(
      startLocal: '09:00',
      endLocal: '10:30',
      timezoneName: 'Asia/Kuwait',
    ),
    availableActions: _m8Actions(),
  );
}

// Server flags for an organizer-owned pending meeting: never assignable,
// reschedulable by the organizer only.
CalendarEvent _meetingEvent() {
  return sampleCalendarEvent(
    id: _meetingEventId,
    type: CalendarEventType.internalMeeting,
    sourceKind: CalendarEventSourceKind.manual,
    titleAr: 'اجتماع الفريق الأسبوعي',
    titleEn: 'Weekly team meeting',
    availableActions: const CalendarAvailableActions(
      canViewCustomer: false,
      canViewContract: false,
      canAssign: false,
      canReschedule: true,
      canCreateManual: false,
      canOpenDirections: false,
      canEditManual: true,
      canCancelManual: true,
      canMarkManualDone: true,
      canOpenMeetingLink: false,
    ),
  );
}

// Terminal status: the server grants no mutation actions at all.
CalendarEvent _cancelledEvent() {
  return sampleCalendarEvent(
    id: _cancelledEventId,
    status: CalendarEventStatus.cancelled,
    titleAr: 'زيارة ملغاة',
    titleEn: 'Cancelled visit',
    customerNameAr: 'شركة النخيل',
    customerNameEn: 'Palm Gardens Co.',
    availableActions: const CalendarAvailableActions(
      canViewCustomer: false,
      canViewContract: false,
      canAssign: false,
      canReschedule: false,
      canCreateManual: false,
      canOpenDirections: false,
      canEditManual: false,
      canCancelManual: false,
      canMarkManualDone: false,
      canOpenMeetingLink: false,
    ),
  );
}

FakeCalendarRepository _repoWith(List<CalendarEvent> events) {
  return FakeCalendarRepository(
    listResult: sampleEventList(inRangeRows: events, overdueRows: const []),
  );
}

FakeCalendarRepository _repo() {
  return FakeCalendarRepository(
    listResult: sampleEventList(
      inRangeRows: [_assignableEvent()],
      overdueRows: const [],
    ),
    participantCandidates: [
      sampleParticipantCandidate(
        employeeId: 'emp-ahmad',
        nameAr: 'أحمد الصباح',
        nameEn: 'Ahmad Al-Sabah',
      ),
      sampleParticipantCandidate(
        employeeId: 'emp-no-cal',
        nameAr: 'سارة الحربي',
        nameEn: 'Sara Al-Harbi',
        hasCalendarAccess: false,
      ),
      sampleParticipantCandidate(
        employeeId: 'emp-no-tenant',
        nameAr: 'فهد العتيبي',
        nameEn: 'Fahad Al-Otaibi',
        hasActiveTenantAccount: false,
      ),
      sampleParticipantCandidate(
        employeeId: 'emp-no-app',
        nameAr: 'نورة القحطاني',
        nameEn: 'Noura Al-Qahtani',
        hasAppAccount: false,
      ),
    ],
  );
}

const _dayOffConflict = CalendarManualConflictInfo(
  scheduleWarnings: [
    {'code': 'non_working_day'},
  ],
  overlapWarnings: [
    {'employee_id': 'emp-ahmad'},
  ],
  overlapTotalCount: 1,
);

// ---- Pump / dialog helpers ----------------------------------------------

Future<void> _pumpCalendar(
  WidgetTester tester, {
  required Locale locale,
  required FakeCalendarRepository repo,
  Size size = _desktop,
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

Future<void> _revealEvent(WidgetTester tester, String eventId) async {
  final target = find.byKey(Key('calendar-event-ink-$eventId'));
  for (var i = 0; i < 30; i++) {
    if (target.evaluate().isNotEmpty) {
      await tester.ensureVisible(target);
      await tester.pumpAndSettle();
      return;
    }
    final list = find.byType(Scrollable).first;
    await tester.drag(list, const Offset(0, -500));
    await tester.pumpAndSettle();
  }
  fail('Could not reveal event $eventId');
}

Future<void> _openActionsDialog(WidgetTester tester, String eventId) async {
  await _revealEvent(tester, eventId);
  await tester.tap(find.byKey(Key('calendar-event-ink-$eventId')));
  await tester.pumpAndSettle();
}

Future<void> _openAssignmentDialog(WidgetTester tester) async {
  await _openActionsDialog(tester, _assignableEventId);
  await tester.tap(
    find.byKey(const Key('calendar-assign-$_assignableEventId')),
  );
  await tester.pumpAndSettle();
}

Future<void> _openRescheduleDialog(WidgetTester tester) async {
  await _openActionsDialog(tester, _assignableEventId);
  await tester.tap(
    find.byKey(const Key('calendar-reschedule-$_assignableEventId')),
  );
  await tester.pumpAndSettle();
}

Future<void> _pickRescheduleDay(WidgetTester tester, int day) async {
  await tester.tap(find.byKey(const Key('calendar-reschedule-date')));
  await tester.pumpAndSettle();
  await tester.tap(find.text('$day').last);
  await tester.pumpAndSettle();
  final okLabel = MaterialLocalizations.of(
    tester.element(find.byType(AlertDialog).first),
  ).okButtonLabel;
  await tester.tap(find.text(okLabel));
  await tester.pumpAndSettle();
}

Future<void> _submitReschedule(
  WidgetTester tester, {
  required int day,
  required String reason,
}) async {
  await _openRescheduleDialog(tester);
  await _pickRescheduleDay(tester, day);
  await tester.enterText(
    find.byKey(const Key('calendar-reschedule-reason')),
    reason,
  );
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('calendar-reschedule-submit')));
  await tester.pumpAndSettle();
}

// ---- Rendering plumbing (theme/fonts/capture), mirrors calendar_m7b ----

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
