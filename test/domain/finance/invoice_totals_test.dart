import 'package:flutter_test/flutter_test.dart';

import 'invoice_calculation_fixtures.dart';

void main() {
  group('calculateInvoiceTotals', () {
    for (final fixture in invoiceCalculationFixtures) {
      test('matches fixture ${fixture.name}', () {
        final totals = calculateFixtureTotals(fixture);
        expect(
          totals.toNormalizedMap(decimalPlaces: fixture.decimalPlaces),
          fixture.expectedTotals,
          reason: fixture.name,
        );
      });
    }
  });
}
