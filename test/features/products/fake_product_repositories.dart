import 'package:decimal/decimal.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/products/data/product_group_repository.dart';
import 'package:hs360/features/products/data/product_repository.dart';
import 'package:hs360/features/products/domain/product.dart';
import 'package:hs360/features/products/domain/product_filters.dart';
import 'package:hs360/features/products/domain/product_group.dart';
import 'package:hs360/features/products/domain/product_stock_label.dart';
import 'package:hs360/features/products/domain/product_stock_summary.dart';
import 'package:hs360/features/products/domain/product_permissions.dart';
import 'package:hs360/core/errors/products_exception.dart';
import 'package:hs360/features/products/domain/product_form_state.dart';
import 'package:hs360/features/products/domain/product_type.dart';
import 'package:hs360/features/products/domain/unit_of_measure.dart';

class FakeProductRepository extends ProductRepository {
  FakeProductRepository({
    this.products = const [],
    this.productById,
    this.stockThrows = false,
    this.stockLabelsById = const {},
    this.stockLabelsThrows = false,
    this.searchProductIdsResult = const {},
    this.searchProductIdsThrows = false,
  }) : super(null);

  List<Product> products;
  Product? productById;
  bool stockThrows;
  Map<String, ProductStockLabel> stockLabelsById;
  bool stockLabelsThrows;
  bool searchProductIdsThrows = false;
  Set<String> searchProductIdsResult = const {};
  String? lastMovementSearch;
  ProductFilters? lastFilters;
  int stockFetchCount = 0;
  int searchProductIdsCount = 0;

  @override
  Future<List<Product>> fetchProducts(
    ProductFilters filters,
    AppSession session,
  ) async {
    lastFilters = filters;
    return List<Product>.from(products);
  }

  ProductFormState? lastCreateInput;
  ProductFormState? lastUpdateInput;
  String? lastImageUrl;
  bool permissionDeniedOnImage = false;

  @override
  Future<Product?> fetchProductById(String id, AppSession session) async {
    if (productById != null && productById!.id == id) return productById;
    for (final product in products) {
      if (product.id == id) return product;
    }
    if (products.isNotEmpty) return products.first;
    return sampleProduct(id: id);
  }

  @override
  Future<Product> createProduct(
    AppSession session,
    ProductFormState input,
  ) async {
    lastCreateInput = input;
    final created = sampleProduct(id: 'new-id', groupId: input.groupId);
    products = [...products, created];
    return created;
  }

  @override
  Future<Product> updateProduct(
    AppSession session,
    String id,
    ProductFormState input,
  ) async {
    lastUpdateInput = input;
    return sampleProduct(id: id, groupId: input.groupId);
  }

  @override
  Future<void> updateProductImageUrl(
    AppSession session,
    String productId,
    String? imageUrl,
  ) async {
    if (permissionDeniedOnImage) {
      throw const ProductsException(code: ProductsException.permissionDenied);
    }
    lastImageUrl = imageUrl;
  }

  @override
  Future<Set<String>> searchProductIdsForInventoryMovements(
    AppSession session,
    String search,
  ) async {
    searchProductIdsCount++;
    lastMovementSearch = search;
    if (!canViewProductsList(session)) return {};
    if (searchProductIdsThrows) {
      throw const ProductsException(code: ProductsException.unknown);
    }
    return searchProductIdsResult;
  }

  @override
  Future<Map<String, ProductStockLabel>> fetchProductsByIdsForStockLabels(
    AppSession session,
    Set<String> productIds,
  ) async {
    if (!canViewProductsList(session) || productIds.isEmpty) {
      return {};
    }
    if (stockLabelsThrows) {
      throw const ProductsException(code: ProductsException.unknown);
    }
    return {
      for (final id in productIds)
        if (stockLabelsById.containsKey(id)) id: stockLabelsById[id]!,
    };
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
  FakeProductGroupRepository({this.groups = const [], this.fetchThrows = false})
    : super(null);

  List<ProductGroup> groups;
  bool fetchThrows;
  int fetchCount = 0;

  @override
  Future<List<ProductGroup>> fetchProductGroups({
    bool activeOnly = false,
  }) async {
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
    canBeSold: true,
    canBeRented: false,
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
