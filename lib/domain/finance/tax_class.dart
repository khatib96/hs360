enum ProductTaxClass { taxable, zeroRated, exempt, nonTaxable }

extension ProductTaxClassDb on ProductTaxClass {
  String get dbValue => switch (this) {
    ProductTaxClass.taxable => 'taxable',
    ProductTaxClass.zeroRated => 'zero_rated',
    ProductTaxClass.exempt => 'exempt',
    ProductTaxClass.nonTaxable => 'non_taxable',
  };

  static ProductTaxClass fromDb(String value) => switch (value) {
    'taxable' => ProductTaxClass.taxable,
    'zero_rated' => ProductTaxClass.zeroRated,
    'exempt' => ProductTaxClass.exempt,
    'non_taxable' => ProductTaxClass.nonTaxable,
    _ => throw ArgumentError('Unknown product tax class: $value'),
  };
}
