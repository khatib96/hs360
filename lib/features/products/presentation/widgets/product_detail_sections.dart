import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/utils/money_formatter.dart';
import '../../../auth/domain/app_session.dart';
import '../../domain/product.dart';
import '../../domain/product_stock_summary.dart';
import '../../domain/product_type.dart';
import '../../domain/product_unit_permissions.dart';
import '../product_detail_controller.dart';
import '../../../inventory/domain/warehouse.dart';
import '../product_display_helpers.dart';
import 'product_stock_summary_card.dart';
import '../products_error_messages.dart';
import 'add_product_unit_dialog.dart';
import 'bulk_product_units_dialog.dart';
import 'product_unit_table.dart';

class ProductDetailOverviewSection extends StatelessWidget {
  const ProductDetailOverviewSection({
    required this.product,
    required this.groupLabel,
    required this.languageCode,
    required this.l10n,
    super.key,
  });

  final Product product;
  final String groupLabel;
  final String languageCode;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Row(l10n.productFieldSku, product.sku),
        _Row(l10n.productFieldGroup, groupLabel),
        _Row(
          l10n.productFieldMode,
          _modeLabel(l10n, product),
        ),
        if (product.canBeRented)
          _Row(
            l10n.productFieldRentalType,
            _rentalTypeLabel(l10n, product.productType),
          ),
        if (product.barcode != null && product.barcode!.isNotEmpty)
          _Row(l10n.productFieldBarcode, product.barcode!),
        _Row(
          l10n.productFieldActive,
          product.isActive
              ? l10n.productStatusActive
              : l10n.productStatusInactive,
        ),
        if (product.descriptionAr != null || product.descriptionEn != null) ...[
          const SizedBox(height: 12),
          Text(
            localizedProductName(product, languageCode),
            style: theme.textTheme.titleMedium,
          ),
        ],
      ],
    );
  }

  String _modeLabel(AppLocalizations l10n, Product product) {
    if (product.canBeSold && product.canBeRented) {
      return '${l10n.productModeSale} + ${l10n.productModeRental}';
    }
    if (product.canBeRented) return l10n.productModeRental;
    return l10n.productModeSale;
  }

  String _rentalTypeLabel(AppLocalizations l10n, ProductType type) {
    return switch (type) {
      ProductType.assetRental => l10n.productRentalTypeAsset,
      ProductType.consumableRental => l10n.productRentalTypeConsumable,
      ProductType.saleOnly => l10n.productsNotAvailable,
    };
  }
}

class ProductDetailPricingSection extends StatelessWidget {
  const ProductDetailPricingSection({
    required this.product,
    required this.canViewCosts,
    required this.l10n,
    super.key,
  });

  final Product product;
  final bool canViewCosts;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (product.canBeSold)
          _Row(l10n.productFieldSalePrice, formatMoney(product.salePrice)),
        if (product.canBeRented &&
            product.productType == ProductType.assetRental &&
            product.expectedLifespanMonths != null)
          _Row(
            l10n.productFieldExpectedLifespan,
            product.expectedLifespanMonths!.toString(),
          ),
        if (canViewCosts) ...[
          if (product.minSalePrice != null)
            _Row(
              l10n.productFieldMinSalePrice,
              formatMoney(product.minSalePrice!),
            ),
          if (product.avgCost != null)
            _Row(l10n.productFieldAvgCost, formatMoney(product.avgCost!)),
          if (product.lastPurchaseCost != null)
            _Row(
              l10n.productFieldLastPurchaseCost,
              formatMoney(product.lastPurchaseCost!),
            ),
        ],
      ],
    );
  }
}

class ProductDetailUnitsSection extends ConsumerWidget {
  const ProductDetailUnitsSection({
    required this.productId,
    required this.product,
    required this.languageCode,
    required this.l10n,
    required this.canViewCosts,
    required this.session,
    super.key,
  });

