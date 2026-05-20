import '../domain/product.dart';
import '../domain/product_group.dart';

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
