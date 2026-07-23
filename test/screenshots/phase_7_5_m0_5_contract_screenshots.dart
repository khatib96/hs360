// Phase 7.5 M0.5 pre-shell contract-detail baseline.
//
// Renders the production ContractDetailScreen with the accepted fake
// repository fixture in AR/EN at desktop and narrow widths. PNGs are written
// to build/screenshots/ for the M0.5 evidence copy step.
//
// Run:
// flutter test test/screenshots/phase_7_5_m0_5_contract_screenshots.dart
import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/theme/app_theme.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/contracts/data/contract_repository.dart';
import 'package:hs360/features/contracts/presentation/contract_detail_screen.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../features/contracts/fake_contract_repository.dart';

final _captureKey = GlobalKey();

void main() {
  setUpAll(_loadFonts);

  for (final locale in const [Locale('ar'), Locale('en')]) {
    final localeTag = locale.languageCode == 'ar' ? 'ar_rtl' : 'en_ltr';

    testWidgets('contract detail desktop $localeTag', (tester) async {
      await _pumpContract(
        tester,
        locale: locale,
        size: const Size(1280, 900),
        expectKnownNarrowOverflow: false,
      );
      await _capture(tester, 'm0_5_contract_detail_desktop_$localeTag');
    });

    testWidgets('contract detail narrow $localeTag', (tester) async {
      await _pumpContract(
        tester,
        locale: locale,
        size: const Size(390, 844),
        expectKnownNarrowOverflow: true,
      );
      await _capture(tester, 'm0_5_contract_detail_narrow_$localeTag');
    });
  }
}

Future<void> _pumpContract(
  WidgetTester tester, {
  required Locale locale,
  required Size size,
  required bool expectKnownNarrowOverflow,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final session = AppSession(
    userId: 'm0-5-user',
    email: 'm0.5@example.test',
    tenantId: 'm0-5-tenant',
    tenantUserId: 'm0-5-tenant-user',
    accountType: 'manager',
    displayName: locale.languageCode == 'ar' ? 'مدير النظام' : 'System Manager',
    preferredLocale: locale.languageCode,
    permissions: AppPermissions.manager,
  );

  final theme = AppTheme.light();
  final expectedOverflows = <FlutterErrorDetails>[];
  final previousErrorHandler = FlutterError.onError;
  if (expectKnownNarrowOverflow) {
    FlutterError.onError = (details) {
      if (details.exceptionAsString().contains('A RenderFlex overflowed')) {
        expectedOverflows.add(details);
        return;
      }
      previousErrorHandler?.call(details);
    };
  }

  try {
    await tester.pumpWidget(
      RepaintBoundary(
        key: _captureKey,
        child: ProviderScope(
          overrides: [
            authControllerProvider.overrideWith(
              () => _BaselineAuthController(session),
            ),
            contractRepositoryProvider.overrideWith(
              (ref) => FakeContractRepository(
                detailById: {
                  'contract-m0-5': sampleContractDetail(
                    id: 'contract-m0-5',
                    billingDay: 5,
                    refillDay: 10,
                  ),
                },
              ),
            ),
          ],
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            locale: locale,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: theme,
            home: const ContractDetailScreen(contractId: 'contract-m0-5'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  } finally {
    FlutterError.onError = previousErrorHandler;
  }

  if (expectKnownNarrowOverflow) {
    // M0.5 baseline debt: two overview rows overflow at 390 px in both
    // locales. Keep the screenshot reproducible until M1/M3 corrects it.
    expect(expectedOverflows, hasLength(2));
    expect(tester.takeException(), isNull);
  } else {
    expect(tester.takeException(), isNull);
  }
}

Future<void> _capture(WidgetTester tester, String name) async {
  final boundary =
      _captureKey.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final directory = Directory('build/screenshots')
      ..createSync(recursive: true);
    File(
      '${directory.path}/$name.png',
    ).writeAsBytesSync(data!.buffer.asUint8List());
    image.dispose();
  });
}

Future<void> _loadFonts() async {
  const fonts = {
    'NotoSans': [
      'assets/fonts/noto/NotoSans-Regular.ttf',
      'assets/fonts/noto/NotoSans-Bold.ttf',
    ],
    'NotoSansArabic': [
      'assets/fonts/noto/NotoSansArabic-Regular.ttf',
      'assets/fonts/noto/NotoSansArabic-Bold.ttf',
    ],
  };
  for (final family in fonts.entries) {
    final loader = FontLoader(family.key);
    for (final asset in family.value) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
}

class _BaselineAuthController extends AuthController {
  _BaselineAuthController(this.session);

  final AppSession session;

  @override
  FutureOr<AppSession?> build() => session;
}
