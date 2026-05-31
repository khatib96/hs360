import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/suppliers/domain/supplier_filters.dart';

void main() {
  group('SupplierFilters.hasNonDefaultFilters', () {
    test('active-only default is not treated as user-filtered', () {
      expect(
        const SupplierFilters(isActive: true).hasNonDefaultFilters,
        isFalse,
      );
    });

    test('status changes away from active-only are user filters', () {
      expect(const SupplierFilters().hasNonDefaultFilters, isTrue);
      expect(
        const SupplierFilters(isActive: false).hasNonDefaultFilters,
        isTrue,
      );
    });

    test('search is a user filter', () {
      expect(
        const SupplierFilters(
          isActive: true,
          search: ' supplier ',
        ).hasNonDefaultFilters,
        isTrue,
      );
    });
  });
}
