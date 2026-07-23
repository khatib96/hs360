import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/theme/app_theme.dart';
import 'package:hs360/shared/widgets/app_detail_surface.dart';
import 'package:hs360/shared/widgets/app_filter_bar.dart';
import 'package:hs360/shared/widgets/app_page_header.dart';
import 'package:hs360/shared/widgets/app_sensitive_action_dialog.dart';
import 'package:hs360/shared/widgets/app_state_view.dart';
import 'package:hs360/shared/widgets/app_status_badge.dart';
import 'package:hs360/shared/widgets/app_table_frame.dart';

void main() {
  group('Phase 7.5 M1 semantic theme', () {
    test('critical foreground/background pairs meet WCAG AA', () {
      expect(
        _contrast(AppColors.pureWhite, AppColors.actionGold),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(AppColors.pureWhite, AppColors.actionGoldHover),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(AppColors.charcoal, AppColors.brandGold),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(AppColors.success, AppColors.successContainer),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(AppColors.warning, AppColors.warningContainer),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(AppColors.error, AppColors.errorContainer),
        greaterThanOrEqualTo(4.5),
      );
      expect(
        _contrast(AppColors.info, AppColors.infoContainer),
        greaterThanOrEqualTo(4.5),
      );
    });

    test(
      'locale selects the bundled Noto family without a font replacement',
      () {
        final en = AppTheme.light(locale: const Locale('en'));
        final ar = AppTheme.light(locale: const Locale('ar'));

        expect(en.textTheme.bodyMedium?.fontFamily, 'NotoSans');
        expect(en.textTheme.bodyMedium?.fontFamilyFallback, ['NotoSansArabic']);
        expect(ar.textTheme.bodyMedium?.fontFamily, 'NotoSansArabic');
        expect(ar.textTheme.bodyMedium?.fontFamilyFallback, ['NotoSans']);
        expect(en.brightness, Brightness.light);
        expect(ar.brightness, Brightness.light);
      },
    );

    test('button states use action, hover, and disabled roles', () {
      final style = AppTheme.light().filledButtonTheme.style!;
      expect(
        style.backgroundColor!.resolve(<WidgetState>{}),
        AppColors.actionGold,
      );
      expect(
        style.backgroundColor!.resolve({WidgetState.hovered}),
        AppColors.actionGoldHover,
      );
      expect(
        style.backgroundColor!.resolve({WidgetState.disabled}),
        AppColors.neutral100,
      );
    });
  });

  for (final locale in const [Locale('en'), Locale('ar')]) {
    final isArabic = locale.languageCode == 'ar';
    testWidgets(
      'shared surfaces support ${isArabic ? 'RTL' : 'LTR'} at 200% text',
      (tester) async {
        await _pump(
          tester,
          locale: locale,
          textScale: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppPageHeader(
                  eyebrow: isArabic ? 'المالية' : 'Finance',
                  title: isArabic
                      ? 'الفواتير والمستندات'
                      : 'Invoices & documents',
                  subtitle: isArabic
                      ? 'عنوان طويل لاختبار التفاف النص بصورة آمنة'
                      : 'A long subtitle that must wrap without page overflow',
                  actions: [
                    FilledButton(
                      onPressed: () {},
                      child: Text(isArabic ? 'إنشاء جديد' : 'Create new'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AppFilterBar(
                  trailing: OutlinedButton(
                    key: const Key('clear-button'),
                    onPressed: () {},
                    child: Text(isArabic ? 'مسح الفلاتر' : 'Clear filters'),
                  ),
                  child: TextField(
                    key: const Key('search-field'),
                    decoration: InputDecoration(
                      labelText: isArabic ? 'بحث' : 'Search',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    AppStatusBadge(
                      label: isArabic ? 'نشط' : 'Active',
                      tone: AppStatusTone.success,
                    ),
                    AppStatusBadge(
                      label: isArabic ? 'قيد الانتظار' : 'Pending',
                      tone: AppStatusTone.warning,
                    ),
                    AppStatusBadge(
                      label: isArabic ? 'ملغي' : 'Cancelled',
                      tone: AppStatusTone.error,
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(
                  height: 300,
                  child: AppTableFrame(
                    header: Text(isArabic ? 'النتائج' : 'Results'),
                    child: AppStateView.empty(
                      title: isArabic ? 'لا توجد نتائج' : 'No results',
                      message: isArabic
                          ? 'غيّر معايير البحث ثم حاول مرة أخرى.'
                          : 'Change the filters and try again.',
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                AppDetailSection(
                  title: isArabic ? 'التفاصيل' : 'Details',
                  child: AppInfoRow(
                    label: isArabic
                        ? 'حالة المستند الطويلة'
                        : 'Document status',
                    value: Text(
                      isArabic
                          ? 'قيمة طويلة تلتف على الشاشات الضيقة'
                          : 'A long value that wraps on narrow screens',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        expect(find.byType(AppFilterBar), findsOneWidget);
        expect(find.byType(AppTableFrame), findsOneWidget);
        expect(find.byType(AppDetailSection), findsOneWidget);
        expect(find.byType(AppStatusBadge), findsNWidgets(3));
      },
    );
  }

  testWidgets('filter controls follow keyboard reading order', (tester) async {
    await _pump(
      tester,
      child: AppFilterBar(
        trailing: OutlinedButton(
          key: const Key('clear-button'),
          onPressed: () {},
          child: const Text('Clear'),
        ),
        child: const TextField(key: Key('search-field')),
      ),
    );

    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(
      Focus.of(tester.element(find.byKey(const Key('search-field')))).hasFocus,
      isTrue,
    );
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    expect(
      Focus.of(tester.element(find.byKey(const Key('clear-button')))).hasFocus,
      isTrue,
    );
  });

  testWidgets('sensitive dialog exposes destructive action safely', (
    tester,
  ) async {
    var confirmed = false;
    await _pump(
      tester,
      child: Builder(
        builder: (context) => FilledButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (_) => AppSensitiveActionDialog(
              title: 'Cancel document?',
              content: const Text(
                'This action records a reason and audit row.',
              ),
              cancelLabel: 'Keep',
              confirmLabel: 'Cancel document',
              onCancel: () => Navigator.pop(context),
              onConfirm: () {
                confirmed = true;
                Navigator.pop(context);
              },
            ),
          ),
          child: const Text('Open'),
        ),
      ),
    );

    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Cancel document?'), findsOneWidget);

    final destructive = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Cancel document'),
    );
    expect(
      destructive.style?.backgroundColor?.resolve(<WidgetState>{}),
      AppColors.error,
    );

    await tester.tap(find.text('Cancel document'));
    await tester.pumpAndSettle();
    expect(confirmed, isTrue);
  });
}

Future<void> _pump(
  WidgetTester tester, {
  required Widget child,
  Locale locale = const Locale('en'),
  double textScale = 1,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(locale: locale),
      home: Directionality(
        textDirection: locale.languageCode == 'ar'
            ? TextDirection.rtl
            : TextDirection.ltr,
        child: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, 844),
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(body: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

double _contrast(Color first, Color second) {
  final lighter = first.computeLuminance() > second.computeLuminance()
      ? first
      : second;
  final darker = identical(lighter, first) ? second : first;
  return (lighter.computeLuminance() + 0.05) /
      (darker.computeLuminance() + 0.05);
}
