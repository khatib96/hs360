part of 'calendar_m6_screenshots.dart';

// Shared fixtures/helpers for M7A calendar screenshots.
// Intentionally ~400 lines: multi-scenario pump/capture support.

final _rootKey = GlobalKey();
const _desktop = Size(1280, 900);
const _narrow = Size(1000, 900);

const _participants = [
  CalendarEventParticipant(
    employeeId: 'emp-1',
    nameAr: 'أحمد الكندري',
    nameEn: 'Ahmad Al-Kandari',
    isActive: true,
    hasAppAccount: true,
  ),
  CalendarEventParticipant(
    employeeId: 'emp-2',
    nameAr: 'سارة العتيبي',
    nameEn: 'Sara Al-Otaibi',
    isActive: true,
    hasAppAccount: true,
  ),
];

final _demoCustomer = Customer(
  id: 'cust-1',
  tenantId: 't',
  code: 'CUST-0001',
  customerType: CustomerType.company,
  nameAr: 'مؤسسة النخبة لقطع غيار السيارات',
  nameEn: 'Elite Auto Parts',
  phonePrimary: '99000000',
  isActive: true,
  isVip: false,
);

const _demoLocation = CustomerServiceLocation(
  id: 'loc-1',
  tenantId: 't',
  customerId: 'cust-1',
  code: 'LOC-1',
  name: 'ورشة الشويخ الصناعية',
  locationType: ServiceLocationType.installationSite,
  isPrimary: true,
  isActive: true,
);

