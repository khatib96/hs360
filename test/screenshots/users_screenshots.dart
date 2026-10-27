// Users & Permissions visual evidence (Arabic RTL, desktop width).
// Run explicitly: flutter test test/screenshots/users_screenshots.dart
// Output: build/screenshots/users_*.png
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/theme/app_theme.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/auth/presentation/change_password_screen.dart';
import 'package:hs360/features/users/data/users_repository.dart';
import 'package:hs360/features/users/domain/permission_catalog.dart';
import 'package:hs360/features/users/presentation/user_detail_screen.dart';
import 'package:hs360/features/users/presentation/users_screen.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../features/users/users_test_support.dart';

final _rootKey = GlobalKey();

class _CatalogRepository extends FakeUsersRepository {
  _CatalogRepository({required super.accounts});

  @override
  Future<List<PermissionCatalogEntry>> loadPermissionCatalog() async => [
    for (final (index, (id, category, ar, sensitive)) in _catalog.indexed)
      PermissionCatalogEntry(
        id: id,
        category: category,
        labelAr: ar,
        labelEn: id,
        isSensitive: sensitive,
        sortOrder: index,
      ),
  ];
}

const _catalog = [
  ('dashboard.view', 'core', 'عرض لوحة التحكم', false),
  ('customers.view', 'sales', 'عرض العملاء', false),
  ('customers.create', 'sales', 'إنشاء العملاء', false),
  ('customers.view_ledger', 'sales', 'عرض كشف حساب العميل', true),
  ('contracts.view', 'sales', 'عرض العقود', false),
  ('contracts.field.snapshot_profit', 'sales', 'عرض الربح المتوقع للعقد', true),
  ('invoices.view_sales', 'finance', 'عرض فواتير المبيعات', false),
  ('invoices.cancel', 'finance', 'إلغاء الفواتير', true),
  ('vouchers.create_receipt', 'finance', 'إنشاء سندات القبض', false),
  ('products.view', 'inventory', 'عرض المنتجات', false),
  ('products.field.avg_cost', 'inventory', 'عرض متوسط التكلفة', true),
];

Widget _app(Widget home, UsersRepository repository) {
  const locale = Locale('ar');
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => TestAuth(testSession())),
      usersRepositoryProvider.overrideWithValue(repository),
    ],
    child: RepaintBoundary(
      key: _rootKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(locale: locale),
        locale: locale,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
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
  await tester.pumpAndSettle();
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

void main() {
  final accounts = [
    testAccount(
      id: 'tu-1',
      name: 'محمد المدير',
      accountType: 'manager',
      isSelf: true,
    ),
    testAccount(
      id: 'tu-2',
      name: 'أحمد المحاسب',
      permissionIds: {
        'customers.view',
        'invoices.view_sales',
        'vouchers.create_receipt',
      },
    ),
    testAccount(id: 'tu-3', name: 'سارة', mustChangePassword: true),
    testAccount(
      id: 'tu-4',
      name: 'خالد',
      isActive: false,
      permissionIds: {'products.view'},
    ),
  ];

  setUpAll(_loadFonts);

  Future<void> sized(WidgetTester tester) async {
    await tester.binding.setSurfaceSize(const Size(1440, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
  }

  testWidgets('users list', (tester) async {
    await sized(tester);
    await tester.pumpWidget(
      _app(const UsersScreen(), _CatalogRepository(accounts: accounts)),
    );
    await _capture(tester, 'users_list_desktop_ar_rtl');
  });

  testWidgets('user permissions editor', (tester) async {
    await sized(tester);
    await tester.pumpWidget(
      _app(
        const UserDetailScreen(tenantUserId: 'tu-2'),
        _CatalogRepository(accounts: accounts),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('permission-customers.view_ledger')));
    await _capture(tester, 'users_detail_editor_desktop_ar_rtl');
  });

  testWidgets('create user dialog', (tester) async {
    await sized(tester);
    await tester.pumpWidget(
      _app(const UsersScreen(), _CatalogRepository(accounts: accounts)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('users-add-command')));
    await _capture(tester, 'users_create_dialog_desktop_ar_rtl');
  });

  testWidgets('forced password change', (tester) async {
    await sized(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuth(
              testSession(isManager: false, mustChangePassword: true),
            ),
          ),
          usersRepositoryProvider.overrideWithValue(FakeUsersRepository()),
        ],
        child: RepaintBoundary(
          key: _rootKey,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(locale: const Locale('ar')),
            locale: const Locale('ar'),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const ChangePasswordScreen(),
          ),
        ),
      ),
    );
    await _capture(tester, 'users_forced_password_change_ar_rtl');
  });
}
