import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/domain/services/unit_conversion_service.dart';

void main() {
  const service = UnitConversionService();

  test('toPrimary multiplies by factor', () {
    expect(
      service.toPrimary(Decimal.fromInt(2), Decimal.fromInt(1000)),
      Decimal.fromInt(2000),
    );
  });

  test('toSecondary divides by factor', () {
    expect(
      service.toSecondary(Decimal.fromInt(2000), Decimal.fromInt(1000)),
      Decimal.fromInt(2),
    );
  });

  test('rejects non-positive factor', () {
    expect(
      () => service.validateConversionFactor(Decimal.zero),
      throwsFormatException,
    );
  });
}
