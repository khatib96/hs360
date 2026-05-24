import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/products/domain/product_unit_edit_policy.dart';
import 'package:hs360/features/products/domain/unit_status.dart';

void main() {
  test('rented unit is not safe editable', () {
    expect(isUnitSafeEditable(UnitStatus.rented), isFalse);
    expect(isUnitSafeEditable(UnitStatus.availableNew), isTrue);
    expect(isUnitSafeEditable(UnitStatus.lost), isTrue);
  });
}
