import 'package:decimal/decimal.dart';

import '../../core/errors/products_exception.dart';
import '../../features/products/domain/product_form_state.dart';
import 'validation_result.dart';

class ProductValidator {
  const ProductValidator();

  ValidationResult validate(ProductFormState input) {
    final codes = <String>[];

    if (input.sku.trim().isEmpty) {
      codes.add(ProductsException.validationFailed);
    }
    if (input.nameAr.trim().isEmpty || input.nameEn.trim().isEmpty) {
      codes.add(ProductsException.validationFailed);
    }
    if (input.groupId.trim().isEmpty) {
      codes.add(ProductsException.validationFailed);
    }

    if (input.unitSecondary == null) {
      if (input.conversionFactor != Decimal.one) {
        codes.add(ProductsException.validationFailed);
      }
    } else if (input.conversionFactor <= Decimal.one) {
      codes.add(ProductsException.validationFailed);
    }

    if (input.minSalePrice != null && input.salePrice < input.minSalePrice!) {
      codes.add(ProductsException.validationFailed);
    }

    if (input.reorderPoint != null && input.reorderPoint! < Decimal.zero) {
      codes.add(ProductsException.validationFailed);
    }

    for (final cost in [
      input.avgCost,
      input.lastPurchaseCost,
      input.minSalePrice,
    ]) {
      if (cost != null && cost < Decimal.zero) {
        codes.add(ProductsException.validationFailed);
      }
    }

    if (input.minRentalPrice != null) {
      codes.add(ProductsException.fieldNotSupported);
    }

    if (codes.isEmpty) return const ValidationResult.valid();
    return ValidationResult(codes: codes);
  }
}