FakeCalendarRepository _richRepo() {
  final events = [
    sampleCalendarEvent(
      id: 'evt-meeting',
      type: CalendarEventType.internalMeeting,
      sourceKind: CalendarEventSourceKind.manual,
      titleAr: 'اجتماع تنسيق الفريق',
      titleEn: 'Team coordination meeting',
      meetingMode: CalendarMeetingMode.online,
      meetingUrl: 'https://meet.example.com/hs360-standup',
      participants: _participants,
      timeWindow: const CalendarTimeWindow(
        startLocal: '09:00',
        endLocal: '09:45',
        timezoneName: 'Asia/Kuwait',
      ),
      availableActions: const CalendarAvailableActions(
        canViewCustomer: false,
        canViewContract: false,
        canAssign: false,
        canReschedule: false,
        canCreateManual: true,
        canOpenDirections: false,
        canEditManual: true,
        canCancelManual: true,
        canMarkManualDone: true,
        canOpenMeetingLink: true,
      ),
    ),
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
        canCreateManual: true,
        canOpenDirections: true,
        canEditManual: false,
        canCancelManual: false,
        canMarkManualDone: false,
        canOpenMeetingLink: false,
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
      type: CalendarEventType.customerVisit,
      sourceKind: CalendarEventSourceKind.manual,
      status: CalendarEventStatus.pending,
      titleAr: 'زيارة عميل — مبيعات',
      titleEn: 'Customer visit — sales',
      customerNameAr: 'شركة المسار للنقل',
      customerNameEn: 'Al-Masar Transport',
    ),
  ];

  return FakeCalendarRepository(
    participantCandidates: _participants,
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
      if (d.day == 14) return 4;
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

Future<void> _openMeetingActions(WidgetTester tester) async {
  await _revealAgenda(tester);
  final meetingInk = find.byKey(const Key('calendar-event-ink-evt-meeting'));
  await tester.ensureVisible(meetingInk);
  await tester.pumpAndSettle();
  await tester.tap(meetingInk);
  await tester.pumpAndSettle();
}

Future<void> _selectManualType(
  WidgetTester tester,
  CalendarEventType type,
) async {
  await tester.tap(find.byKey(const Key('calendar-manual-type')));
  await tester.pumpAndSettle();
  final label = _manualTypeLabel(tester, type);
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

Future<void> _selectMeetingModeOnline(WidgetTester tester) async {
  await tester.tap(find.byKey(const Key('calendar-manual-meeting-mode')));
  await tester.pumpAndSettle();
  final label = _l10n(tester).calendarMeetingModeOnline;
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

AppLocalizations _l10n(WidgetTester tester) {
  final dialog = find.byType(AlertDialog);
  final element = dialog.evaluate().isNotEmpty
      ? tester.element(dialog.first)
      : tester.element(find.byType(MaterialApp));
  return AppLocalizations.of(element)!;
}

String _manualTypeLabel(WidgetTester tester, CalendarEventType type) {
  final l10n = _l10n(tester);
  return switch (type) {
    CalendarEventType.customerVisit => l10n.calendarEventTypeCustomerVisit,
    CalendarEventType.internalMeeting => l10n.calendarEventTypeInternalMeeting,
    CalendarEventType.internalTask => l10n.calendarEventTypeInternalTask,
    CalendarEventType.internalActivity => l10n.calendarEventTypeInternalActivity,
    CalendarEventType.custom => l10n.calendarEventTypeCustom,
    _ => type.name,
  };
}

Future<void> _scrollDialogTo(WidgetTester tester, Key key) async {
  for (var i = 0; i < 20; i++) {
    if (find.byKey(key).evaluate().isNotEmpty) {
      await tester.ensureVisible(find.byKey(key));
      await tester.pumpAndSettle();
      return;
    }
    final scrollables = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(Scrollable),
    );
    if (scrollables.evaluate().isEmpty) return;
    await tester.drag(scrollables.first, const Offset(0, -200));
    await tester.pumpAndSettle();
  }
}

Future<void> _pumpCustomerVisitDialog(
  WidgetTester tester, {
  required Locale locale,
}) async {
  await _pump(
    tester,
    size: _desktop,
    locale: locale,
    repo: _richRepo(),
  );
  await tester.tap(find.byKey(const Key('calendar-create-event')));
  await tester.pumpAndSettle();
  await _selectManualType(tester, CalendarEventType.customerVisit);
  await _scrollDialogTo(tester, const Key('calendar-manual-customer-search'));
  final search = find.byKey(const Key('calendar-manual-customer-search'));
  await tester.enterText(search, 'نخبة');
  await tester.testTextInput.receiveAction(TextInputAction.done);
  await tester.pumpAndSettle();
  final customerLabel = locale.languageCode == 'ar'
      ? _demoCustomer.nameAr
      : (_demoCustomer.nameEn ?? _demoCustomer.nameAr);
  await tester.tap(find.text(customerLabel).last);
  await tester.pumpAndSettle();
  await _scrollDialogTo(tester, const Key('calendar-manual-location'));
}

Future<void> _pumpConflictDialog(
  WidgetTester tester, {
  required Locale locale,
  required CalendarManualConflictInfo conflicts,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = _desktop;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.binding.setSurfaceSize(_desktop);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final theme = _screenshotTheme();

  await tester.pumpWidget(
    RepaintBoundary(
      key: _rootKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: theme,
        home: Builder(
          builder: (context) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              showCalendarConflictConfirmDialog(
                context: context,
                conflicts: conflicts,
              );
            });
            return const Scaffold(body: SizedBox.expand());
          },
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pumpAndSettle();
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

List<Override> _lookupOverrides() {
  return [
    customerRepositoryProvider.overrideWith(
      (ref) => FakeCustomerRepository(customers: [_demoCustomer]),
    ),
    customerServiceLocationRepositoryProvider.overrideWith(
      (ref) => FakeCustomerServiceLocationRepository(
        locations: [_demoLocation],
      ),
    ),
    contractRepositoryProvider.overrideWith(
      (ref) => FakeContractRepository(
        summaries: [
          sampleContractSummary(id: 'ct-1'),
        ],
      ),
    ),
  ];
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

  final theme = _screenshotTheme();

  await tester.pumpWidget(
    RepaintBoundary(
      key: _rootKey,
      child: ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _TestAuth(
              _session({
                'calendar.view',
                'calendar.create',
                'calendar.edit',
                'customers.view',
                'contracts.view',
              }),
            ),
          ),
          calendarRepositoryProvider.overrideWith((ref) => repo),
          ..._lookupOverrides(),
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
  const families = <String, List<String>>{
    'NotoSans': [
      'assets/fonts/noto/NotoSans-Regular.ttf',
      'assets/fonts/noto/NotoSans-Bold.ttf',
    ],
    'NotoSansArabic': [
      'assets/fonts/noto/NotoSansArabic-Regular.ttf',
      'assets/fonts/noto/NotoSansArabic-Bold.ttf',
    ],
    'MaterialIcons': [
      'assets/fonts/material/MaterialIcons-Regular.otf',
    ],
    // IconData from flutter_lucide uses fontPackage, so tests must register
    // the package-prefixed family name used at paint time.
    'packages/flutter_lucide/lucide': [
      'assets/fonts/lucide/lucide.ttf',
    ],
    'lucide': [
      'assets/fonts/lucide/lucide.ttf',
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
