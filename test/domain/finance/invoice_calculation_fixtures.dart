import 'package:decimal/decimal.dart';

import 'package:hs360/domain/finance/invoice_line_math.dart';
import 'package:hs360/domain/finance/invoice_totals.dart';
import 'package:hs360/domain/finance/tax_class.dart';

class InvoiceCalculationFixture {
  const InvoiceCalculationFixture({
    required this.name,
    required this.decimalPlaces,
    required this.taxEnabled,
    this.effectiveTaxRateId = 'rate-1',
    this.effectiveTaxRate = '5',
    required this.lines,
    required this.expectedLineMaps,
    required this.expectedTotals,
  });

  final String name;
  final int decimalPlaces;
  final bool taxEnabled;
  final String? effectiveTaxRateId;
  final String effectiveTaxRate;
  final List<InvoiceLineInput> lines;
  final List<Map<String, String>> expectedLineMaps;
  final Map<String, String> expectedTotals;
}

const productA = '00000000-0000-0000-0000-000000000901';

final invoiceCalculationFixtures = <InvoiceCalculationFixture>[
  InvoiceCalculationFixture(
    name: 'tax_disabled',
    decimalPlaces: 3,
    taxEnabled: false,
    lines: [
      InvoiceLineInput(
        productId: productA,
        qty: Decimal.parse('2'),
        unitPrice: Decimal.parse('10.000'),
        discountPct: Decimal.zero,
        taxClass: ProductTaxClass.taxable,
      ),
    ],
    expectedLineMaps: const [
      {
        'gross_amount': '20.000',
        'discount_amount': '0.000',
        'before_tax_amount': '20.000',
        'tax_rate': '0',
        'taxable_amount': '0.000',
        'tax_amount': '0.000',
        'after_tax_amount': '20.000',
        'line_total': '20.000',
      },
    ],
    expectedTotals: const {
      'subtotal': '20.000',
      'discount_amount': '0.000',
      'tax_amount': '0.000',
      'total': '20.000',
    },
  ),
  InvoiceCalculationFixture(
    name: 'taxable_single_line',
    decimalPlaces: 3,
    taxEnabled: true,
    effectiveTaxRate: '5',
    lines: [
      InvoiceLineInput(
        productId: productA,
        qty: Decimal.parse('2'),
        unitPrice: Decimal.parse('10.000'),
        discountPct: Decimal.zero,
        taxClass: ProductTaxClass.taxable,
      ),
    ],
    expectedLineMaps: const [
      {
        'gross_amount': '20.000',
        'discount_amount': '0.000',
        'before_tax_amount': '20.000',
        'tax_rate': '5',
        'taxable_amount': '20.000',
        'tax_amount': '1.000',
        'after_tax_amount': '21.000',
        'line_total': '21.000',
      },
    ],
    expectedTotals: const {
      'subtotal': '20.000',
      'discount_amount': '0.000',
      'tax_amount': '1.000',
      'total': '21.000',
    },
  ),
  InvoiceCalculationFixture(
    name: 'zero_rated',
    decimalPlaces: 3,
    taxEnabled: true,
    lines: [
      InvoiceLineInput(
        productId: productA,
        qty: Decimal.parse('1'),
        unitPrice: Decimal.parse('15.000'),
        discountPct: Decimal.zero,
        taxClass: ProductTaxClass.zeroRated,
      ),
    ],
    expectedLineMaps: const [
      {
        'gross_amount': '15.000',
        'discount_amount': '0.000',
        'before_tax_amount': '15.000',
        'tax_rate': '0',
        'taxable_amount': '15.000',
        'tax_amount': '0.000',
        'after_tax_amount': '15.000',
        'line_total': '15.000',
      },
    ],
    expectedTotals: const {
      'subtotal': '15.000',
      'discount_amount': '0.000',
      'tax_amount': '0.000',
      'total': '15.000',
    },
  ),
  InvoiceCalculationFixture(
    name: 'exempt',
    decimalPlaces: 3,
    taxEnabled: true,
    lines: [
      InvoiceLineInput(
        productId: productA,
        qty: Decimal.parse('1'),
        unitPrice: Decimal.parse('12.000'),
        discountPct: Decimal.zero,
        taxClass: ProductTaxClass.exempt,
      ),
    ],
    expectedLineMaps: const [
      {
        'gross_amount': '12.000',
        'discount_amount': '0.000',
        'before_tax_amount': '12.000',
        'tax_rate': '0',
        'taxable_amount': '0.000',
        'tax_amount': '0.000',
        'after_tax_amount': '12.000',
        'line_total': '12.000',
      },
    ],
    expectedTotals: const {
      'subtotal': '12.000',
      'discount_amount': '0.000',
      'tax_amount': '0.000',
      'total': '12.000',
    },
  ),
  InvoiceCalculationFixture(
    name: 'non_taxable',
    decimalPlaces: 3,
    taxEnabled: true,
    lines: [
      InvoiceLineInput(
        productId: productA,
        qty: Decimal.parse('1'),
        unitPrice: Decimal.parse('8.000'),
        discountPct: Decimal.zero,
        taxClass: ProductTaxClass.nonTaxable,
      ),
    ],
    expectedLineMaps: const [
      {
        'gross_amount': '8.000',
        'discount_amount': '0.000',
        'before_tax_amount': '8.000',
        'tax_rate': '0',
        'taxable_amount': '0.000',
        'tax_amount': '0.000',
        'after_tax_amount': '8.000',
        'line_total': '8.000',
      },
    ],
    expectedTotals: const {
      'subtotal': '8.000',
      'discount_amount': '0.000',
      'tax_amount': '0.000',
      'total': '8.000',
    },
  ),
  InvoiceCalculationFixture(
    name: 'discount_before_tax',
    decimalPlaces: 3,
    taxEnabled: true,
    effectiveTaxRate: '5',
    lines: [
      InvoiceLineInput(
        productId: productA,
        qty: Decimal.parse('1'),
        unitPrice: Decimal.parse('100.000'),
        discountPct: Decimal.parse('10'),
        taxClass: ProductTaxClass.taxable,
      ),
    ],
    expectedLineMaps: const [
      {
        'gross_amount': '100.000',
        'discount_amount': '10.000',
        'before_tax_amount': '90.000',
        'tax_rate': '5',
        'taxable_amount': '90.000',
        'tax_amount': '4.500',
        'after_tax_amount': '94.500',
        'line_total': '94.500',
      },
    ],
    expectedTotals: const {
      'subtotal': '100.000',
      'discount_amount': '10.000',
      'tax_amount': '4.500',
      'total': '94.500',
    },
  ),
  InvoiceCalculationFixture(
    name: 'multiple_lines',
    decimalPlaces: 3,
    taxEnabled: true,
    effectiveTaxRate: '5',
    lines: [
      InvoiceLineInput(
        productId: productA,
        qty: Decimal.parse('1'),
        unitPrice: Decimal.parse('10.000'),
        discountPct: Decimal.zero,
        taxClass: ProductTaxClass.taxable,
      ),
      InvoiceLineInput(
        productId: productA,
        qty: Decimal.parse('2'),
        unitPrice: Decimal.parse('5.000'),
        discountPct: Decimal.zero,
        taxClass: ProductTaxClass.zeroRated,
      ),
    ],
    expectedLineMaps: const [
      {
        'gross_amount': '10.000',
        'discount_amount': '0.000',
        'before_tax_amount': '10.000',
        'tax_rate': '5',
        'taxable_amount': '10.000',
        'tax_amount': '0.500',
        'after_tax_amount': '10.500',
        'line_total': '10.500',
      },
      {
        'gross_amount': '10.000',
        'discount_amount': '0.000',
        'before_tax_amount': '10.000',
        'tax_rate': '0',
        'taxable_amount': '10.000',
        'tax_amount': '0.000',
        'after_tax_amount': '10.000',
        'line_total': '10.000',
      },
    ],
    expectedTotals: const {
      'subtotal': '20.000',
      'discount_amount': '0.000',
      'tax_amount': '0.500',
      'total': '20.500',
    },
  ),
  InvoiceCalculationFixture(
    name: 'rounding_boundary_3dp',
    decimalPlaces: 3,
    taxEnabled: true,
    effectiveTaxRate: '5',
    lines: [
      InvoiceLineInput(
        productId: productA,
        qty: Decimal.parse('3'),
        unitPrice: Decimal.parse('1.005'),
        discountPct: Decimal.zero,
        taxClass: ProductTaxClass.taxable,
      ),
    ],
    expectedLineMaps: const [
      {
        'gross_amount': '3.015',
        'discount_amount': '0.000',
        'before_tax_amount': '3.015',
        'tax_rate': '5',
        'taxable_amount': '3.015',
        'tax_amount': '0.151',
        'after_tax_amount': '3.166',
        'line_total': '3.166',
      },
    ],
    expectedTotals: const {
      'subtotal': '3.015',
      'discount_amount': '0.000',
      'tax_amount': '0.151',
      'total': '3.166',
    },
  ),
  InvoiceCalculationFixture(
    name: 'decimal_places_2',
    decimalPlaces: 2,
    taxEnabled: true,
    effectiveTaxRate: '5',
    lines: [
      InvoiceLineInput(
        productId: productA,
        qty: Decimal.parse('1'),
        unitPrice: Decimal.parse('10.555'),
        discountPct: Decimal.zero,
        taxClass: ProductTaxClass.taxable,
      ),
    ],
    expectedLineMaps: const [
      {
        'gross_amount': '10.56',
        'discount_amount': '0.00',
        'before_tax_amount': '10.56',
        'tax_rate': '5',
        'taxable_amount': '10.56',
        'tax_amount': '0.53',
        'after_tax_amount': '11.09',
        'line_total': '11.09',
      },
    ],
    expectedTotals: const {
      'subtotal': '10.56',
      'discount_amount': '0.00',
      'tax_amount': '0.53',
      'total': '11.09',
    },
  ),
  InvoiceCalculationFixture(
    name: 'decimal_places_0',
    decimalPlaces: 0,
    taxEnabled: true,
    effectiveTaxRate: '5',
    lines: [
      InvoiceLineInput(
        productId: productA,
        qty: Decimal.parse('2'),
        unitPrice: Decimal.parse('10.4'),
        discountPct: Decimal.zero,
        taxClass: ProductTaxClass.taxable,
      ),
    ],
    expectedLineMaps: const [
      {
        'gross_amount': '21',
        'discount_amount': '0',
        'before_tax_amount': '21',
        'tax_rate': '5',
        'taxable_amount': '21',
        'tax_amount': '1',
        'after_tax_amount': '22',
        'line_total': '22',
      },
    ],
    expectedTotals: const {
      'subtotal': '21',
      'discount_amount': '0',
      'tax_amount': '1',
      'total': '22',
    },
  ),
];

InvoiceTotals calculateFixtureTotals(InvoiceCalculationFixture fixture) {
  return calculateInvoiceTotals(
    lines: fixture.lines,
    decimalPlaces: fixture.decimalPlaces,
    taxEnabled: fixture.taxEnabled,
    effectiveTaxRateId: fixture.taxEnabled ? fixture.effectiveTaxRateId : null,
    effectiveTaxRate: Decimal.parse(fixture.effectiveTaxRate),
  );
}
