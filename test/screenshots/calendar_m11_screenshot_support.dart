part of 'calendar_m11_screenshots.dart';

final _rootKey = GlobalKey();
const _phone360 = Size(360, 800);
const _phone412 = Size(412, 900);
const _desktop = Size(1280, 800);

const _customerId = '11111111-1111-4111-8111-111111111111';
const _contractId = '22222222-2222-4222-8222-222222222222';

class _TestAuth extends AuthController {
  _TestAuth(this.session);
  final AppSession? session;
  @override
  FutureOr<AppSession?> build() => session;
}

AppSession _session({Set<String> permissions = const {'calendar.view'}}) {
  return AppSession(
    userId: 'u',
    email: 'e@test.com',
    tenantId: 't',
    tenantUserId: 'tu',
    accountType: 'user',
    displayName: 'Test User',
    preferredLocale: 'en',
    permissions: AppPermissions(isManager: false, permissions: permissions),
  );
}

FakeCalendarRepository _repo() {
  return FakeCalendarRepository(
    filterAgendaToRequestedDate: true,
    rangeScope: CalendarReadScope.tenantWide,
    eventCountForDate: (_) => 1,
    listResult: sampleEventList(
      tenantLocalToday: DateTime(2026, 7, 14),
      inRangeRows: [
        sampleCalendarEvent(
          id: 'evt-1',
          scheduledDate: DateTime(2026, 7, 14),
          titleEn: 'Scoped event',
          titleAr: 'حدث نطاق',
        ),
      ],
    ),
  );
}

Future<void> _pumpCalendar(
  WidgetTester tester, {
  required Locale locale,
  required Size size,
  String? customerId,
  String? contractId,
  double textScale = 1.0,
}) async {
  final session = _session();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    RepaintBoundary(
      key: _rootKey,
      child: ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => _TestAuth(session)),
          calendarRepositoryProvider.overrideWith((ref) => _repo()),
        ],
        child: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: locale,
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: CalendarScreen(
              customerIdQueryParam: customerId,
              contractIdQueryParam: contractId,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 200));
}

Future<GoRouter> _pumpCalendarRouter(
  WidgetTester tester, {
  required Locale locale,
  required Size size,
  String? customerId,
  String? contractId,
}) async {
  final session = _session();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final router = GoRouter(
    initialLocation: AppRoutes.calendarPath(
      customerId: customerId,
      contractId: contractId,
    ),
    routes: [
      GoRoute(
        path: AppRoutes.calendar,
        builder: (context, state) => CalendarScreen(
          customerIdQueryParam: state.uri.queryParameters['customerId'],
          contractIdQueryParam: state.uri.queryParameters['contractId'],
          dateQueryParam: state.uri.queryParameters['date'],
        ),
      ),
    ],
  );

  await tester.pumpWidget(
    RepaintBoundary(
      key: _rootKey,
      child: ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => _TestAuth(session)),
          calendarRepositoryProvider.overrideWith((ref) => _repo()),
        ],
        child: MediaQuery(
          data: MediaQueryData(size: size),
          child: MaterialApp.router(
            debugShowCheckedModeBanner: false,
            locale: locale,
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 50));
  await tester.pump(const Duration(milliseconds: 200));
  return router;
}

Future<void> _pumpCustomerHeader(
  WidgetTester tester, {
  required Locale locale,
  required Set<String> permissions,
}) async {
  const size = _phone360;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final customer = sampleCustomer(id: _customerId);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _rootKey,
      child: ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _TestAuth(_session(permissions: permissions)),
          ),
          customerServiceLocationRepositoryProvider.overrideWith(
            (ref) => FakeCustomerServiceLocationRepository(),
          ),
        ],
        child: MediaQuery(
          data: const MediaQueryData(size: size),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: locale,
            theme: AppTheme.light(),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: CustomerDetailHeader(
                customer: customer,
                customerId: customer.id,
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _pumpContractSchedule(
  WidgetTester tester, {
  required Locale locale,
  required Set<String> permissions,
}) async {
  const size = _phone360;
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final detail = sampleContractDetail(id: _contractId);
  final session = _session(permissions: permissions);
  await tester.pumpWidget(
    RepaintBoundary(
      key: _rootKey,
      child: MediaQuery(
        data: const MediaQueryData(size: size),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: locale,
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ContractUpcomingScheduleSection(
              detail: detail,
              languageCode: locale.languageCode,
              session: session,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
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
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final asset in entry.value) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  await tester.pump();
  final boundary =
      _rootKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.0);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final dir = Directory('build/screenshots')..createSync(recursive: true);
    File('${dir.path}/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}
