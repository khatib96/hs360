import 'package:decimal/decimal.dart';

import '../../core/errors/products_exception.dart';
import '../../features/products/domain/product_form_state.dart';
import '../../features/products/domain/unit_of_measure.dart';
import 'validation_result.dart';

class ProductValidator {
  const ProductValidator();

  ValidationResult validate(ProductFormState input) {
    final codes = <String>[];

    if (input.nameAr.trim().isEmpty) {
      codes.add(ProductsException.nameArRequired);
    }
    if (input.nameEn.trim().isEmpty) {
      codes.add(ProductsException.nameEnRequired);
    }
    if (input.groupId.trim().isEmpty) {
      codes.add(ProductsException.groupRequired);
    }
    if (!input.canBeSold && !input.canBeRented) {
      codes.add(ProductsException.productModeRequired);
    }

    if (input.unitSecondary == null) {
      if (input.conversionFactor != Decimal.one) {
        codes.add(ProductsException.conversionFactorInvalid);
      }
    } else if (input.conversionFactor <= Decimal.one) {
      codes.add(ProductsException.conversionFactorInvalid);
    }

    if (input.salePrice < Decimal.zero) {
      codes.add(ProductsException.negativeValue);
    }
    if (input.canBeSold &&
        input.minSalePrice != null &&
        input.minSalePrice! < Decimal.zero) {
      codes.add(ProductsException.negativeValue);
    }
    if (input.reorderPoint != null && input.reorderPoint! < Decimal.zero) {
      codes.add(ProductsException.negativeValue);
    }
    for (final cost in [input.avgCost, input.lastPurchaseCost]) {
      if (cost != null && cost < Decimal.zero) {
        codes.add(ProductsException.negativeValue);
      }
    }

    if (input.canBeSold &&
        input.minSalePrice != null &&
        input.salePrice < input.minSalePrice!) {
      codes.add(ProductsException.salePriceBelowMin);
    }

    if (input.isAssetRental && input.expectedLifespanMonths <= 0) {
      codes.add(ProductsException.expectedLifespanInvalid);
    }

    if (input.isSerialized && input.unitPrimary != UnitOfMeasure.piece) {
      codes.add(ProductsException.serializedRequiresPiece);
    }

    if (input.minRentalPrice != null) {
      codes.add(ProductsException.fieldNotSupported);
    }

    if (codes.isEmpty) return const ValidationResult.valid();
    return ValidationResult(codes: codes);
  }

  /// Step-scoped validation for wizard navigation (1–5).
  ValidationResult validateStep(int step, ProductFormState input) {
    final all = validate(input);
    if (all.isValid) return all;

    final stepCodes = switch (step) {
      1 => {
        ProductsException.nameArRequired,
        ProductsException.nameEnRequired,
        ProductsException.groupRequired,
        ProductsException.productModeRequired,
      },
      2 => {ProductsException.conversionFactorInvalid},
      3 => {
        ProductsException.negativeValue,
        ProductsException.salePriceBelowMin,
      },
      4 => {
        ProductsException.serializedRequiresPiece,
        ProductsException.expectedLifespanInvalid,
      },
      _ => <String>{},
    };

    final filtered = all.codes
        .where((c) => step == 5 || stepCodes.contains(c))
        .toList();
    if (filtered.isEmpty) return const ValidationResult.valid();
    return ValidationResult(codes: filtered);
  }
}
