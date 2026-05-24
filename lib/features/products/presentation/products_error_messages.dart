import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/errors/products_exception.dart';

String productsErrorCode(Object? error) {
  if (error is ProductsException) return error.code;
  return ProductsException.unknown;
}

String productsErrorMessage(AppLocalizations l10n, String code) {
  return switch (code) {
    ProductsException.permissionDenied => l10n.productErrorPermissionDenied,
    ProductsException.skuRequired => l10n.productValidationSkuRequired,
    ProductsException.nameArRequired => l10n.productValidationNameArRequired,
    ProductsException.nameEnRequired => l10n.productValidationNameEnRequired,
    ProductsException.groupRequired => l10n.productValidationGroupRequired,
    ProductsException.conversionFactorInvalid =>
      l10n.productValidationConversionInvalid,
    ProductsException.salePriceBelowMin => l10n.productValidationSaleBelowMin,
    ProductsException.rentalPriceRequired =>
      l10n.productValidationRentalRequired,
    ProductsException.serializedRequiresPiece =>
      l10n.productValidationSerializedPiece,
    ProductsException.negativeValue => l10n.productValidationNegative,
    ProductsException.invalidDecimal => l10n.productValidationInvalidDecimal,
    ProductsException.productGroupsPermissionRequired =>
      l10n.productGroupsPermissionRequired,
    ProductsException.imageTypeInvalid => l10n.productErrorImageType,
    ProductsException.imageTooLarge => l10n.productErrorImageSize,
    ProductsException.duplicateSku => l10n.productErrorDuplicateSku,
    ProductsException.duplicateBarcode => l10n.productErrorDuplicateBarcode,
    ProductsException.fieldNotSupported => l10n.productErrorFieldNotSupported,
    ProductsException.validationFailed => l10n.productValidationFailed,
    ProductsException.duplicateSerial => l10n.productUnitErrorDuplicateSerial,
    ProductsException.notSerializedProduct => l10n.productUnitErrorNotSerialized,
    ProductsException.unitNotEditable => l10n.productUnitErrorNotEditable,
    ProductsException.bulkLimitExceeded => l10n.productUnitErrorBulkLimit,
    _ => l10n.productErrorUnknown,
  };
}
