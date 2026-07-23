// Phase 7.5 M1 shared-foundation visual evidence.
//
// Run:
// flutter test test/screenshots/phase_7_5_m1_foundation_screenshots.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/tenant_currency_format.dart';
import 'package:hs360/core/localization/locale_controller.dart';
import 'package:hs360/core/theme/app_theme.dart';
import 'package:hs360/features/finance_shared/presentation/money_display.dart';
import 'package:hs360/features/finance_shared/presentation/tenant_currency_provider.dart';
import 'package:hs360/shared/widgets/app_detail_surface.dart';
import 'package:hs360/shared/widgets/app_filter_bar.dart';
import 'package:hs360/shared/widgets/app_page_header.dart';
import 'package:hs360/shared/widgets/app_state_view.dart';
import 'package:hs360/shared/widgets/app_status_badge.dart';
import 'package:hs360/shared/widgets/app_table_frame.dart';

final _captureKey = GlobalKey();

void main() {
  setUpAll(_loadFonts);

  for (final locale in const [Locale('ar'), Locale('en')]) {
    final localeTag = locale.languageCode == 'ar' ? 'ar_rtl' : 'en_ltr';
    testWidgets('M1 foundation desktop $localeTag', (tester) async {
      await _pump(tester, locale: locale, size: const Size(1280, 900));
      await _capture(tester, 'm1_foundation_desktop_$localeTag');
    });
    testWidgets('M1 foundation narrow $localeTag', (tester) async {
      await _pump(tester, locale: locale, size: const Size(390, 844));
      await _capture(tester, 'm1_foundation_narrow_$localeTag');
    });
  }
}

Future<void> _pump(
  WidgetTester tester, {
  required Locale locale,
  required Size size,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final ar = locale.languageCode == 'ar';
  await tester.pumpWidget(
    RepaintBoundary(
      key: _captureKey,
      child: ProviderScope(
        overrides: [
          localeProvider.overrideWithValue(locale),
          tenantCurrencyFormatProvider.overrideWith(
            (ref) async => TenantCurrencyFormat.defaults(),
          ),
        ],
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          locale: locale,
          theme: AppTheme.light(locale: locale),
          home: Directionality(
            textDirection: ar ? TextDirection.rtl : TextDirection.ltr,
            child: Scaffold(body: _FoundationGallery(arabic: ar)),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

class _FoundationGallery extends StatelessWidget {
  const _FoundationGallery({required this.arabic});

  final bool arabic;

  @override
  Widget build(BuildContext context) {
    String text(String ar, String en) => arabic ? ar : en;

    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPageHeader(
                eyebrow: text('نظام HS360', 'HS360 system'),
                title: text('أساس الواجهة المشتركة', 'Shared UI foundation'),
                subtitle: text(
                  'دفء إداري هادئ مع كثافة عملية للمالية والمخزون',
                  'Executive warmth with operational Finance and Inventory density',
                ),
                actions: [
                  OutlinedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.download_outlined),
                    label: Text(text('تصدير', 'Export')),
                  ),
                  FilledButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add),
                    label: Text(text('إنشاء جديد', 'Create new')),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              AppFilterBar(
                compact: true,
                trailing: TextButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.filter_alt_off_outlined),
                  label: Text(text('مسح', 'Clear')),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    SizedBox(
                      width: 280,
                      child: TextField(
                        decoration: InputDecoration(
                          labelText: text('بحث موحّد', 'Shared search'),
                          prefixIcon: const Icon(Icons.search),
                        ),
                      ),
                    ),
                    DropdownMenu<String>(
                      width: 210,
                      label: Text(text('الحالة', 'Status')),
                      initialSelection: 'all',
                      dropdownMenuEntries: [
                        DropdownMenuEntry(
                          value: 'all',
                          label: text('كل الحالات', 'All statuses'),
                        ),
                      ],
                    ),
                  ],
                ),
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
                    label: text('تجريبي', 'Trial'),
                    tone: AppStatusTone.brand,
                  ),
                  AppStatusBadge(
                    label: text('قيد الانتظار', 'Pending'),
                    tone: AppStatusTone.warning,
                  ),
                  AppStatusBadge(
                    label: text('ملغي', 'Cancelled'),
                    tone: AppStatusTone.error,
                  ),
                  AppStatusBadge(
                    label: text('معلومة', 'Information'),
                    tone: AppStatusTone.info,
                  ),
                ],
              ),
              const SizedBox(height: 20),
              LayoutBuilder(
                builder: (context, constraints) {
                  final detail = AppDetailSection(
                    title: text('تفاصيل تمثيلية', 'Representative details'),
                    child: Column(
                      children: [
                        AppInfoRow(
                          label: text('العميل', 'Customer'),
                          value: Text(
                            text('شركة العطور الحديثة', 'Modern Fragrance Co.'),
                          ),
                        ),
                        AppInfoRow(
                          label: text('القيمة الشهرية', 'Monthly value'),
                          value: MoneyDisplay(
                            amount: Decimal.parse('1250.500'),
                          ),
                        ),
                      ],
                    ),
                  );
                  final state = SizedBox(
                    height: 230,
                    child: AppTableFrame(
                      header: Text(
                        text('قائمة تمثيلية', 'Representative list'),
                      ),
                      child: AppStateView.empty(
                        title: text('لا توجد نتائج', 'No results'),
                        message: text(
                          'غيّر معايير البحث ثم حاول مجدداً.',
                          'Change the filters and try again.',
                        ),
                      ),
                    ),
                  );
                  if (constraints.maxWidth < 760) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [detail, const SizedBox(height: 16), state],
                    );
                  }
                  return Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: detail),
                      const SizedBox(width: 16),
                      Expanded(child: state),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
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
    'MaterialIcons': ['assets/fonts/material/MaterialIcons-Regular.otf'],
  };
  for (final family in fonts.entries) {
    final loader = FontLoader(family.key);
    for (final asset in family.value) {
      loader.addFont(rootBundle.load(asset));
    }
    await loader.load();
  }
}
