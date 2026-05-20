import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/quantity_formatter.dart';
import '../../domain/product_stock_summary.dart';
import '../../domain/product_type.dart';

class ProductTypeBadge extends StatelessWidget {
  const ProductTypeBadge({required this.type, super.key});

  final ProductType type;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = switch (type) {
      ProductType.saleOnly => l10n.productTypeSaleOnly,
      ProductType.assetRental => l10n.productTypeAssetRental,
      ProductType.consumableRental => l10n.productTypeConsumableRental,
    };

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.goldSoft.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(label, style: Theme.of(context).textTheme.labelSmall),
    );
  }
}

class ProductActiveBadge extends StatelessWidget {
  const ProductActiveBadge({required this.isActive, super.key});

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final label = isActive ? l10n.productStatusActive : l10n.productStatusInactive;
    final color = isActive ? AppColors.success : AppColors.neutral600;

    return Container(
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: color),
      ),
    );
  }
}

class ProductStockBadge extends StatelessWidget {
  const ProductStockBadge({
    required this.canViewStock,
    this.summary,
    this.reorderPoint,
    super.key,
  });

  final bool canViewStock;
  final ProductStockSummary? summary;
  final Decimal? reorderPoint;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    if (!canViewStock) {
      return Text(l10n.productsNotAvailable, style: _mutedStyle(context));
    }

    if (summary == null) {
      return Text(l10n.productsNotAvailable, style: _mutedStyle(context));
    }

    final qty = summary!.totalQtyAvailable;
    if (qty <= Decimal.zero) {
      return Text(l10n.productStockOut, style: _mutedStyle(context));
    }

    if (reorderPoint != null && qty <= reorderPoint!) {
      return Text(
        '${l10n.productStockLow} (${formatQuantity(qty)})',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: AppColors.warning,
            ),
      );
    }

    return Text(
      '${l10n.productStockIn} (${formatQuantity(qty)})',
      style: Theme.of(context).textTheme.labelSmall,
    );
  }

  TextStyle? _mutedStyle(BuildContext context) =>
      Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.neutral600);
}

/// Em dash placeholder for unavailable numeric cells.
class ProductEmDashCell extends StatelessWidget {
  const ProductEmDashCell({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Text(
      l10n.productsNotAvailable,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.neutral600,
          ),
    );
  }
}
