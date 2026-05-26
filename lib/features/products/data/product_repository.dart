import 'dart:math';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/products_exception.dart';
import '../../../core/network/supabase_providers.dart';
import '../../../domain/validators/product_validator.dart';
import '../../auth/domain/app_session.dart';
import '../domain/product.dart';
import '../domain/product_cost_access.dart';
import '../domain/product_permissions.dart';
import '../domain/product_filters.dart';
import '../domain/product_form_state.dart';
import '../domain/product_stock_label.dart';
import '../domain/product_stock_summary.dart';
import '../../inventory/domain/inventory_balance.dart';

part 'product_repository.g.dart';

@Riverpod(keepAlive: true)
ProductRepository productRepository(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return ProductRepository(client);
}

class ProductRepository {
  ProductRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) throw ProductsException.notConfigured();
    return client;
  }

  Future<List<Product>> fetchProducts(
    ProductFilters filters,
    AppSession session,
  ) async {
    try {
      final table = productReadTableForSession(session);
      final columns = productReadColumnsForSession(session);

      var query = _requireClient.from(table).select(columns);

      final search = filters.search?.trim();
      if (search != null && search.isNotEmpty) {
        final pattern = '%$search%';
        query = query.or(
          'sku.ilike.$pattern,name_ar.ilike.$pattern,'
          'name_en.ilike.$pattern,barcode.ilike.$pattern',
        );
      }
      if (filters.groupId != null) {
        query = query.eq('group_id', filters.groupId!);
      }
      if (filters.productType != null) {
        query = query.eq('product_type', filters.productType!.toDb());
      }
      if (filters.isActive != null) {
        query = query.eq('is_active', filters.isActive!);
      }

      final rows = await query.order('sku');
      var products = (rows as List)
          .map((r) => Product.fromRow(Map<String, dynamic>.from(r)))
          .toList();

      if (filters.stockFilter != null) {
        products = await _applyStockFilter(products, filters.stockFilter!);
      }

      return products;
    } catch (e, st) {
      throw ProductsException.fromSupabase(e, st);
    }
  }

  Future<List<Product>> _applyStockFilter(
    List<Product> products,
    ProductStockFilter filter,
  ) async {
    final result = <Product>[];
    for (final product in products) {
      final summary = await fetchProductStock(product.id);
      final qty = summary.totalQtyAvailable;
      final reorder = product.reorderPoint;

      final matches = switch (filter) {
        ProductStockFilter.inStock => qty > Decimal.zero,
        ProductStockFilter.outOfStock => qty <= Decimal.zero,
        ProductStockFilter.lowStock =>
          reorder != null && qty > Decimal.zero && qty <= reorder,
      };
      if (matches) result.add(product);
    }
    return result;
  }

  Future<Product?> fetchProductById(String id, AppSession session) async {
    try {
      final table = productReadTableForSession(session);
      final columns = productReadColumnsForSession(session);

      final row = await _requireClient
          .from(table)
          .select(columns)
          .eq('id', id)
          .maybeSingle();

      if (row == null) return null;
      return Product.fromRow(Map<String, dynamic>.from(row));
    } catch (e, st) {
      throw ProductsException.fromSupabase(e, st);
    }
  }

  Future<Product> createProduct(
    AppSession session,
    ProductFormState input,
  ) async {
    _validateBeforeWrite(session, input);
    try {
      final canReadCreatedProduct = canViewProductsList(session);
      final createdId = canReadCreatedProduct ? null : _newUuidV4();
      final data = _buildWriteMap(
        session,
        input,
        isCreate: true,
        id: createdId,
      );

      if (!canReadCreatedProduct) {
        await _requireClient.from('products').insert(data);
        return _productFromCreateInput(
          id: createdId!,
          session: session,
          input: input,
        );
      }

      final row = await _requireClient
          .from('products')
          .insert(data)
          .select(productMutationReturnColumnsForSession(session))
          .single();
      return _mapMutationResponse(row, session);
    } catch (e, st) {
      throw ProductsException.fromSupabase(e, st);
    }
  }

  Future<Product> updateProduct(
    AppSession session,
    String id,
    ProductFormState input,
  ) async {
    _validateBeforeWrite(session, input);
    try {
      final data = _buildWriteMap(session, input, isCreate: false);
      final row = await _requireClient
          .from('products')
          .update(data)
          .eq('id', id)
          .select(productMutationReturnColumnsForSession(session))
          .single();
      return _mapMutationResponse(row, session);
    } catch (e, st) {
      throw ProductsException.fromSupabase(e, st);
    }
  }

  Future<void> updateProductImageUrl(
    AppSession session,
    String productId,
    String? imageUrl,
  ) async {
    if (!canEditProduct(session)) {
      throw const ProductsException(code: ProductsException.permissionDenied);
    }
    try {
      await _requireClient
          .from('products')
          .update({'image_url': imageUrl})
          .eq('id', productId);
    } catch (e, st) {
      throw ProductsException.fromSupabase(e, st);
    }
  }

  Future<void> deactivateProduct(AppSession session, String id) async {
    try {
      await _requireClient
          .from('products')
          .update({'is_active': false})
          .eq('id', id);
    } catch (e, st) {
      throw ProductsException.fromSupabase(e, st);
    }
  }

  /// Resolves product IDs for inventory movements search (no [is_active] filter).
  Future<Set<String>> searchProductIdsForInventoryMovements(
    AppSession session,
    String search,
  ) async {
    if (!canViewProductsList(session)) return {};

    final trimmed = search.trim();
    if (trimmed.isEmpty) return {};

    try {
      final table = productReadTableForSession(session);
      final pattern = '%$trimmed%';
      final rows = await _requireClient
          .from(table)
          .select('id')
          .or(
            'sku.ilike.$pattern,name_ar.ilike.$pattern,'
            'name_en.ilike.$pattern',
          );

      return {
        for (final row in rows as List)
          (row as Map<String, dynamic>)['id'] as String,
      };
    } catch (e, st) {
      throw ProductsException.fromSupabase(e, st);
    }
  }

  Future<Map<String, ProductStockLabel>> fetchProductsByIdsForStockLabels(
    AppSession session,
    Set<String> productIds,
  ) async {
    if (!canViewProductsList(session) || productIds.isEmpty) {
      return {};
    }

    try {
      final table = productReadTableForSession(session);
      final columns = productStockLabelColumnsForSession(session);
      final rows = await _requireClient
          .from(table)
          .select(columns)
          .inFilter('id', productIds.toList());

      final map = <String, ProductStockLabel>{};
      for (final row in rows as List) {
        final label = ProductStockLabel.fromRow(
          Map<String, dynamic>.from(row),
        );
        map[label.id] = label;
      }
      return map;
    } catch (e, st) {
      throw ProductsException.fromSupabase(e, st);
    }
  }

  Future<ProductStockSummary> fetchProductStock(String productId) async {
    try {
      final rows = await _requireClient
          .from('inventory_balances')
          .select()
          .eq('product_id', productId);

      final balances = (rows as List)
          .map((r) => InventoryBalance.fromRow(Map<String, dynamic>.from(r)))
          .toList();

      var total = Decimal.zero;
      for (final b in balances) {
        total += b.qtyAvailable;
      }

      return ProductStockSummary(
        productId: productId,
        totalQtyAvailable: total,
        balances: balances,
      );
    } catch (e, st) {
      throw ProductsException.fromSupabase(e, st);
    }
  }

  Future<Product> _mapMutationResponse(
    Map<String, dynamic> row,
    AppSession session,
  ) async {
    if (canViewFullProductCosts(session)) {
      return Product.fromRow(Map<String, dynamic>.from(row));
    }

    final product = await fetchProductById(row['id'] as String, session);
    if (product == null) {
      throw const ProductsException(code: ProductsException.unknown);
    }
    return product;
  }

  void _validateBeforeWrite(AppSession session, ProductFormState input) {
    final productResult = const ProductValidator().validate(input);
    if (!productResult.isValid) {
      throw ProductsException(code: productResult.codes.first);
    }
    assertProductCostWrite(session, input);
  }

  Map<String, dynamic> _buildWriteMap(
    AppSession session,
    ProductFormState input, {
    required bool isCreate,
    String? id,
  }) {
    final map = <String, dynamic>{
      'sku': input.sku.trim(),
      'barcode': input.barcode?.trim(),
      'name_ar': input.nameAr.trim(),
      'name_en': input.nameEn.trim(),
      'description_ar': input.descriptionAr?.trim(),
      'description_en': input.descriptionEn?.trim(),
      'group_id': input.groupId,
      'product_type': input.effectiveProductType.toDb(),
      'can_be_sold': input.canBeSold,
      'can_be_rented': input.canBeRented,
      'unit_primary': input.unitPrimary.toDb(),
      'unit_secondary': input.unitSecondary?.toDb(),
      'conversion_factor': input.conversionFactor.toString(),
      'sale_price': input.canBeSold ? input.salePrice.toString() : '0',
      'rental_price_monthly': null,
      'expected_lifespan_months': input.expectedLifespanMonths,
      'default_oil_ml_per_month': input.defaultOilMlPerMonth?.toString(),
      'is_serialized': input.isSerialized,
      'trackable_for_maintenance': input.trackableForMaintenance,
      'reorder_point': input.reorderPoint?.toString(),
      'is_active': input.isActive,
      'image_url': input.imageUrl,
    };

    if (isCreate) {
      map['tenant_id'] = session.tenantId;
      if (id != null) map['id'] = id;
    }

    if (canWriteProductCosts(session)) {
      if (input.avgCost != null) {
        map['avg_cost'] = input.avgCost!.toString();
      }
      if (input.lastPurchaseCost != null) {
        map['last_purchase_cost'] = input.lastPurchaseCost!.toString();
      }
      if (input.canBeSold && input.minSalePrice != null) {
        map['min_sale_price'] = input.minSalePrice!.toString();
      } else if (!input.canBeSold) {
        map['min_sale_price'] = null;
      }
    }

    return map;
  }

  Product _productFromCreateInput({
    required String id,
    required AppSession session,
    required ProductFormState input,
  }) {
    final canViewCosts = canViewFullProductCosts(session);
    return Product(
      id: id,
      tenantId: session.tenantId,
      sku: input.sku.trim(),
      barcode: input.barcode?.trim(),
      nameAr: input.nameAr.trim(),
      nameEn: input.nameEn.trim(),
      descriptionAr: input.descriptionAr?.trim(),
      descriptionEn: input.descriptionEn?.trim(),
      groupId: input.groupId,
      productType: input.effectiveProductType,
      canBeSold: input.canBeSold,
      canBeRented: input.canBeRented,
      unitPrimary: input.unitPrimary,
      unitSecondary: input.unitSecondary,
      conversionFactor: input.conversionFactor,
      salePrice: input.salePrice,
      minSalePrice: canViewCosts ? input.minSalePrice : null,
      avgCost: canViewCosts ? input.avgCost : null,
      lastPurchaseCost: canViewCosts ? input.lastPurchaseCost : null,
      expectedLifespanMonths: input.expectedLifespanMonths,
      defaultOilMlPerMonth: input.defaultOilMlPerMonth,
      isSerialized: input.isSerialized,
      trackableForMaintenance: input.trackableForMaintenance,
      reorderPoint: input.reorderPoint,
      isActive: input.isActive,
      imageUrl: input.imageUrl,
      createdAt: DateTime.now().toUtc(),
    );
  }

  String _newUuidV4() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hex(int byte) => byte.toRadixString(16).padLeft(2, '0');
    final value = bytes.map(hex).join();
    return '${value.substring(0, 8)}-'
        '${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-'
        '${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }
}
