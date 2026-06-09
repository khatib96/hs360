import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/product_cost_access.dart';
import '../domain/product_permissions.dart';
import 'product_detail_controller.dart';
import 'product_display_helpers.dart';
import 'product_list_permissions.dart';
import 'products_error_messages.dart';
import 'widgets/product_detail_sections.dart';
import 'widgets/product_image_picker.dart';
import 'widgets/product_list_badges.dart';

class ProductDetailScreen extends ConsumerWidget {
  const ProductDetailScreen({required this.productId, super.key});

  final String productId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final languageCode = locale.languageCode;
    final session = ref.watch(authControllerProvider).valueOrNull;
    final state = ref.watch(productDetailControllerProvider(productId));
    final controller = ref.read(
      productDetailControllerProvider(productId).notifier,
    );

    final canEdit = session != null && canEditProduct(session);
    final canViewCosts = session != null && canViewFullProductCosts(session);
    final canViewStock = session != null && canViewProductStock(session);

    String groupLabel = l10n.productsGroupUnavailable;
    if (session != null && canViewProductGroups(session)) {
      for (final group in state.groups) {
        if (group.id == state.product?.groupId) {
          groupLabel = localizedGroupName(group, languageCode);
          break;
        }
      }
    }

    Widget body;
    if (state.isLoading) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.loading),
          ],
        ),
      );
    } else if (state.notFound) {
      body = Center(child: Text(l10n.productDetailNotFound));
    } else if (state.errorCode != null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(productsErrorMessage(l10n, state.errorCode!)),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => controller.load(productId),
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    } else {
      final product = state.product!;
      body = DefaultTabController(
        length: 5,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ProductImagePicker(
                    imageUrl: product.imageUrl,
                    canEdit: canEdit,
                    isUploading: state.isUploadingImage,
                    addLabel: l10n.productImageAdd,
                    changeLabel: l10n.productImageChange,
                    uploadingLabel: l10n.productImageUploading,
                    onPick: (file) async {
                      final bytes = await file.readAsBytes();
                      await controller.uploadImage(
                        productId: productId,
                        bytes: bytes,
                        mimeType: file.mimeType,
                        fileExtension: file.name.split('.').last,
                      );
                    },
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          localizedProductName(product, languageCode),
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${l10n.productFieldSku}: ${product.sku}',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          children: [
                            ProductTypeBadge(
                              type: product.productType,
                              canBeSold: product.canBeSold,
                              canBeRented: product.canBeRented,
                            ),
                            ProductActiveBadge(isActive: product.isActive),
                          ],
                        ),
                        if (state.imageErrorCode != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            productsErrorMessage(l10n, state.imageErrorCode!),
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.error,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            TabBar(
              isScrollable: true,
              tabs: [
                Tab(text: l10n.productSectionOverview),
                Tab(text: l10n.productSectionPricing),
                Tab(text: l10n.productSectionUnits),
                Tab(text: l10n.productSectionInventory),
                Tab(text: l10n.productSectionAudit),
              ],
            ),
            Expanded(
              child: TabBarView(
                children: [
                  ProductDetailOverviewSection(
                    product: product,
                    groupLabel: groupLabel,
                    languageCode: languageCode,
                    l10n: l10n,
                  ),
                  ProductDetailPricingSection(
                    product: product,
                    canViewCosts: canViewCosts,
                    l10n: l10n,
                  ),
                  ProductDetailUnitsSection(
                    productId: productId,
                    product: product,
                    languageCode: languageCode,
                    l10n: l10n,
                    canViewCosts: canViewCosts,
                    session: session!,
                  ),
                  ProductDetailInventorySection(
                    product: product,
                    stock: state.stockSummary,
                    warehouses: state.stockWarehouses,
                    unavailable: !canViewStock || state.stockUnavailable,
                    languageCode: languageCode,
                    l10n: l10n,
                  ),
                  ProductDetailAuditSection(product: product, l10n: l10n),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final actions = <Widget>[];
    if (canEdit && state.product != null) {
      actions.add(
        TextButton(
          onPressed: () => context.go('/products/$productId/edit'),
          child: Text(l10n.productEditAction),
        ),
      );
    }

    return AppShell(
      title: l10n.productsDetail,
      currentRoute: '/products/$productId',
      actions: actions,
      body: body,
    );
  }
}
