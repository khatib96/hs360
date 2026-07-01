import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/utils/decimal_parser.dart';

void main() {
  group('parseDecimal', () {
    test('parses int', () {
      expect(parseDecimal(10), Decimal.fromInt(10));
    });

    test('parses string', () {
      expect(parseDecimal('12.500'), Decimal.parse('12.500'));
    });

    test('parses editable decimal text', () {
      expect(parseDecimal('5.'), Decimal.parse('5.0'));
      expect(parseDecimal('.5'), Decimal.parse('0.5'));
      expect(parseDecimal('5,5'), Decimal.parse('5.5'));
      expect(parseDecimal('٥٫٥'), Decimal.parse('5.5'));
    });

    test('parses Decimal', () {
      final d = Decimal.parse('1.5');
      expect(parseDecimal(d), d);
    });

    test('throws on invalid', () {
      expect(() => parseDecimal('not-a-number'), throwsFormatException);
    });
  });

  group('tryParseDecimal', () {
    test('returns null for null', () {
      expect(tryParseDecimal(null), isNull);
    });

    test('returns null for empty string', () {
      expect(tryParseDecimal('  '), isNull);
    });

    test('returns null for transient invalid input', () {
      expect(tryParseDecimal('.'), isNull);
      expect(tryParseDecimal('..'), isNull);
    });
  });
}
