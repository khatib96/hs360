import 'package:decimal/decimal.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/products/data/product_group_repository.dart';
import 'package:hs360/features/products/data/product_repository.dart';
import 'package:hs360/features/products/domain/product.dart';
import 'package:hs360/features/products/domain/product_filters.dart';
import 'package:hs360/features/products/domain/product_group.dart';
import 'package:hs360/features/products/domain/product_stock_summary.dart';
import 'package:hs360/features/products/domain/product_type.dart';
import 'package:hs360/features/products/domain/unit_of_measure.dart';

class FakeProductRepository extends ProductRepository {
  FakeProductRepository({
    this.products = const [],
    this.stockThrows = false,
  }) : super(null);

  List<Product> products;
  bool stockThrows;
  ProductFilters? lastFilters;
  int stockFetchCount = 0;

  @override
  Future<List<Product>> fetchProducts(
    ProductFilters filters,
    AppSession session,
  ) async {
    lastFilters = filters;
    return List<Product>.from(products);
  }

  @override
  Future<ProductStockSummary> fetchProductStock(String productId) async {
    stockFetchCount++;
    if (stockThrows) throw Exception('stock failed');
    return ProductStockSummary(
      productId: productId,
      totalQtyAvailable: Decimal.fromInt(5),
    );
  }
}

class FakeProductGroupRepository extends ProductGroupRepository {
  FakeProductGroupRepository({
    this.groups = const [],
    this.fetchThrows = false,
  }) : super(null);

  List<ProductGroup> groups;
  bool fetchThrows;
  int fetchCount = 0;

  @override
  Future<List<ProductGroup>> fetchProductGroups({bool activeOnly = false}) async {
    fetchCount++;
    if (fetchThrows) throw Exception('groups failed');
    return List<ProductGroup>.from(groups);
  }
}

Product sampleProduct({String id = 'p-1', String groupId = 'g-1'}) {
  return Product(
    id: id,
    tenantId: 't-1',
    sku: 'SKU-001',
    nameAr: 'منتج',
    nameEn: 'Product',
    groupId: groupId,
    productType: ProductType.saleOnly,
    unitPrimary: UnitOfMeasure.piece,
    conversionFactor: Decimal.one,
    salePrice: Decimal.fromInt(100),
    isSerialized: false,
    trackableForMaintenance: false,
    isActive: true,
  );
}

ProductGroup sampleGroup({String id = 'g-1'}) {
  return ProductGroup(
    id: id,
    tenantId: 't-1',
    nameAr: 'مجموعة',
    nameEn: 'Group',
    isActive: true,
  );
}
