import 'package:decimal/decimal.dart';

import '../../../core/errors/products_exception.dart';
import '../domain/product_form_state.dart';
import '../domain/product_type.dart';
import '../domain/unit_of_measure.dart';

/// Mutable wizard/edit draft mapped to [ProductFormState] on submit.
class ProductFormDraft {
  ProductFormDraft({
    this.sku = '',
    this.barcode,
    this.nameAr = '',
    this.nameEn = '',
    this.groupId = '',
    this.productType = ProductType.saleOnly,
    this.unitPrimary = UnitOfMeasure.piece,
    this.unitSecondary,
    this.conversionFactor = '1',
    this.salePrice = '0',
    this.minSalePrice,
    this.rentalPriceMonthly,
    this.avgCost,
    this.lastPurchaseCost,
    this.reorderPoint,
    this.isSerialized = false,
    this.trackableForMaintenance = false,
    this.isActive = true,
    this.imageUrl,
  });

  String sku;
  String? barcode;
  String nameAr;
  String nameEn;
  String groupId;
  ProductType productType;
  UnitOfMeasure unitPrimary;
  UnitOfMeasure? unitSecondary;
  String conversionFactor;
  String salePrice;
  String? minSalePrice;
  String? rentalPriceMonthly;
  String? avgCost;
  String? lastPurchaseCost;
  String? reorderPoint;
  bool isSerialized;
  bool trackableForMaintenance;
  bool isActive;
  String? imageUrl;

  factory ProductFormDraft.fromFormState(ProductFormState state) {
    return ProductFormDraft(
      sku: state.sku,
      barcode: state.barcode,
      nameAr: state.nameAr,
      nameEn: state.nameEn,
      groupId: state.groupId,
      productType: state.productType,
      unitPrimary: state.unitPrimary,
      unitSecondary: state.unitSecondary,
      conversionFactor: state.conversionFactor.toString(),
      salePrice: state.salePrice.toString(),
      minSalePrice: state.minSalePrice?.toString(),
      rentalPriceMonthly: state.rentalPriceMonthly?.toString(),
      avgCost: state.avgCost?.toString(),
      lastPurchaseCost: state.lastPurchaseCost?.toString(),
      reorderPoint: state.reorderPoint?.toString(),
      isSerialized: state.isSerialized,
      trackableForMaintenance: state.trackableForMaintenance,
      isActive: state.isActive,
      imageUrl: state.imageUrl,
    );
  }

  ProductFormState toFormState() {
    return ProductFormState(
      sku: sku,
      barcode: barcode?.trim().isEmpty == true ? null : barcode?.trim(),
      nameAr: nameAr,
      nameEn: nameEn,
      groupId: groupId,
      productType: productType,
      unitPrimary: unitPrimary,
      unitSecondary: unitSecondary,
      conversionFactor: _parseDecimal(conversionFactor, defaultValue: Decimal.one),
      salePrice: _parseDecimal(salePrice, defaultValue: Decimal.zero),
      minSalePrice: _tryParse(minSalePrice),
      rentalPriceMonthly: _tryParse(rentalPriceMonthly),
      avgCost: _tryParse(avgCost),
      lastPurchaseCost: _tryParse(lastPurchaseCost),
      reorderPoint: _tryParse(reorderPoint),
      isSerialized: isSerialized,
      trackableForMaintenance: trackableForMaintenance,
      isActive: isActive,
      imageUrl: imageUrl,
    );
  }

  String? firstInvalidDecimalCodeForStep(
    int step, {
    required bool canWriteCosts,
  }) {
    final values = switch (step) {
      2 => <String?>[conversionFactor],
      3 => <String?>[
          salePrice,
          if (productType.isRental) rentalPriceMonthly,
          if (canWriteCosts) ...[
            minSalePrice,
            avgCost,
            lastPurchaseCost,
          ],
        ],
      4 => <String?>[reorderPoint],
      _ => const <String?>[],
    };

    for (final value in values) {
      if (_isInvalidDecimal(value)) {
        return ProductsException.invalidDecimal;
      }
    }
    return null;
  }

  String? firstInvalidDecimalCode({required bool canWriteCosts}) {
    for (final step in const [2, 3, 4]) {
      final code = firstInvalidDecimalCodeForStep(
        step,
        canWriteCosts: canWriteCosts,
      );
      if (code != null) return code;
    }
    return null;
  }

  static Decimal _parseDecimal(String value, {required Decimal defaultValue}) {
    final parsed = _tryParse(value);
    return parsed ?? defaultValue;
  }

  static Decimal? _tryParse(String? value) {
    if (value == null) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    return Decimal.tryParse(trimmed);
  }

  static bool _isInvalidDecimal(String? value) {
    if (value == null) return false;
    final trimmed = value.trim();
    if (trimmed.isEmpty) return true;
    return Decimal.tryParse(trimmed) == null;
  }
}
