import 'package:decimal/decimal.dart';

import 'product_type.dart';
import 'unit_of_measure.dart';

/// Create/update product input. No [tenantId] — repository sets from [AppSession].
class ProductFormState {
  ProductFormState({
    required this.sku,
    required this.nameAr,
    required this.nameEn,
    required this.groupId,
    required this.productType,
    this.canBeSold = true,
    bool? canBeRented,
    required this.unitPrimary,
    this.barcode,
    this.descriptionAr,
    this.descriptionEn,
    this.unitSecondary,
    Decimal? conversionFactor,
    Decimal? salePrice,
    this.minSalePrice,
    this.avgCost,
    this.lastPurchaseCost,
    this.minRentalPrice,
    this.expectedLifespanMonths = 24,
    this.defaultOilMlPerMonth,
    this.isSerialized = false,
    this.trackableForMaintenance = false,
    this.reorderPoint,
    this.isActive = true,
    this.imageUrl,
  })  : canBeRented = canBeRented ?? productType.isRental,
        conversionFactor = conversionFactor ?? Decimal.one,
        salePrice = salePrice ?? Decimal.zero;

  final String sku;
  final String? barcode;
  final String nameAr;
  final String nameEn;
  final String? descriptionAr;
  final String? descriptionEn;
  final String groupId;
  /// Rental kind when [canBeRented] is true. [ProductType.saleOnly] is used
  /// for non-rental products to preserve the existing database enum.
  final ProductType productType;
  final bool canBeSold;
  final bool canBeRented;
  final UnitOfMeasure unitPrimary;
  final UnitOfMeasure? unitSecondary;
  final Decimal conversionFactor;
  final Decimal salePrice;
  final Decimal? minSalePrice;
  final Decimal? avgCost;
  final Decimal? lastPurchaseCost;
  final Decimal? minRentalPrice;
  final int expectedLifespanMonths;
  final Decimal? defaultOilMlPerMonth;
  final bool isSerialized;
  final bool trackableForMaintenance;
  final Decimal? reorderPoint;
  final bool isActive;
  final String? imageUrl;

  ProductType get effectiveProductType {
    if (!canBeRented) return ProductType.saleOnly;
    return productType.isRental ? productType : ProductType.assetRental;
  }

  bool get isAssetRental =>
      canBeRented && effectiveProductType == ProductType.assetRental;

  bool get isConsumableRental =>
      canBeRented && effectiveProductType == ProductType.consumableRental;
}
