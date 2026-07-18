part of 'calendar_m10_screenshots.dart';

final _rootKey = GlobalKey();
const _phone360 = Size(360, 800);
const _phone412 = Size(412, 900);
const _desktop = Size(1280, 800);

class _TestAuth extends AuthController {
  _TestAuth(this.session);
  final AppSession? session;
  @override
  FutureOr<AppSession?> build() => session;
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

AppSession _officeSession() {
  return AppSession(
    userId: 'u',
    email: 'e@test.com',
    tenantId: 't',
    tenantUserId: 'tu',
    accountType: 'manager',
    displayName: 'Office User',
    preferredLocale: 'en',
    permissions: AppPermissions(isManager: true, permissions: const {}),
  );
}

CalendarAvailableActions _routeActions({bool canOpenDirections = true}) {
  return CalendarAvailableActions(
    canViewCustomer: true,
    canViewContract: true,
    canAssign: false,
    canReschedule: false,
    canCreateManual: false,
    canOpenDirections: canOpenDirections,
    canEditManual: false,
    canCancelManual: false,
    canMarkManualDone: false,
    canOpenMeetingLink: false,
  );
}

final _today = DateTime(2026, 7, 14);

FakeCalendarRepository _assignedRouteRepo() {
  return FakeCalendarRepository()
    ..routeDayResult = CalendarRouteResult(
      date: _today,
      employeeId: 'tu',
      points: [
        CalendarRoutePoint(
          event: sampleCalendarEvent(
            id: 'route-mapped-1',
            scheduledDate: _today,
            titleAr: 'زيارة عميل',
            titleEn: 'Customer visit',
            customerNameEn: 'Palm Gardens',
            customerNameAr: 'شركة النخيل',
            serviceLocationName: 'Main site',
            directionsAvailable: true,
            availableActions: _routeActions(),
          ),
          locationState: CalendarRouteLocationState.mapped,
          latitude: 29.3759,
          longitude: 47.9774,
        ),
        CalendarRoutePoint(
          event: sampleCalendarEvent(
            id: 'route-unavailable-1',
            scheduledDate: _today,
            titleAr: 'زيارة بدون موقع',
            titleEn: 'Visit without location',
            availableActions: _routeActions(canOpenDirections: false),
          ),
          locationState: CalendarRouteLocationState.missing,
        ),
      ],
      hasMore: false,
    )
    ..directionsResult = sampleDirectionsTarget(eventId: 'route-mapped-1');
}

FakeCalendarRepository _mixedRouteRepo() {
  return FakeCalendarRepository()
    ..routeDayResult = CalendarRouteResult(
      date: _today,
      employeeId: 'tu',
      points: [
        CalendarRoutePoint(
          event: sampleCalendarEvent(
            id: 'mapped-a',
            scheduledDate: _today,
            titleEn: 'Mapped stop',
            titleAr: 'توقف بإحداثيات',
            directionsAvailable: true,
            availableActions: _routeActions(),
          ),
          locationState: CalendarRouteLocationState.mapped,
          latitude: 29.38,
          longitude: 47.98,
        ),
        CalendarRoutePoint(
          event: sampleCalendarEvent(
            id: 'url-only-b',
            scheduledDate: _today,
            titleEn: 'URL-only stop',
            titleAr: 'توقف برابط فقط',
            directionsAvailable: true,
            availableActions: _routeActions(),
          ),
          locationState: CalendarRouteLocationState.urlOnly,
        ),
        CalendarRoutePoint(
          event: sampleCalendarEvent(
            id: 'missing-c',
            scheduledDate: _today,
            titleEn: 'Missing location',
            titleAr: 'موقع مفقود',
            availableActions: _routeActions(canOpenDirections: false),
          ),
          locationState: CalendarRouteLocationState.missing,
        ),
        CalendarRoutePoint(
          event: sampleCalendarEvent(
            id: 'invalid-d',
            scheduledDate: _today,
            titleEn: 'Invalid location',
            titleAr: 'موقع غير صالح',
            availableActions: _routeActions(canOpenDirections: false),
          ),
          locationState: CalendarRouteLocationState.invalid,
        ),
      ],
      hasMore: false,
    )
    ..directionsResult = sampleDirectionsTarget(eventId: 'mapped-a');
}

FakeCalendarRepository _clusterRouteRepo() {
  return FakeCalendarRepository()
    ..routeDayResult = CalendarRouteResult(
      date: _today,
      employeeId: 'tu',
      points: [
        sampleRoutePoint(
          eventId: 'cluster-1',
          latitude: 29.3759,
          longitude: 47.9774,
        ),
        sampleRoutePoint(
          eventId: 'cluster-2',
          latitude: 29.3759,
          longitude: 47.9774,
        ),
      ],
      hasMore: false,
    );
}

FakeCalendarRepository _truncatedRouteRepo() {
  return FakeCalendarRepository()
    ..routeDayResult = sampleRouteResult(date: _today, hasMore: true);
}

FakeCalendarRepository _officeRouteRepo() {
  return FakeCalendarRepository()
    ..routeEmployeesResult = const CalendarRouteEmployeeListResult(
      employees: [
        CalendarRouteEmployee(
          employeeId: 'emp-1',
          nameAr: 'موظف أول',
          nameEn: 'First Employee',
          isActive: true,
        ),
        CalendarRouteEmployee(
          employeeId: 'emp-2',
          nameAr: 'موظف ثاني',
          nameEn: 'Second Employee',
          isActive: true,
        ),
      ],
      hasMore: false,
    )
    ..routeDayResult = sampleRouteResult(date: _today, employeeId: 'emp-1');
}

CalendarMapSurface _fakeMapSurfaceBuilder({
  required List<CalendarRoutePoint> points,
  required String? selectedEventId,
  required ValueChanged<String> onSelectEvent,
  required VoidCallback onTileFailure,
  required int tileSessionId,
}) {
  return FakeCalendarMapSurface(
    key: ValueKey('calendar-map-session-$tileSessionId'),
    points: points,
    selectedEventId: selectedEventId,
    onSelectEvent: onSelectEvent,
    groupSameCoordinates: true,
  );
}

CalendarMapSurface _failingMapSurfaceBuilder({
  required List<CalendarRoutePoint> points,
  required String? selectedEventId,
  required ValueChanged<String> onSelectEvent,
  required VoidCallback onTileFailure,
  required int tileSessionId,
}) {
  return _ScreenshotFailMapSurface(
    points: points,
    selectedEventId: selectedEventId,
    onSelectEvent: onSelectEvent,
    onTileFailure: onTileFailure,
    tileSessionId: tileSessionId,
  );
}

class _ScreenshotFailMapSurface extends CalendarMapSurface {
  const _ScreenshotFailMapSurface({
    required super.points,
    super.selectedEventId,
    required super.onSelectEvent,
    required this.onTileFailure,
    required this.tileSessionId,
  });

  final VoidCallback onTileFailure;
  final int tileSessionId;

  @override
  Widget build(BuildContext context) {
    if (tileSessionId == 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => onTileFailure());
    }
    return FakeCalendarMapSurface(
      points: points,
      selectedEventId: selectedEventId,
      onSelectEvent: onSelectEvent,
      groupSameCoordinates: true,
    );
  }
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

Future<void> _pumpRoute(
  WidgetTester tester, {
  required Locale locale,
  required FakeCalendarRepository repo,
  AppSession? session,
  String? dateQueryParam,
  Size size = _phone360,
  CalendarRouteMapSurfaceBuilder mapSurfaceBuilder = _fakeMapSurfaceBuilder,
}) async {
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
          authControllerProvider.overrideWith(
            () => _TestAuth(session ?? _assignedSession()),
          ),
          calendarRepositoryProvider.overrideWith((ref) => repo),
          calendarMapAppResolverProvider.overrideWithValue(
            CalendarMapAppResolver(canLaunch: (_) async => true),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: locale,
          theme: _screenshotTheme(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: CalendarRouteScreen(
            dateQueryParam: dateQueryParam,
            mapSurfaceBuilder: mapSurfaceBuilder,
          ),
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
