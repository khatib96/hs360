import '../domain/product.dart';
import '../domain/product_group.dart';
import '../domain/product_type.dart';
import '../domain/unit_of_measure.dart';

/// Locale-aware product display name (pure — no providers).
String localizedProductName(Product product, String languageCode) {
  if (languageCode.toLowerCase() == 'ar') {
    return _localizedText(product.nameAr, product.nameEn);
  }
  return product.nameEn;
}

/// Locale-aware group display name (pure — no providers).
String localizedGroupName(ProductGroup group, String languageCode) {
  if (languageCode.toLowerCase() == 'ar') {
    return _localizedText(group.nameAr, group.nameEn);
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

String _localizedText(String preferred, String fallback) {
  final value = preferred.trim();
  if (value.isEmpty || value.contains('?')) {
    return fallback;
  }
  return preferred;
}
