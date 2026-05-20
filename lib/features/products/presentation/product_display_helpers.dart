import '../domain/product.dart';
import '../domain/product_group.dart';
import '../domain/product_type.dart';
import '../domain/unit_of_measure.dart';

/// Locale-aware product display name (pure — no providers).
String localizedProductName(Product product, String languageCode) {
  if (languageCode.toLowerCase() == 'ar') {
    return product.nameAr;
  }
  return product.nameEn;
}

/// Locale-aware group display name (pure — no providers).
String localizedGroupName(ProductGroup group, String languageCode) {
  if (languageCode.toLowerCase() == 'ar') {
    return group.nameAr;
  }
  return group.nameEn;
}

String localizedProductTypeLabel(
  ProductType type,
  String Function(String) labelFor,
) {
  return switch (type) {
    ProductType.saleOnly => labelFor('sale'),
    ProductType.assetRental => labelFor('asset'),
    ProductType.consumableRental => labelFor('consumable'),
  };
}

String unitOfMeasureLabel(UnitOfMeasure unit) {
  return unit.dbValue;
}
