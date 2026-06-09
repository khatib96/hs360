import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/inventory/domain/movement_type.dart';
import 'package:hs360/features/inventory/domain/warehouse_type.dart';
import 'package:hs360/features/products/domain/product_type.dart';
import 'package:hs360/features/products/domain/unit_of_measure.dart';
import 'package:hs360/features/products/domain/unit_status.dart';

void main() {
  group('ProductType', () {
    test('round-trips all values from 003_enums.sql', () {
      const values = ['sale_only', 'asset_rental', 'consumable_rental'];
      for (final v in values) {
        expect(ProductType.fromDb(v).toDb(), v);
      }
    });

    test('unknown value throws', () {
      expect(() => ProductType.fromDb('invalid'), throwsFormatException);
    });
  });

  group('UnitOfMeasure', () {
    test('round-trips all values', () {
      const values = [
        'piece',
        'liter',
        'ml',
        'gram',
        'kg',
        'box',
        'bottle',
        'carton',
        'meter',
        'pack',
      ];
      for (final v in values) {
        expect(UnitOfMeasure.fromDb(v).toDb(), v);
      }
    });
  });

  group('WarehouseType', () {
    test('round-trips all values', () {
      for (final v in ['main', 'branch', 'van']) {
        expect(WarehouseType.fromDb(v).toDb(), v);
      }
    });
  });

  group('MovementType', () {
    test('round-trips all values from 003_enums.sql', () {
      const values = [
        'purchase',
        'sale',
        'rental_out',
        'rental_return',
        'refill',
        'transfer_out',
        'transfer_in',
        'adjustment_in',
        'adjustment_out',
        'sale_return',
        'purchase_return',
        'maintenance_in',
        'maintenance_out',
      ];
      for (final v in values) {
        expect(MovementType.fromDb(v).toDb(), v);
      }
    });
  });

  group('UnitStatus', () {
    test('round-trips all values', () {
      const values = [
        'available_new',
        'available_used',
        'rented',
        'trial',
        'maintenance',
        'sold',
        'damaged',
        'lost',
        'retired',
      ];
      for (final v in values) {
        expect(UnitStatus.fromDb(v).toDb(), v);
      }
    });
  });
}
