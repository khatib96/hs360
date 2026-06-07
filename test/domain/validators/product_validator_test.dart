import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/products_exception.dart';
import 'package:hs360/domain/validators/product_validator.dart';
import 'package:hs360/features/products/domain/product_form_state.dart';
import 'package:hs360/features/products/domain/product_type.dart';
import 'package:hs360/features/products/domain/unit_of_measure.dart';

ProductFormState _validForm({ProductType type = ProductType.saleOnly}) {
  return ProductFormState(
    nameAr: 'اسم',
    nameEn: 'Name',
    groupId: 'g-1',
    productType: type,
    canBeSold: type == ProductType.saleOnly,
    canBeRented: type.isRental,
    unitPrimary: UnitOfMeasure.piece,
    salePrice: Decimal.fromInt(10),
  );
}

void main() {
  const validator = ProductValidator();

  test('valid form returns no codes', () {
    expect(validator.validate(_validForm()).isValid, isTrue);
  });

  test('name_ar_required when name empty', () {
    final form = _validForm();
    final result = validator.validate(
      ProductFormState(
        nameAr: '',
        nameEn: form.nameEn,
        groupId: form.groupId,
        productType: form.productType,
        canBeSold: form.canBeSold,
        canBeRented: form.canBeRented,
        unitPrimary: form.unitPrimary,
      ),
    );
    expect(result.codes, contains(ProductsException.nameArRequired));
  });

  test('rental product does not require product-level rental price', () {
    final result = validator.validate(
      ProductFormState(
        nameAr: 'a',
        nameEn: 'b',
        groupId: 'g',
        productType: ProductType.assetRental,
        canBeSold: false,
        canBeRented: true,
        unitPrimary: UnitOfMeasure.piece,
      ),
    );
    expect(result.isValid, isTrue);
  });

  test('serialized_requires_piece when serialized and not piece', () {
    final form = ProductFormState(
      nameAr: 'a',
      nameEn: 'b',
      groupId: 'g',
      productType: ProductType.saleOnly,
      canBeSold: true,
      canBeRented: false,
      unitPrimary: UnitOfMeasure.liter,
      isSerialized: true,
    );
    expect(
      validator.validate(form).codes,
      contains(ProductsException.serializedRequiresPiece),
    );
  });

  test('negative_value for negative sale price', () {
    final form = _validForm();
    final result = validator.validate(
      ProductFormState(
        nameAr: form.nameAr,
        nameEn: form.nameEn,
        groupId: form.groupId,
        productType: form.productType,
        canBeSold: form.canBeSold,
        canBeRented: form.canBeRented,
        unitPrimary: form.unitPrimary,
        salePrice: Decimal.fromInt(-1),
      ),
    );
    expect(result.codes, contains(ProductsException.negativeValue));
  });

  test('min_rental_price yields field_not_supported', () {
    final form = _validForm();
    final result = validator.validate(
      ProductFormState(
        nameAr: form.nameAr,
        nameEn: form.nameEn,
        groupId: form.groupId,
        productType: form.productType,
        canBeSold: form.canBeSold,
        canBeRented: form.canBeRented,
        unitPrimary: form.unitPrimary,
        minRentalPrice: Decimal.one,
      ),
    );
    expect(result.codes, contains(ProductsException.fieldNotSupported));
  });

  test('sale and rental together are valid', () {
    final form = ProductFormState(
      nameAr: 'a',
      nameEn: 'b',
      groupId: 'g',
      productType: ProductType.consumableRental,
      canBeSold: true,
      canBeRented: true,
      unitPrimary: UnitOfMeasure.liter,
      salePrice: Decimal.fromInt(10),
    );

    expect(validator.validate(form).isValid, isTrue);
  });

  test('product_mode_required when neither sale nor rental selected', () {
    final result = validator.validate(
      ProductFormState(
        nameAr: 'a',
        nameEn: 'b',
        groupId: 'g',
        productType: ProductType.saleOnly,
        canBeSold: false,
        canBeRented: false,
        unitPrimary: UnitOfMeasure.piece,
      ),
    );

    expect(result.codes, contains(ProductsException.productModeRequired));
  });

  test('expected_lifespan_invalid for asset rental with non-positive months', () {
    final result = validator.validate(
      ProductFormState(
        nameAr: 'a',
        nameEn: 'b',
        groupId: 'g',
        productType: ProductType.assetRental,
        canBeSold: false,
        canBeRented: true,
        unitPrimary: UnitOfMeasure.piece,
        expectedLifespanMonths: 0,
      ),
    );

    expect(
      result.codes,
      contains(ProductsException.expectedLifespanInvalid),
    );
  });
}
