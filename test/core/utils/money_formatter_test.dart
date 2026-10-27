import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/utils/money_formatter.dart';

void main() {
  test('keeps fixed currency decimals and groups thousands', () {
    expect(formatMoney(Decimal.parse('1234.5')), '1,234.500');
    expect(formatMoney(Decimal.zero), '0.000');
    expect(formatMoney(Decimal.parse('12.5'), decimalPlaces: 2), '12.50');
    expect(formatMoney(Decimal.parse('12.5'), decimalPlaces: 0), '13');
  });

  test('formats the largest numeric(15,3) value exactly', () {
    expect(
      formatMoney(Decimal.parse('999999999999.999')),
      '999,999,999,999.999',
    );
  });

  test('rounds ties half-up instead of through binary doubles', () {
    expect(formatMoney(Decimal.parse('1.005'), decimalPlaces: 2), '1.01');
    expect(formatMoney(Decimal.parse('-0.0005')), '-0.001');
  });

  test('keeps the sign of small negative amounts', () {
    expect(formatMoney(Decimal.parse('-0.5')), '-0.500');
  });
}
