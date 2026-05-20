import 'product.dart';
import 'product_form_state.dart';
import 'product_type.dart';
import 'unit_of_measure.dart';

ProductFormState productFormStateFromProduct(Product product) {
  return ProductFormState(
    sku: product.sku,
    barcode: product.barcode,
    nameAr: product.nameAr,
    nameEn: product.nameEn,
    descriptionAr: product.descriptionAr,
    descriptionEn: product.descriptionEn,
    groupId: product.groupId,
    productType: product.productType,
    unitPrimary: product.unitPrimary,
    unitSecondary: product.unitSecondary,
    conversionFactor: product.conversionFactor,
    salePrice: product.salePrice,
    minSalePrice: product.minSalePrice,
    rentalPriceMonthly: product.rentalPriceMonthly,
    avgCost: product.avgCost,
    lastPurchaseCost: product.lastPurchaseCost,
    expectedLifespanMonths: product.expectedLifespanMonths ?? 24,
    defaultOilMlPerMonth: product.defaultOilMlPerMonth,
    isSerialized: product.isSerialized,
    trackableForMaintenance: product.trackableForMaintenance,
    reorderPoint: product.reorderPoint,
    isActive: product.isActive,
    imageUrl: product.imageUrl,
  );
}

ProductFormState emptyProductFormState({String groupId = ''}) {
  return ProductFormState(
    sku: '',
    nameAr: '',
    nameEn: '',
    groupId: groupId,
    productType: ProductType.saleOnly,
    unitPrimary: UnitOfMeasure.piece,
  );
}
