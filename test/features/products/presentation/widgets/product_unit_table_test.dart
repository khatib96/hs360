import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/products/domain/product_unit.dart';
import 'package:hs360/features/products/domain/product_unit_health_status.dart';
import 'package:hs360/features/products/domain/unit_status.dart';
import 'package:hs360/features/products/presentation/widgets/product_unit_table.dart';
import 'package:hs360/l10n/app_localizations.dart';

ProductUnit _unit({UnitStatus status = UnitStatus.availableNew}) {
  return ProductUnit(
    id: 'u1',
    tenantId: 't',
    productId: 'p',
    serialNumber: 'SN-1',
    status: status,
    healthStatus: ProductUnitHealthStatus.good,
    acquiredAt: DateTime(2026, 1, 1),
  );
}

void main() {
  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    );
  }

  testWidgets('hides purchase cost column when canViewCosts is false', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return ProductUnitTable(
              units: [_unit()],
              languageCode: 'en',
              canViewCosts: false,
              canEdit: false,
              l10n: l10n,
              onEdit: (unitId, patch) async => null,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Purchase cost'), findsNothing);
  });

  testWidgets('no edit icon on rented unit', (tester) async {
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) {
            final l10n = AppLocalizations.of(context)!;
            return ProductUnitTable(
              units: [_unit(status: UnitStatus.rented)],
              languageCode: 'en',
              canViewCosts: false,
              canEdit: true,
              l10n: l10n,
              onEdit: (unitId, patch) async => null,
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.edit_outlined), findsNothing);
  });
}
