import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/dashboard/data/dashboard_repository.dart';
import 'package:hs360/features/dashboard/domain/activity_feed.dart';
import 'package:hs360/features/dashboard/domain/dashboard_summary.dart';
import 'package:hs360/features/dashboard/presentation/daily_activity_screen.dart';
import 'package:hs360/features/dashboard/presentation/dashboard_screen.dart';
import 'package:hs360/l10n/app_localizations.dart';

class _TestAuth extends AuthController {
  _TestAuth(this.session);
  final AppSession session;

  @override
  FutureOr<AppSession?> build() => session;
}

class _FakeDashboardRepository extends DashboardRepository {
  _FakeDashboardRepository({required this.summary, required this.activity})
    : super(null);

  final DashboardSummary summary;
  final ActivityFeedPage activity;
  int dashboardCalls = 0;
  int activityCalls = 0;

  @override
  Future<DashboardSummary> getDashboard(
    AppSession session, {
    DateTime? businessDate,
  }) async {
    dashboardCalls++;
    return summary;
  }

  @override
  Future<ActivityFeedPage> listDailyActivity(
    AppSession session, {
    DateTime? businessDate,
    int offset = 0,
    int limit = DashboardRepository.pageSize,
  }) async {
    activityCalls++;
    return activity;
  }
}

AppSession _session() => AppSession(
  userId: 'user-1',
  email: 'user@example.com',
  tenantId: 'tenant-1',
  tenantUserId: 'tenant-user-1',
  accountType: 'user',
  displayName: 'User',
  preferredLocale: 'en',
  permissions: AppPermissions(
    isManager: false,
    permissions: {
      'dashboard.view',
      'calendar.view',
      'contracts.view',
      'product_units.view',
      'vouchers.view',
      'invoices.view_sales',
    },
  ),
);

DashboardSummary _summary() => DashboardSummary(
  businessDate: DateTime(2026, 8, 5),
  timezoneName: 'Asia/Kuwait',
  currencyCode: 'KWD',
  todaySchedule: const DashboardScheduleSummary(
    visible: true,
    total: 8,
    completed: 3,
    remaining: 5,
  ),
  overdue: const DashboardOverdueSummary(visible: true, count: 2),
  contracts: const DashboardContractSummary(
    visible: true,
    active: 6,
    trials: 2,
    rentals: 4,
    assetConditionVisible: true,
    assetsRented: 4,
    assetsTrial: 2,
    assetsAttention: 1,
  ),
  financial: DashboardFinancialSummary(
    collectionsVisible: true,
    collections: 25.5,
    outstandingVisible: true,
    outstanding: 75,
    monthStart: DateTime(2026, 8),
  ),
);

ActivityFeedPage _activity() => ActivityFeedPage(
  businessDate: DateTime(2026, 8, 5),
  timezoneName: 'Asia/Kuwait',
  currencyCode: 'KWD',
  totalCount: 1,
  hasMore: false,
  items: [
    ActivityFeedItem(
      kind: 'invoice',
      entityId: 'invoice-1',
      occurredAt: DateTime(2026, 8, 5, 10),
      titleAr: 'فاتورة SI-1',
      titleEn: 'Invoice SI-1',
      identifier: 'sales',
      status: 'confirmed',
      amount: 25.5,
      sourceRoute: '/invoices/invoice-1?type=sales',
    ),
  ],
);

Widget _app({required Widget home, required DashboardRepository repository}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => _TestAuth(_session())),
      dashboardRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}

void main() {
  testWidgets('Dashboard v1 renders the four trusted priority slots', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(1280, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeDashboardRepository(
      summary: _summary(),
      activity: _activity(),
    );

    await tester.pumpWidget(
      _app(home: const DashboardScreen(), repository: repository),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('dashboard-schedule-card')), findsOneWidget);
    expect(find.byKey(const Key('dashboard-overdue-card')), findsOneWidget);
    expect(find.byKey(const Key('dashboard-contracts-card')), findsOneWidget);
    expect(find.byKey(const Key('dashboard-finance-card')), findsOneWidget);
    expect(find.text('8'), findsOneWidget);
    expect(find.textContaining('KWD'), findsNWidgets(2));
    expect(repository.dashboardCalls, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Daily Activity renders a dated, permission-shaped timeline', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final repository = _FakeDashboardRepository(
      summary: _summary(),
      activity: _activity(),
    );
    late final GoRouter router;
    router = GoRouter(
      initialLocation: '/daily-activity?date=2026-08-05',
      routes: [
        GoRoute(
          path: '/daily-activity',
          builder: (_, state) => DailyActivityScreen(
            dateQueryParam: state.uri.queryParameters['date'],
          ),
        ),
        GoRoute(
          path: '/invoices/:id',
          builder: (_, state) => Text('Invoice ${state.pathParameters['id']}'),
        ),
      ],
    );
    addTearDown(router.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(() => _TestAuth(_session())),
          dashboardRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Daily Activity'), findsWidgets);
    expect(find.text('Invoice SI-1'), findsOneWidget);
    expect(find.textContaining('25.5'), findsOneWidget);
    expect(find.byKey(const Key('daily-activity-date-picker')), findsOneWidget);
    expect(repository.activityCalls, 1);
    expect(tester.takeException(), isNull);
  });
}
