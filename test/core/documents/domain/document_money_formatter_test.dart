import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/document_money_formatter.dart';
import 'package:hs360/core/documents/domain/tenant_currency_format.dart';

void main() {
  const format = TenantCurrencyFormat(
    isoCode: 'KWD',
    majorSymbolAr: 'د.ك',
    majorSymbolEn: 'KWD',
    decimalPlaces: 3,
    symbolPosition: 'after',
    thousandSeparator: ',',
    decimalSeparator: '.',
  );

  test('formats without using double conversion in output path', () {
    final value = Decimal.parse('1234.567');
    final formatted = formatDocumentMoney(value, format, languageCode: 'en');
    expect(formatted, '1,234.567 KWD');
  });

  test('Arabic symbol suffix', () {
    final formatted = formatDocumentMoney(
      Decimal.parse('10.000'),
      format,
      languageCode: 'ar',
    );
    expect(formatted, '10.000 د.ك');
  });

  test('before symbol position', () {
    const beforeFormat = TenantCurrencyFormat(
      isoCode: 'USD',
      majorSymbolAr: r'$',
      majorSymbolEn: r'$',
      decimalPlaces: 2,
      symbolPosition: 'before',
      thousandSeparator: ',',
      decimalSeparator: '.',
    );
    final formatted = formatDocumentMoney(
      Decimal.parse('12.50'),
      beforeFormat,
      languageCode: 'en',
    );
    expect(formatted, r'$12.50');
  });

  test('negative values', () {
    final formatted = formatDocumentMoney(
      Decimal.parse('-5.250'),
      format,
      languageCode: 'en',
      includeSymbol: false,
    );
    expect(formatted, '-5.250');
  });

  test('formats normalized serialized values without Decimal parsing', () {
    expect(
      tryFormatSerializedDocumentMoney('001234.5', format, languageCode: 'en'),
      '1,234.500 KWD',
    );
    expect(
      tryFormatSerializedDocumentMoney('-0.000', format, languageCode: 'en'),
      '0.000 KWD',
    );
  });

  test('defers values that require rounding to the Decimal path', () {
    expect(tryFormatSerializedDocumentMoney('1.2345', format), isNull);
  });
}
