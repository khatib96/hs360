// Phase 7.5 M2 shell visual evidence.
//
// Run:
// flutter test test/screenshots/phase_7_5_m2_shell_screenshots.dart
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
import 'package:hs360/shared/widgets/app_page_header.dart';
import 'package:hs360/shared/widgets/app_shell.dart';
import 'package:hs360/shared/widgets/app_shell_controller.dart';
import 'package:hs360/shared/widgets/app_state_view.dart';
import 'package:hs360/shared/widgets/app_status_badge.dart';

final _captureKey = GlobalKey();

void main() {
  setUpAll(_loadFonts);

  for (final locale in const [Locale('ar'), Locale('en')]) {
    final localeTag = locale.languageCode == 'ar' ? 'ar_rtl' : 'en_ltr';
    testWidgets('M2 expanded desktop $localeTag', (tester) async {
      await _pump(tester, locale: locale, size: const Size(1440, 1000));
      await _capture(tester, 'm2_shell_expanded_desktop_$localeTag');
    });
    testWidgets('M2 collapsed desktop $localeTag', (tester) async {
      await _pump(
        tester,
        locale: locale,
        size: const Size(1280, 900),
        collapsed: true,
      );
      await _capture(tester, 'm2_shell_collapsed_desktop_$localeTag');
    });
    testWidgets('M2 narrow drawer $localeTag', (tester) async {
      await _pump(
        tester,
        locale: locale,
        size: const Size(390, 844),
        openDrawer: true,
      );
      await _capture(tester, 'm2_shell_narrow_drawer_$localeTag');
    });
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required Locale locale,
  required Size size,
  bool collapsed = false,
  bool openDrawer = false,
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
          appSidebarCollapsedProvider.overrideWith((ref) => collapsed),
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
            child: const _EvidenceShell(),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  if (openDrawer) {
    await tester.tap(find.byIcon(Icons.menu));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 350));
  }
  expect(tester.takeException(), isNull);
}

class _EvidenceShell extends StatelessWidget {
  const _EvidenceShell();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppShell(
      title: l10n.navInvoices,
      currentRoute: AppRoutes.invoices,
      body: const _EvidenceBody(),
    );
  }
}

class _EvidenceBody extends StatelessWidget {
  const _EvidenceBody();

  @override
  Widget build(BuildContext context) {
    final ar = Localizations.localeOf(context).languageCode == 'ar';
    String text(String arText, String enText) => ar ? arText : enText;
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppPageHeader(
            eyebrow: text('المالية', 'Finance'),
            title: text('مساحة عمل الفواتير', 'Invoice workspace'),
            subtitle: text(
              'هيكل واضح للوحدات مع تبويبات مصفّاة حسب الصلاحيات.',
              'A module shell with permission-shaped contextual navigation.',
            ),
            actions: [
              FilledButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.add),
                label: Text(text('فاتورة جديدة', 'New invoice')),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              AppStatusBadge(
                label: text('نشط', 'Active'),
                tone: AppStatusTone.success,
              ),
              AppStatusBadge(
                label: text('بانتظار المراجعة', 'Pending review'),
                tone: AppStatusTone.warning,
              ),
            ],
          ),
          const SizedBox(height: 20),
          SizedBox(
            height: 360,
            child: Card(
              child: AppStateView.empty(
                title: text('لا توجد فواتير', 'No invoices'),
                message: text(
                  'ستظهر المستندات المصرّح بها هنا.',
                  'Authorized documents will appear here.',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

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
