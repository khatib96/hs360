import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/scanning/domain/scan_result.dart';

void main() {
  test('ScanResult.fromJson parses resolver payload', () {
    final result = ScanResult.fromJson({
      'kind': 'product_unit',
      'id': '00000000-0000-0000-0000-000000000001',
      'product_id': '00000000-0000-0000-0000-000000000901',
      'matched_by': 'serial_number',
      'display_code': 'SN-001',
      'is_active_or_available': true,
    });

    expect(result.kind, ScanResultKind.productUnit);
    expect(result.matchedBy, ScanMatchedBy.serialNumber);
    expect(result.displayCode, 'SN-001');
    expect(result.isActiveOrAvailable, isTrue);
  });

  test('ScanResult.fromJson parses product match', () {
    final result = ScanResult.fromJson({
      'kind': 'product',
      'id': '00000000-0000-0000-0000-000000000901',
      'product_id': '00000000-0000-0000-0000-000000000901',
      'matched_by': 'product_barcode',
      'display_code': '628000000001',
      'is_active_or_available': false,
    });

    expect(result.kind, ScanResultKind.product);
    expect(result.matchedBy, ScanMatchedBy.productBarcode);
    expect(result.isActiveOrAvailable, isFalse);
  });
}
