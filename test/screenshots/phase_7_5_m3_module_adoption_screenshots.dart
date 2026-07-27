// Phase 7.5 M3 module adoption visual evidence.
//
// Run:
// flutter test test/screenshots/phase_7_5_m3_module_adoption_screenshots.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/localization/locale_controller.dart';
import 'package:hs360/core/routing/app_routes.dart';
import 'package:hs360/core/theme/app_theme.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/l10n/app_localizations.dart';
import 'package:hs360/shared/widgets/app_filter_bar.dart';
import 'package:hs360/shared/widgets/app_page_header.dart';
import 'package:hs360/shared/widgets/app_shell.dart';
import 'package:hs360/shared/widgets/app_table_frame.dart';

final _captureKey = GlobalKey();

void main() {
  setUpAll(_loadFonts);

  for (final locale in const [Locale('ar'), Locale('en')]) {
    final localeTag = locale.languageCode == 'ar' ? 'ar_rtl' : 'en_ltr';
    testWidgets('M3 finance desktop $localeTag', (tester) async {
      await _pump(
        tester,
        locale: locale,
        size: const Size(1440, 1000),
        module: _EvidenceModule.finance,
      );
      await _capture(tester, 'm3_finance_module_desktop_$localeTag');
    });
    testWidgets('M3 inventory narrow $localeTag', (tester) async {
      await _pump(
        tester,
        locale: locale,
        size: const Size(390, 844),
        module: _EvidenceModule.inventory,
      );
      await _capture(tester, 'm3_inventory_module_narrow_$localeTag');
    });
  }
}

enum _EvidenceModule { finance, inventory }

Future<void> _pump(
  WidgetTester tester, {
  required Locale locale,
  required Size size,
  required _EvidenceModule module,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final session = AppSession(
    userId: 'manager-1',
    email: 'manager@hs360.local',
    tenantId: 'tenant-1',
    tenantUserId: 'tenant-user-1',
    accountType: 'manager',
    displayName: locale.languageCode == 'ar' ? 'مدير النظام' : 'System Manager',
    preferredLocale: locale.languageCode,
    permissions: AppPermissions(isManager: true, permissions: const {}),
  );

  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureKey,
      child: ProviderScope(
        overrides: [
          authControllerProvider.overrideWith(
            () => _TestAuthController(session),
          ),
          localeProvider.overrideWithValue(locale),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: locale,
          theme: AppTheme.light(locale: locale),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Directionality(
            textDirection: locale.languageCode == 'ar'
                ? TextDirection.rtl
                : TextDirection.ltr,
            child: _EvidenceShell(module: module),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  expect(tester.takeException(), isNull);
}

class _EvidenceShell extends StatelessWidget {
  const _EvidenceShell({required this.module});

  final _EvidenceModule module;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final finance = module == _EvidenceModule.finance;
    return AppShell(
      title: finance ? l10n.navInvoices : l10n.inventory,
      currentRoute: finance ? AppRoutes.invoices : AppRoutes.inventory,
      moduleActions: finance
          ? [
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: Text(_text(context, 'فاتورة جديدة', 'New invoice')),
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.payments_outlined),
                label: Text(_text(context, 'سند قبض', 'Receipt voucher')),
              ),
            ]
          : [
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.tune),
                label: Text(_text(context, 'تسوية مخزون', 'Stock adjustment')),
              ),
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.swap_horiz),
                label: Text(_text(context, 'تحويل مخزون', 'Stock transfer')),
              ),
            ],
      body: _EvidenceBody(finance: finance),
    );
  }
}

class _EvidenceBody extends StatelessWidget {
  const _EvidenceBody({required this.finance});

  final bool finance;

  @override
  Widget build(BuildContext context) {
    final rows = finance
        ? [
            (
              'INV-2026-0142',
              _text(context, 'شركة النور', 'Al Noor Co.'),
              '325.000',
            ),
            (
              'INV-2026-0141',
              _text(context, 'روائح الخليج', 'Gulf Aromas'),
              '180.500',
            ),
            (
              'INV-2026-0140',
              _text(context, 'فندق الواحة', 'Oasis Hotel'),
              '760.000',
            ),
          ]
        : [
            ('SKU-1008', _text(context, 'جهاز تعطير S2', 'S2 diffuser'), '24'),
            ('SKU-2040', _text(context, 'زيت العود', 'Oud oil'), '67'),
            ('SKU-3021', _text(context, 'عبوة 500 مل', '500 ml refill'), '15'),
          ];

    return Padding(
      padding: const EdgeInsetsDirectional.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppPageHeader(
            eyebrow: finance
                ? _text(context, 'المالية', 'Finance')
                : _text(context, 'المخزون', 'Inventory'),
            title: finance
                ? _text(context, 'الفواتير', 'Invoices')
                : _text(context, 'أرصدة المخزون', 'Inventory balances'),
            subtitle: _text(
              context,
              'الأوامر والتنقل وحالات العرض موحّدة داخل الوحدة.',
              'Commands, navigation, and states are unified inside the module.',
            ),
          ),
          const SizedBox(height: 16),
          AppFilterBar(
            compact: true,
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: _text(context, 'بحث وتصفية', 'Search and filter'),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: AppTableFrame(
              child: ListView.separated(
                itemCount: rows.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final row = rows[index];
                  return ListTile(
                    leading: Icon(
                      finance
                          ? Icons.receipt_long_outlined
                          : Icons.inventory_2_outlined,
                    ),
                    title: Text(row.$1),
                    subtitle: Text(row.$2),
                    trailing: Text(
                      row.$3,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String _text(BuildContext context, String ar, String en) =>
    Localizations.localeOf(context).languageCode == 'ar' ? ar : en;

class _TestAuthController extends AuthController {
  _TestAuthController(this.session);

  final AppSession session;

  @override
  FutureOr<AppSession?> build() => session;
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary =
      _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/screenshots')
      ..createSync(recursive: true);
    File(
      '${directory.path}/$name.png',
    ).writeAsBytesSync(bytes!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _loadFonts() async {
  for (final entry in const {
    'NotoSans': [
      'assets/fonts/noto/NotoSans-Regular.ttf',
      'assets/fonts/noto/NotoSans-Bold.ttf',
    ],
    'NotoSansArabic': [
      'assets/fonts/noto/NotoSansArabic-Regular.ttf',
      'assets/fonts/noto/NotoSansArabic-Bold.ttf',
    ],
    'MaterialIcons': ['assets/fonts/material/MaterialIcons-Regular.otf'],
  }.entries) {
    final loader = FontLoader(entry.key);
    for (final asset in entry.value) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
}
