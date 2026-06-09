import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/products/domain/product_unit_bulk_parser.dart';

void main() {
  const parser = ProductUnitBulkParser();

  test('parses one serial per line', () {
    final result = parser.parse('HS-001\nHS-002\n');
    expect(result.hasErrors, isFalse);
    expect(result.rows.length, 2);
    expect(result.rows.first.serialNumber, 'HS-001');
  });

  test('trims whitespace and rejects empty serials', () {
    final result = parser.parse('  HS-001  \n\n');
    expect(result.rows.length, 1);
    expect(result.rows.first.serialNumber, 'HS-001');
  });

  test('detects duplicate serials case-insensitively', () {
    final result = parser.parse('ABC\nabc');
    expect(result.hasErrors, isTrue);
    expect(
      result.errors.any((e) => e.startsWith('duplicate_serial_in_input')),
      isTrue,
    );
  });

  test('parses CSV with optional header', () {
    final raw =
        'serial_number,barcode,purchase_cost\n'
        'HS-1,628001,10\n'
        'HS-2,,20';
    final result = parser.parse(raw);
    expect(result.hasErrors, isFalse);
    expect(result.rows.length, 2);
    expect(result.rows.first.barcode, '628001');
    expect(result.rows.last.purchaseCost.toString(), '20');
  });

  test('rejects more than 100 rows', () {
    final lines = List.generate(101, (i) => 'S-$i').join('\n');
    final result = parser.parse(lines);
    expect(result.errors, contains('bulk_limit_exceeded'));
  });
}