  final String productId;
  final Product product;
  final String languageCode;
  final AppLocalizations l10n;
  final bool canViewCosts;
  final AppSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!product.isSerialized) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Row(l10n.productFieldUnitPrimary, unitOfMeasureLabel(product.unitPrimary)),
          _Row(
            l10n.productFieldUnitSecondary,
            product.unitSecondary != null
                ? unitOfMeasureLabel(product.unitSecondary!)
                : l10n.productNoSecondaryUnit,
          ),
          _Row(
            l10n.productFieldConversionFactor,
            product.conversionFactor.toString(),
          ),
          _Row(
            l10n.productFieldSerialized,
            product.isSerialized ? l10n.productStatusActive : l10n.productsNotAvailable,
          ),
          const SizedBox(height: 16),
          Text(l10n.productUnitsNotSerialized),
        ],
      );
    }

    final state = ref.watch(productDetailControllerProvider(productId));
    final controller =
        ref.read(productDetailControllerProvider(productId).notifier);

    if (!canViewProductUnits(session)) {
      return Center(child: Text(l10n.productUnitsViewDenied));
    }

    if (state.unitsLoading && state.units.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final canCreate = canCreateProductUnits(session);
    final canEdit = canEditProductUnits(session);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (canCreate)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Wrap(
              spacing: 8,
              children: [
                FilledButton.icon(
                  onPressed: state.warehouses.isEmpty
                      ? null
                      : () => _onAdd(context, ref, controller),
                  icon: const Icon(Icons.add),
                  label: Text(l10n.productUnitAdd),
                ),
                OutlinedButton.icon(
                  onPressed: state.warehouses.isEmpty
                      ? null
                      : () => _onBulk(context, ref, controller),
                  icon: const Icon(Icons.playlist_add),
                  label: Text(l10n.productUnitBulkAdd),
                ),
              ],
            ),
          ),
        if (state.unitsErrorCode != null)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              productsErrorMessage(l10n, state.unitsErrorCode!),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(
          child: ProductUnitTable(
            units: state.units,
            languageCode: languageCode,
            canViewCosts: canViewCosts,
            canEdit: canEdit,
            l10n: l10n,
            onEdit: (unitId, result) async {
              final code = await controller.updateUnitSafe(
                productId: productId,
                unitId: unitId,
                input: result.input,
              );
              if (code != null && context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(productsErrorMessage(l10n, code))),
                );
              }
              return code;
            },
          ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.productUnitSectionHistory,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(l10n.productUnitsHistoryEmpty),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _onAdd(
    BuildContext context,
    WidgetRef ref,
    ProductDetailController controller,
  ) async {
    final state = ref.read(productDetailControllerProvider(productId));
    final result = await showAddProductUnitDialog(
      context: context,
      warehouses: state.warehouses,
      languageCode: languageCode,
      canViewCosts: canViewCosts,
      l10n: l10n,
    );
    if (result == null || !context.mounted) return;

    final code = await controller.addUnit(
      productId: productId,
      warehouseId: result.warehouseId,
      input: result.input,
    );
    if (code != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(productsErrorMessage(l10n, code))),
      );
    }
  }

  Future<void> _onBulk(
    BuildContext context,
    WidgetRef ref,
    ProductDetailController controller,
  ) async {
    final state = ref.read(productDetailControllerProvider(productId));
    final result = await showBulkProductUnitsDialog(
      context: context,
      warehouses: state.warehouses,
      languageCode: languageCode,
      canViewCosts: canViewCosts,
      l10n: l10n,
    );
    if (result == null || !context.mounted) return;

    final code = await controller.bulkAddUnits(
      productId: productId,
      warehouseId: result.warehouseId,
      units: result.units,
    );
    if (code != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(productsErrorMessage(l10n, code))),
      );
    }
  }
}

class ProductDetailInventorySection extends StatelessWidget {
  const ProductDetailInventorySection({
    required this.product,
    required this.stock,
    required this.warehouses,
    required this.unavailable,
    required this.languageCode,
    required this.l10n,
    super.key,
  });

  final Product product;
  final ProductStockSummary? stock;
  final List<Warehouse> warehouses;
  final bool unavailable;
  final String languageCode;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (unavailable) {
      return Center(child: Text(l10n.productDetailStockUnavailable));
    }
    return ProductStockSummaryCard(
      stock: stock!,
      product: product,
      warehouses: warehouses,
      languageCode: languageCode,
      l10n: l10n,
    );
  }
}

class ProductDetailAuditSection extends StatelessWidget {
  const ProductDetailAuditSection({
    required this.product,
    required this.l10n,
    super.key,
  });

  final Product product;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (product.createdAt != null)
          _Row(l10n.productDetailCreatedAt, _formatDate(product.createdAt!)),
        if (product.updatedAt != null)
          _Row(l10n.productDetailUpdatedAt, _formatDate(product.updatedAt!)),
      ],
    );
  }

  String _formatDate(DateTime dt) =>
      '${dt.year}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 2,
            child: Text(label, style: Theme.of(context).textTheme.bodySmall),
          ),
          Expanded(
            flex: 3,
            child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
