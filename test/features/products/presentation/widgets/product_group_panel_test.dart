import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/products/domain/product_group.dart';
import 'package:hs360/features/products/presentation/widgets/product_group_panel.dart';
import 'package:hs360/l10n/app_localizations.dart';

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SizedBox(width: 240, child: child)),
    );
  }

  final groups = [
    const ProductGroup(
      id: 'group-1',
      tenantId: 'tenant-1',
      nameAr: 'أجهزة',
      nameEn: 'Devices',
      isActive: true,
    ),
    const ProductGroup(
      id: 'group-2',
      tenantId: 'tenant-1',
      nameAr: 'زيوت',
      nameEn: 'Oils',
      isActive: true,
    ),
  ];

  testWidgets(
    'selecting group tiles does not trigger ListTile Material assertion',
    (tester) async {
      var selectedId = 'group-1';

      await tester.pumpWidget(
        wrap(
          ProductGroupPanel(
            groups: groups,
            selectedGroupId: selectedId,
            languageCode: 'en',
            canCreateGroup: false,
            canEditGroup: false,
            onGroupSelected: (id) => selectedId = id ?? '',
            onAddGroup: () {},
            onEditGroup: (_) {},
            onDeactivateGroup: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Devices'), findsOneWidget);

      await tester.tap(find.text('Oils'));
      await tester.pumpAndSettle();

      expect(find.text('Oils'), findsOneWidget);
    },
  );

  testWidgets('compact panel selects all groups without assertion', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        ProductGroupPanelCompact(
          groups: groups,
          selectedGroupId: null,
          languageCode: 'en',
          canCreateGroup: false,
          canEditGroup: false,
          onGroupSelected: (_) {},
          onAddGroup: () {},
          onEditGroup: (_) {},
          onDeactivateGroup: (_) {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = lookupAppLocalizations(const Locale('en'));
    await tester.tap(find.byType(ExpansionTile));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.productsAllGroups));
    await tester.pumpAndSettle();

    expect(find.text(l10n.productsAllGroups), findsOneWidget);
  });
}
