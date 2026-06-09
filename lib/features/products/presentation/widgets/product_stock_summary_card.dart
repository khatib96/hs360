import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/quantity_formatter.dart';
import '../../../inventory/domain/inventory_balance.dart';
import '../../../inventory/domain/inventory_stock_helpers.dart';
import '../../../inventory/domain/warehouse.dart';
import '../../../inventory/presentation/warehouse_display_helpers.dart';
import '../../domain/product.dart';
import '../../domain/product_stock_summary.dart';

class ProductStockSummaryCard extends StatelessWidget {
  const ProductStockSummaryCard({
    required this.stock,
    required this.product,
    required this.warehouses,
    required this.languageCode,
    required this.l10n,
    super.key,
  });

  final ProductStockSummary stock;
  final Product product;
  final List<Warehouse> warehouses;
  final String languageCode;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final warehousesById = {for (final w in warehouses) w.id: w};
    final low = isLowStock(
      totalAvailable: stock.totalQtyAvailable,
      reorderPoint: product.reorderPoint,
    );

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _Row(
          l10n.productDetailStockTotal,
          formatQuantity(stock.totalQtyAvailable),
          emphasize: low,
        ),
        if (low) ...[
          const SizedBox(height: 12),
          MessageBannerLike(message: l10n.productDetailStockLowWarning),
        ],
        const SizedBox(height: 16),
        Text(
          l10n.productDetailStockByWarehouse,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        if (stock.balances.isEmpty)
          Text(l10n.inventoryBalancesEmpty)
        else
          ...stock.balances.map(
            (balance) => _WarehouseBalanceRow(
              balance: balance,
              warehouse: warehousesById[balance.warehouseId],
              languageCode: languageCode,
              l10n: l10n,
            ),
          ),
      ],
    );
  }
}

class _WarehouseBalanceRow extends StatelessWidget {
  const _WarehouseBalanceRow({
    required this.balance,
    required this.warehouse,
    required this.languageCode,
    required this.l10n,
  });

  final InventoryBalance balance;
  final Warehouse? warehouse;
  final String languageCode;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final warehouseLabel = warehouse != null
        ? localizedWarehouseName(warehouse!, languageCode)
        : '${l10n.inventoryBalanceNameUnavailable} (${_shortId(balance.warehouseId)})';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(warehouseLabel, style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 4),
          _Row(
            l10n.inventoryBalanceAvailable,
            formatQuantity(balance.qtyAvailable),
          ),
          _Row(l10n.inventoryBalanceRented, formatQuantity(balance.qtyRented)),
          _Row(l10n.inventoryBalanceTrial, formatQuantity(balance.qtyTrial)),
          _Row(
            l10n.inventoryBalanceMaintenance,
            formatQuantity(balance.qtyMaintenance),
          ),
          _Row(
            l10n.inventoryBalanceDamaged,
            formatQuantity(balance.qtyDamaged),
          ),
        ],
      ),
    );
  }

  String _shortId(String id) {
    if (id.length <= 8) return id;
    return id.substring(0, 8);
  }
}

class _Row extends StatelessWidget {
  const _Row(this.label, this.value, {this.emphasize = false});

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    final style = emphasize
        ? Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: AppColors.warning,
            fontWeight: FontWeight.w600,
          )
        : Theme.of(context).textTheme.bodyLarge;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(value, style: style),
        ],
      ),
    );
  }
}

/// Lightweight warning strip without importing shared MessageBanner tree in tests.
class MessageBannerLike extends StatelessWidget {
  const MessageBannerLike({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.35)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(12),
        child: Text(
          message,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: AppColors.warning),
        ),
      ),
    );
  }
}
