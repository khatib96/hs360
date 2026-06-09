import 'package:decimal/decimal.dart';

import '../../../core/errors/products_exception.dart';
import '../domain/product_form_state.dart';
import '../domain/product_type.dart';
import '../domain/unit_of_measure.dart';

/// Mutable wizard/edit draft mapped to [ProductFormState] on submit.
class ProductFormDraft {
  ProductFormDraft({
    this.barcode,
    this.nameAr = '',
    this.nameEn = '',
    this.groupId = '',
    this.productType = ProductType.saleOnly,
    this.canBeSold = true,
    this.canBeRented = false,
    this.unitPrimary = UnitOfMeasure.piece,
    this.unitSecondary,
    this.conversionFactor = '1',
    this.salePrice = '0',
    this.minSalePrice,
    this.avgCost,
    this.lastPurchaseCost,
    this.expectedLifespanMonths = '24',
    this.reorderPoint,
    this.isSerialized = false,
    this.trackableForMaintenance = false,
    this.isActive = true,
    this.imageUrl,
  });

  String? barcode;
  String nameAr;
  String nameEn;
  String groupId;
  ProductType productType;
  bool canBeSold;
  bool canBeRented;
  UnitOfMeasure unitPrimary;
  UnitOfMeasure? unitSecondary;
  String conversionFactor;
  String salePrice;
  String? minSalePrice;
  String? avgCost;
  String? lastPurchaseCost;
  String expectedLifespanMonths;
  String? reorderPoint;
  bool isSerialized;
  bool trackableForMaintenance;
  bool isActive;
  String? imageUrl;

  factory ProductFormDraft.fromFormState(ProductFormState state) {
    return ProductFormDraft(
      barcode: state.barcode,
      nameAr: state.nameAr,
      nameEn: state.nameEn,
      groupId: state.groupId,
      productType: state.productType,
      canBeSold: state.canBeSold,
      canBeRented: state.canBeRented,
      unitPrimary: state.unitPrimary,
      unitSecondary: state.unitSecondary,
      conversionFactor: state.conversionFactor.toString(),
      salePrice: state.salePrice.toString(),
      minSalePrice: state.minSalePrice?.toString(),
      avgCost: state.avgCost?.toString(),
      lastPurchaseCost: state.lastPurchaseCost?.toString(),
      expectedLifespanMonths: state.expectedLifespanMonths.toString(),
      reorderPoint: state.reorderPoint?.toString(),
      isSerialized: state.isSerialized,
      trackableForMaintenance: state.trackableForMaintenance,
      isActive: state.isActive,
      imageUrl: state.imageUrl,
    );
  }

  ProductFormState toFormState() {
    return ProductFormState(
      barcode: barcode?.trim().isEmpty == true ? null : barcode?.trim(),
      nameAr: nameAr,
      nameEn: nameEn,
      groupId: groupId,
      productType: productType,
      canBeSold: canBeSold,
      canBeRented: canBeRented,
      unitPrimary: unitPrimary,
      unitSecondary: unitSecondary,
      conversionFactor: _parseDecimal(
        conversionFactor,
        defaultValue: Decimal.one,
      ),
      salePrice: _parseDecimal(salePrice, defaultValue: Decimal.zero),
      minSalePrice: _tryParse(minSalePrice),
      avgCost: _tryParse(avgCost),
      lastPurchaseCost: _tryParse(lastPurchaseCost),
      expectedLifespanMonths: int.tryParse(expectedLifespanMonths.trim()) ?? 24,
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
        if (canBeSold) salePrice,
        if (canWriteCosts) ...[
          if (canBeSold) minSalePrice,
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

  bool get hasInvalidExpectedLifespan {
    if (!canBeRented || productType != ProductType.assetRental) return false;
    final parsed = int.tryParse(expectedLifespanMonths.trim());
    return parsed == null || parsed <= 0;
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
