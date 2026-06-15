class TaxSettings {
  const TaxSettings({
    required this.taxEnabled,
    this.taxRegistrationNumber,
    this.defaultTaxRateId,
    this.defaultTaxSeriesCode,
  });

  final bool taxEnabled;
  final String? taxRegistrationNumber;
  final String? defaultTaxRateId;
  final String? defaultTaxSeriesCode;
}
