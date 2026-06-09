import 'package:decimal/decimal.dart';

import '../../../core/utils/decimal_parser.dart';
import 'product_type.dart';
import 'unit_of_measure.dart';

/// Product row from [products] or [products_safe].
class Product {
  const Product({
    required this.id,
    required this.tenantId,
    required this.sku,
    this.barcode,
    required this.nameAr,
    required this.nameEn,
    this.descriptionAr,
    this.descriptionEn,
    required this.groupId,
    required this.productType,
    required this.canBeSold,
    required this.canBeRented,
    required this.unitPrimary,
    this.unitSecondary,
    required this.conversionFactor,
    required this.salePrice,
    this.minSalePrice,
    this.avgCost,
    this.lastPurchaseCost,
    this.minRentalPrice,
    this.expectedLifespanMonths,
    this.defaultOilMlPerMonth,
    required this.isSerialized,
    required this.trackableForMaintenance,
    this.reorderPoint,
    required this.isActive,
    this.imageUrl,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String tenantId;
  final String sku;
  final String? barcode;
  final String nameAr;
  final String nameEn;
  final String? descriptionAr;
  final String? descriptionEn;
  final String groupId;
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
  final int? expectedLifespanMonths;
  final Decimal? defaultOilMlPerMonth;
  final bool isSerialized;
  final bool trackableForMaintenance;
  final Decimal? reorderPoint;
  final bool isActive;
  final String? imageUrl;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory Product.fromRow(Map<String, dynamic> row) {
    return Product(
      id: row['id'] as String,
      tenantId: row['tenant_id'] as String,
      sku: row['sku'] as String,
      barcode: row['barcode'] as String?,
      nameAr: row['name_ar'] as String,
      nameEn: row['name_en'] as String,
      descriptionAr: row['description_ar'] as String?,
      descriptionEn: row['description_en'] as String?,
      groupId: row['group_id'] as String,
      productType: ProductType.fromDb(row['product_type'] as String?),
      canBeSold:
          row['can_be_sold'] as bool? ??
          (ProductType.fromDb(row['product_type'] as String?) ==
              ProductType.saleOnly),
      canBeRented:
          row['can_be_rented'] as bool? ??
          ProductType.fromDb(row['product_type'] as String?).isRental,
      unitPrimary: UnitOfMeasure.fromDb(row['unit_primary'] as String?),
      unitSecondary: row['unit_secondary'] != null
          ? UnitOfMeasure.fromDb(row['unit_secondary'] as String?)
          : null,
      conversionFactor: parseDecimal(row['conversion_factor']),
      salePrice: parseDecimal(row['sale_price']),
      minSalePrice: tryParseDecimal(row['min_sale_price']),
      avgCost: tryParseDecimal(row['avg_cost']),
      lastPurchaseCost: tryParseDecimal(row['last_purchase_cost']),
      minRentalPrice: tryParseDecimal(row['min_rental_price']),
      expectedLifespanMonths: row['expected_lifespan_months'] as int?,
      defaultOilMlPerMonth: tryParseDecimal(row['default_oil_ml_per_month']),
      isSerialized: row['is_serialized'] as bool? ?? false,
      trackableForMaintenance:
          row['trackable_for_maintenance'] as bool? ?? false,
      reorderPoint: tryParseDecimal(row['reorder_point']),
      isActive: row['is_active'] as bool? ?? true,
      imageUrl: row['image_url'] as String?,
      createdAt: row['created_at'] != null
          ? DateTime.parse(row['created_at'] as String)
          : null,
      updatedAt: row['updated_at'] != null
          ? DateTime.parse(row['updated_at'] as String)
          : null,
    );
  }

  Product copyWith({
    bool? isActive,
    Decimal? avgCost,
    Decimal? lastPurchaseCost,
  }) {
    return Product(
      id: id,
      tenantId: tenantId,
      sku: sku,
      barcode: barcode,
      nameAr: nameAr,
      nameEn: nameEn,
      descriptionAr: descriptionAr,
      descriptionEn: descriptionEn,
      groupId: groupId,
      productType: productType,
      canBeSold: canBeSold,
      canBeRented: canBeRented,
      unitPrimary: unitPrimary,
      unitSecondary: unitSecondary,
      conversionFactor: conversionFactor,
      salePrice: salePrice,
      minSalePrice: minSalePrice,
      avgCost: avgCost ?? this.avgCost,
      lastPurchaseCost: lastPurchaseCost ?? this.lastPurchaseCost,
      minRentalPrice: minRentalPrice,
      expectedLifespanMonths: expectedLifespanMonths,
      defaultOilMlPerMonth: defaultOilMlPerMonth,
      isSerialized: isSerialized,
      trackableForMaintenance: trackableForMaintenance,
      reorderPoint: reorderPoint,
      isActive: isActive ?? this.isActive,
      imageUrl: imageUrl,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// Column lists for explicit Supabase selects (never use *).
abstract final class ProductColumns {
  static const safe = '''
id, tenant_id, sku, barcode, name_ar, name_en, description_ar, description_en,
group_id, product_type, can_be_sold, can_be_rented,
unit_primary, unit_secondary, conversion_factor,
sale_price, expected_lifespan_months, default_oil_ml_per_month,
is_serialized, trackable_for_maintenance, reorder_point, is_active, image_url, created_at
''';

  static const full = '''
id, tenant_id, sku, barcode, name_ar, name_en, description_ar, description_en,
group_id, product_type, can_be_sold, can_be_rented,
unit_primary, unit_secondary, conversion_factor,
sale_price, expected_lifespan_months, default_oil_ml_per_month,
is_serialized, trackable_for_maintenance, reorder_point, is_active, image_url,
created_at, updated_at, avg_cost, last_purchase_cost, min_sale_price
''';
}
