import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/utils/money_formatter.dart';
import '../../../../core/utils/quantity_formatter.dart';
import '../../domain/product.dart';
import '../../domain/product_stock_summary.dart';
import '../../domain/product_type.dart';
import '../product_display_helpers.dart';

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
          l10n.productFieldType,
          _typeLabel(l10n, product.productType),
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

  String _typeLabel(AppLocalizations l10n, ProductType type) {
    return switch (type) {
      ProductType.saleOnly => l10n.productTypeSaleOnly,
      ProductType.assetRental => l10n.productTypeAssetRental,
      ProductType.consumableRental => l10n.productTypeConsumableRental,
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
        _Row(l10n.productFieldSalePrice, formatMoney(product.salePrice)),
        if (product.rentalPriceMonthly != null)
          _Row(
            l10n.productFieldRentalPrice,
            formatMoney(product.rentalPriceMonthly!),
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

class ProductDetailUnitsSection extends StatelessWidget {
  const ProductDetailUnitsSection({
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
      ],
    );
  }
}

class ProductDetailInventorySection extends StatelessWidget {
  const ProductDetailInventorySection({
    required this.stock,
    required this.unavailable,
    required this.l10n,
    super.key,
  });

  final ProductStockSummary? stock;
  final bool unavailable;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (unavailable) {
      return Center(child: Text(l10n.productDetailStockUnavailable));
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Row(
          l10n.productDetailStockTotal,
          formatQuantity(stock!.totalQtyAvailable),
        ),
      ],
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
