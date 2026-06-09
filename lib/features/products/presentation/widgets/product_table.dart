import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/utils/money_formatter.dart';
import '../../domain/product.dart';
import '../../domain/product_stock_summary.dart';
import '../product_display_helpers.dart';
import 'product_list_badges.dart';

class ProductTable extends StatelessWidget {
  const ProductTable({
    required this.products,
    required this.stockByProductId,
    required this.groupLabelFor,
    required this.canViewCosts,
    required this.canViewStock,
    required this.languageCode,
    super.key,
  });

  final List<Product> products;
  final Map<String, ProductStockSummary> stockByProductId;
  final String Function(String groupId) groupLabelFor;
  final bool canViewCosts;
  final bool canViewStock;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width > 768;

    if (isWide) {
      return _DesktopProductTable(
        products: products,
        stockByProductId: stockByProductId,
        groupLabelFor: groupLabelFor,
        canViewCosts: canViewCosts,
        canViewStock: canViewStock,
        languageCode: languageCode,
      );
    }

    return _MobileProductList(
      products: products,
      stockByProductId: stockByProductId,
      groupLabelFor: groupLabelFor,
      canViewCosts: canViewCosts,
      canViewStock: canViewStock,
      languageCode: languageCode,
    );
  }
}

class _DesktopProductTable extends StatefulWidget {
  const _DesktopProductTable({
    required this.products,
    required this.stockByProductId,
    required this.groupLabelFor,
    required this.canViewCosts,
    required this.canViewStock,
    required this.languageCode,
  });

  final List<Product> products;
  final Map<String, ProductStockSummary> stockByProductId;
  final String Function(String groupId) groupLabelFor;
  final bool canViewCosts;
  final bool canViewStock;
  final String languageCode;

  @override
  State<_DesktopProductTable> createState() => _DesktopProductTableState();
}

class _DesktopProductTableState extends State<_DesktopProductTable> {
  final _verticalController = ScrollController();
  final _horizontalController = ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scrollbar(
      controller: _verticalController,
      child: SingleChildScrollView(
        controller: _verticalController,
        child: SingleChildScrollView(
          controller: _horizontalController,
          scrollDirection: Axis.horizontal,
          child: DataTable(
            showCheckboxColumn: false,
            headingTextStyle: Theme.of(
              context,
            ).textTheme.labelMedium?.copyWith(fontWeight: FontWeight.w600),
            columns: [
              DataColumn(label: Text(l10n.productColumnSku)),
              DataColumn(label: Text(l10n.productColumnName)),
              DataColumn(label: Text(l10n.productColumnGroup)),
              DataColumn(label: Text(l10n.productColumnType)),
              DataColumn(label: Text(l10n.productColumnSalePrice)),
              DataColumn(label: Text(l10n.productColumnStock)),
              DataColumn(label: Text(l10n.productColumnActive)),
              if (widget.canViewCosts) ...[
                DataColumn(label: Text(l10n.productColumnAvgCost)),
                DataColumn(label: Text(l10n.productColumnLastPurchaseCost)),
                DataColumn(label: Text(l10n.productColumnMinSalePrice)),
              ],
            ],
            rows: widget.products.map((product) {
              return DataRow(
                onSelectChanged: (_) => context.go('/products/${product.id}'),
                cells: [
                  DataCell(Text(product.sku)),
                  DataCell(
                    Text(localizedProductName(product, widget.languageCode)),
                  ),
                  DataCell(Text(widget.groupLabelFor(product.groupId))),
                  DataCell(
                    ProductTypeBadge(
                      type: product.productType,
                      canBeSold: product.canBeSold,
                      canBeRented: product.canBeRented,
                    ),
                  ),
                  DataCell(Text(_formatMoney(product.salePrice))),
                  DataCell(
                    ProductStockBadge(
                      canViewStock: widget.canViewStock,
                      summary: widget.stockByProductId[product.id],
                      reorderPoint: product.reorderPoint,
                    ),
                  ),
                  DataCell(ProductActiveBadge(isActive: product.isActive)),
                  if (widget.canViewCosts) ...[
                    DataCell(_optionalMoney(product.avgCost)),
                    DataCell(_optionalMoney(product.lastPurchaseCost)),
                    DataCell(_optionalMoney(product.minSalePrice)),
                  ],
                ],
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  String _formatMoney(Decimal value) {
    return _formatMoneyForLanguage(value, widget.languageCode);
  }

  Widget _optionalMoney(Decimal? value) {
    if (value == null) return const ProductEmDashCell();
    return Text(_formatMoney(value));
  }
}

class _MobileProductList extends StatelessWidget {
  const _MobileProductList({
    required this.products,
    required this.stockByProductId,
    required this.groupLabelFor,
    required this.canViewCosts,
    required this.canViewStock,
    required this.languageCode,
  });

  final List<Product> products;
  final Map<String, ProductStockSummary> stockByProductId;
  final String Function(String groupId) groupLabelFor;
  final bool canViewCosts;
  final bool canViewStock;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.zero,
      itemCount: products.length,
      separatorBuilder: (context, index) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final product = products[index];
        return ListTile(
          title: Text(localizedProductName(product, languageCode)),
          subtitle: _MobileProductSubtitle(
            product: product,
            groupLabel: groupLabelFor(product.groupId),
            canViewCosts: canViewCosts,
            languageCode: languageCode,
          ),
          trailing: ProductStockBadge(
            canViewStock: canViewStock,
            summary: stockByProductId[product.id],
            reorderPoint: product.reorderPoint,
          ),
          onTap: () => context.go('/products/${product.id}'),
        );
      },
    );
  }
}

class _MobileProductSubtitle extends StatelessWidget {
  const _MobileProductSubtitle({
    required this.product,
    required this.groupLabel,
    required this.canViewCosts,
    required this.languageCode,
  });

  final Product product;
  final String groupLabel;
  final bool canViewCosts;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Padding(
      padding: const EdgeInsetsDirectional.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${product.sku} - $groupLabel'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ProductTypeBadge(
                type: product.productType,
                canBeSold: product.canBeSold,
                canBeRented: product.canBeRented,
              ),
              ProductActiveBadge(isActive: product.isActive),
              Text(
                '${l10n.productColumnSalePrice}: '
                '${_formatMoneyForLanguage(product.salePrice, languageCode)}',
              ),
              if (canViewCosts) ...[
                Text(
                  '${l10n.productColumnAvgCost}: '
                  '${_optionalMoneyText(context, product.avgCost, languageCode)}',
                ),
                Text(
                  '${l10n.productColumnLastPurchaseCost}: '
                  '${_optionalMoneyText(context, product.lastPurchaseCost, languageCode)}',
                ),
                Text(
                  '${l10n.productColumnMinSalePrice}: '
                  '${_optionalMoneyText(context, product.minSalePrice, languageCode)}',
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

String _formatMoneyForLanguage(Decimal value, String languageCode) {
  return formatMoney(value, locale: languageCode);
}

String _optionalMoneyText(
  BuildContext context,
  Decimal? value,
  String languageCode,
) {
  if (value == null) return AppLocalizations.of(context)!.productsNotAvailable;
  return _formatMoneyForLanguage(value, languageCode);
}
