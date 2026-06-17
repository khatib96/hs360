import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hs360/domain/finance/invoice_line_math.dart';
import 'package:hs360/domain/finance/tax_class.dart';

import 'invoice_calculation_fixtures.dart';

void main() {
  group('calculateInvoiceLineSnapshot', () {
    for (final fixture in invoiceCalculationFixtures) {
      test('matches fixture ${fixture.name}', () {
        final totals = calculateFixtureTotals(fixture);
        expect(totals.lines.length, fixture.expectedLineMaps.length);

        for (var i = 0; i < totals.lines.length; i++) {
          expect(
            totals.lines[i].toNormalizedMap(
              decimalPlaces: fixture.decimalPlaces,
            ),
            fixture.expectedLineMaps[i],
            reason: '${fixture.name} line $i',
          );
        }
      });
    }

    test('rejects qty <= 0', () {
      expect(
        () => calculateInvoiceLineSnapshot(
          input: InvoiceLineInput(
            productId: productA,
            qty: Decimal.zero,
            unitPrice: Decimal.parse('1'),
            discountPct: Decimal.zero,
            taxClass: ProductTaxClass.taxable,
          ),
          decimalPlaces: 3,
          taxEnabled: true,
          effectiveTaxRate: Decimal.parse('5'),
        ),
        throwsArgumentError,
      );
    });

    test('rejects decimal places above 3', () {
      expect(
        () => calculateInvoiceLineSnapshot(
          input: InvoiceLineInput(
            productId: productA,
            qty: Decimal.one,
            unitPrice: Decimal.one,
            discountPct: Decimal.zero,
            taxClass: ProductTaxClass.taxable,
          ),
          decimalPlaces: 4,
          taxEnabled: true,
        ),
        throwsArgumentError,
      );
    });
  });
}
