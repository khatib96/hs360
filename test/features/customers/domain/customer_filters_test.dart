import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/customers/domain/customer_filters.dart';
import 'package:hs360/features/customers/domain/customer_type.dart';

void main() {
  group('CustomerFilters.hasNonDefaultFilters', () {
    test('active-only default is not treated as user-filtered', () {
      expect(
        const CustomerFilters(isActive: true).hasNonDefaultFilters,
        isFalse,
      );
    });

    test('status changes away from active-only are user filters', () {
      expect(const CustomerFilters().hasNonDefaultFilters, isTrue);
      expect(
        const CustomerFilters(isActive: false).hasNonDefaultFilters,
        isTrue,
      );
    });

    test('search and secondary filters are user filters', () {
      expect(
        const CustomerFilters(
          isActive: true,
          search: ' acme ',
        ).hasNonDefaultFilters,
        isTrue,
      );
      expect(
        const CustomerFilters(
          isActive: true,
          isVip: false,
        ).hasNonDefaultFilters,
        isTrue,
      );
      expect(
        const CustomerFilters(
          isActive: true,
          customerType: CustomerType.company,
        ).hasNonDefaultFilters,
        isTrue,
      );
      expect(
        const CustomerFilters(
          isActive: true,
          area: 'Hawalli',
        ).hasNonDefaultFilters,
        isTrue,
      );
      expect(
        const CustomerFilters(
          isActive: true,
          governorate: 'hawalli',
        ).hasNonDefaultFilters,
        isTrue,
      );
    });
  });
}
