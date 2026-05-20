import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/products_exception.dart';
import 'package:hs360/domain/validators/product_validator.dart';
import 'package:hs360/features/products/domain/product_form_state.dart';
import 'package:hs360/features/products/domain/product_type.dart';
import 'package:hs360/features/products/domain/unit_of_measure.dart';

ProductFormState _validForm({ProductType type = ProductType.saleOnly}) {
  return ProductFormState(
    sku: 'SKU-1',
    nameAr: 'اسم',
    nameEn: 'Name',
    groupId: 'g-1',
    productType: type,
    unitPrimary: UnitOfMeasure.piece,
    salePrice: Decimal.fromInt(10),
    rentalPriceMonthly:
        type.isRental ? Decimal.fromInt(50) : null,
  );
}

void main() {
  const validator = ProductValidator();

  test('valid form returns no codes', () {
    expect(validator.validate(_validForm()).isValid, isTrue);
  });

  test('sku_required when sku empty', () {
    final form = _validForm();
    final result = validator.validate(
      ProductFormState(
        sku: '',
        nameAr: form.nameAr,
        nameEn: form.nameEn,
        groupId: form.groupId,
        productType: form.productType,
        unitPrimary: form.unitPrimary,
      ),
    );
    expect(result.codes, contains(ProductsException.skuRequired));
  });

  test('rental_price_required for rental without price', () {
    final result = validator.validate(
      ProductFormState(
        sku: 'S',
        nameAr: 'a',
        nameEn: 'b',
        groupId: 'g',
        productType: ProductType.assetRental,
        unitPrimary: UnitOfMeasure.piece,
        rentalPriceMonthly: null,
      ),
    );
    expect(result.codes, contains(ProductsException.rentalPriceRequired));
  });

  test('serialized_requires_piece when serialized and not piece', () {
    final form = ProductFormState(
      sku: 'S',
      nameAr: 'a',
      nameEn: 'b',
      groupId: 'g',
      productType: ProductType.saleOnly,
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
        sku: form.sku,
        nameAr: form.nameAr,
        nameEn: form.nameEn,
        groupId: form.groupId,
        productType: form.productType,
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
        sku: form.sku,
        nameAr: form.nameAr,
        nameEn: form.nameEn,
        groupId: form.groupId,
        productType: form.productType,
        unitPrimary: form.unitPrimary,
        minRentalPrice: Decimal.one,
      ),
    );
    expect(result.codes, contains(ProductsException.fieldNotSupported));
  });
}
