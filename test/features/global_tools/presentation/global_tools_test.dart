import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/global_tools/data/global_tools_repository.dart';
import 'package:hs360/features/global_tools/domain/app_notification.dart';
import 'package:hs360/features/global_tools/domain/global_search_result.dart';
import 'package:hs360/features/global_tools/presentation/global_search_palette.dart';
import 'package:hs360/l10n/app_localizations.dart';
import 'package:hs360/shared/widgets/app_top_bar.dart';

void main() {
  AppSession session(Set<String> permissions) => AppSession(
    userId: 'user-1',
    email: 'user@example.com',
    tenantId: 'tenant-1',
    tenantUserId: 'tenant-user-1',
    accountType: 'user',
    displayName: 'User',
    preferredLocale: 'en',
    permissions: AppPermissions(isManager: false, permissions: permissions),
  );

  Widget localized({
    required Widget child,
    required GlobalToolsRepository repository,
    Locale locale = const Locale('en'),
  }) {
    return ProviderScope(
      overrides: [globalToolsRepositoryProvider.overrideWithValue(repository)],
      child: MaterialApp(
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('search waits for two characters and groups safe results', (
    tester,
  ) async {
    final repository = _FakeGlobalToolsRepository(
      searchResults: const [
        GlobalSearchResult(
          category: 'customers',
          entityId: 'customer-1',
          titleAr: 'عميل',
          titleEn: 'Customer',
          identifier: 'CUS-1',
          route: '/customers/customer-1',
        ),
        GlobalSearchResult(
          category: 'products',
          entityId: 'product-1',
          titleAr: 'منتج',
          titleEn: 'Product',
          identifier: 'SKU-1',
          route: '/products/product-1',
        ),
      ],
    );

    await tester.pumpWidget(
      localized(
        repository: repository,
        child: GlobalSearchPalette(session: session({'customers.view'})),
      ),
    );

    await tester.enterText(find.byKey(const Key('global-search-field')), 'a');
    await tester.pump(const Duration(milliseconds: 300));
    expect(repository.searchCalls, 0);

    await tester.enterText(find.byKey(const Key('global-search-field')), 'ab');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();

    expect(repository.searchCalls, 1);
    expect(find.text('Customers'), findsOneWidget);
    expect(find.text('Products'), findsOneWidget);
    expect(find.text('CUS-1'), findsOneWidget);
    expect(find.text('SKU-1'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump();
    final selected = tester.widget<ListTile>(
      find.byKey(const Key('global-search-result-product-1')),
    );
    expect(selected.selected, isTrue);
  });

  testWidgets('pointer selection opens the canonical deep link', (
    tester,
  ) async {
    final appSession = session({'products.view'});
    final repository = _FakeGlobalToolsRepository(
      searchResults: const [
        GlobalSearchResult(
          category: 'products',
          entityId: 'product-1',
          titleAr: 'منتج',
          titleEn: 'Product',
          identifier: 'SKU-1',
          route: '/products/product-1',
        ),
      ],
    );
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, _) => Scaffold(
            body: FilledButton(
              onPressed: () => showGlobalSearchPalette(
                context: context,
                session: appSession,
              ),
              child: const Text('Open search'),
            ),
          ),
        ),
        GoRoute(
          path: '/products/:id',
          builder: (_, state) => Text('Opened ${state.pathParameters['id']}'),
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          globalToolsRepositoryProvider.overrideWithValue(repository),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.tap(find.text('Open search'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('global-search-field')), 'sku');
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
    await tester.tap(find.byKey(const Key('global-search-result-product-1')));
    await tester.pumpAndSettle();

    expect(find.text('Opened product-1'), findsOneWidget);
  });

  testWidgets('quick create lists only explicitly permitted actions', (
    tester,
  ) async {
    final appSession = session({'customers.create'});
    await tester.pumpWidget(
      localized(
        repository: _FakeGlobalToolsRepository(),
        child: AppTopBar(title: 'Test', module: null, session: appSession),
      ),
    );

    await tester.tap(find.byKey(const Key('shell-quick-create-anchor')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('quick-create-customer')), findsOneWidget);
    expect(find.byKey(const Key('quick-create-supplier')), findsNothing);
    expect(find.byKey(const Key('quick-create-product')), findsNothing);
  });

  testWidgets('notification panel shows own page and persists read toggle', (
    tester,
  ) async {
    final repository = _FakeGlobalToolsRepository(
      notificationPage: AppNotificationPage(
        items: [
          AppNotification(
            id: 'notice-1',
            subject: 'Visit',
            bodyAr: 'زيارة',
            bodyEn: 'Visit reminder',
            isRead: false,
            createdAt: DateTime.utc(2026, 7, 27, 8),
          ),
        ],
        unreadCount: 1,
        hasMore: false,
      ),
    );
    final appSession = session({'notifications.view'});

    await tester.pumpWidget(
      localized(
        repository: repository,
        child: AppTopBar(title: 'Test', module: null, session: appSession),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const Key('shell-notifications-anchor')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('notification-notice-1')), findsOneWidget);
    expect(find.textContaining('Visit reminder'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mark as read'));
    await tester.pumpAndSettle();

    expect(repository.lastReadId, 'notice-1');
    expect(repository.lastReadValue, isTrue);
  });

  testWidgets('compact global menu remains actionable', (tester) async {
    final appSession = session({'customers.view'});
    await tester.pumpWidget(
      localized(
        repository: _FakeGlobalToolsRepository(),
        locale: const Locale('ar'),
        child: MediaQuery(
          data: const MediaQueryData(size: Size(500, 700)),
          child: AppTopBar(title: 'Test', module: null, session: appSession),
        ),
      ),
    );

    await tester.tap(find.byKey(const Key('shell-global-actions-menu')));
    await tester.pumpAndSettle();
    final searchLabel = find.text('البحث العام');
    expect(Directionality.of(tester.element(searchLabel)), TextDirection.rtl);
    await tester.tap(searchLabel);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('global-search-field')), findsOneWidget);
  });
}

class _FakeGlobalToolsRepository extends GlobalToolsRepository {
  _FakeGlobalToolsRepository({
    this.searchResults = const [],
    this.notificationPage = const AppNotificationPage.empty(),
  }) : super(null);

  final List<GlobalSearchResult> searchResults;
  final AppNotificationPage notificationPage;
  int searchCalls = 0;
  String? lastReadId;
  bool? lastReadValue;

  @override
  Future<List<GlobalSearchResult>> search(
    AppSession session,
    String query, {
    int limitPerGroup = 5,
  }) async {
    searchCalls++;
    return searchResults;
  }

  @override
  Future<AppNotificationPage> listNotifications(
    AppSession session, {
    int limit = 30,
    DateTime? before,
  }) async {
    return notificationPage;
  }

  @override
  Future<bool> setNotificationRead(
    AppSession session,
    String notificationId, {
    required bool isRead,
  }) async {
    lastReadId = notificationId;
    lastReadValue = isRead;
    return true;
  }
}
