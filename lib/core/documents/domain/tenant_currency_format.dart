/// Tenant currency display rules from effective template RPC.
class TenantCurrencyFormat {
  const TenantCurrencyFormat({
    required this.isoCode,
    required this.majorSymbolAr,
    required this.majorSymbolEn,
    required this.decimalPlaces,
    required this.symbolPosition,
    required this.thousandSeparator,
    required this.decimalSeparator,
  });

  final String isoCode;
  final String majorSymbolAr;
  final String majorSymbolEn;
  final int decimalPlaces;
  final String symbolPosition;
  final String thousandSeparator;
  final String decimalSeparator;

  factory TenantCurrencyFormat.fromRpc(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) {
      return TenantCurrencyFormat.defaults();
    }
    final code =
        json['code'] as String? ?? json['iso_code'] as String? ?? 'KWD';
    final symbol =
        json['symbol'] as String? ?? json['major_symbol_en'] as String? ?? '';
    final symbolAr = json['major_symbol_ar'] as String? ?? symbol;
    return TenantCurrencyFormat(
      isoCode: code,
      majorSymbolAr: symbolAr,
      majorSymbolEn: symbol,
      decimalPlaces: json['decimal_places'] as int? ?? 3,
      symbolPosition: json['symbol_position'] as String? ?? 'after',
      thousandSeparator: json['thousand_separator'] as String? ?? ',',
      decimalSeparator: json['decimal_separator'] as String? ?? '.',
    );
  }

  factory TenantCurrencyFormat.defaults() {
    return const TenantCurrencyFormat(
      isoCode: 'KWD',
      majorSymbolAr: 'د.ك',
      majorSymbolEn: 'KWD',
      decimalPlaces: 3,
      symbolPosition: 'after',
      thousandSeparator: ',',
      decimalSeparator: '.',
    );
  }

  String symbolForLocale(String languageCode) {
    return languageCode.startsWith('ar') ? majorSymbolAr : majorSymbolEn;
  }
}
