import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../core/routing/route_guards.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/product_cost_access.dart';
import 'product_form_controller.dart';
import 'product_form_draft.dart';
import 'products_error_messages.dart';
import 'widgets/product_wizard_steps.dart';

class ProductWizardScreen extends ConsumerStatefulWidget {
  const ProductWizardScreen({this.productId, super.key});

  final String? productId;

  @override
  ConsumerState<ProductWizardScreen> createState() =>
      _ProductWizardScreenState();
}

class _ProductWizardScreenState extends ConsumerState<ProductWizardScreen> {
  final _nameAr = TextEditingController();
  final _nameEn = TextEditingController();
  final _conversion = TextEditingController();
  final _salePrice = TextEditingController();
  final _minSalePrice = TextEditingController();
  final _avgCost = TextEditingController();
  final _lastPurchase = TextEditingController();
  final _expectedLifespan = TextEditingController();
  final _barcode = TextEditingController();
  final _reorder = TextEditingController();

  @override
  void dispose() {
    _nameAr.dispose();
    _nameEn.dispose();
    _conversion.dispose();
    _salePrice.dispose();
    _minSalePrice.dispose();
    _avgCost.dispose();
    _lastPurchase.dispose();
    _expectedLifespan.dispose();
    _barcode.dispose();
    _reorder.dispose();
    super.dispose();
  }

  void _bindControllers(ProductFormDraft draft) {
    if (_nameAr.text != draft.nameAr) _nameAr.text = draft.nameAr;
    if (_nameEn.text != draft.nameEn) _nameEn.text = draft.nameEn;
    if (_conversion.text != draft.conversionFactor) {
      _conversion.text = draft.conversionFactor;
    }
    if (_salePrice.text != draft.salePrice) _salePrice.text = draft.salePrice;
    if (_minSalePrice.text != (draft.minSalePrice ?? '')) {
      _minSalePrice.text = draft.minSalePrice ?? '';
    }
    if (_avgCost.text != (draft.avgCost ?? '')) {
      _avgCost.text = draft.avgCost ?? '';
    }
    if (_lastPurchase.text != (draft.lastPurchaseCost ?? '')) {
      _lastPurchase.text = draft.lastPurchaseCost ?? '';
    }
    if (_expectedLifespan.text != draft.expectedLifespanMonths) {
      _expectedLifespan.text = draft.expectedLifespanMonths;
    }
    if (_barcode.text != (draft.barcode ?? '')) {
      _barcode.text = draft.barcode ?? '';
    }
    if (_reorder.text != (draft.reorderPoint ?? '')) {
      _reorder.text = draft.reorderPoint ?? '';
    }
  }

  ProductFormDraft _draftFromControllers(ProductFormDraft base) {
    return ProductFormDraft(
      barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
      nameAr: _nameAr.text,
      nameEn: _nameEn.text,
      groupId: base.groupId,
      productType: base.productType,
      canBeSold: base.canBeSold,
      canBeRented: base.canBeRented,
      unitPrimary: base.unitPrimary,
      unitSecondary: base.unitSecondary,
      conversionFactor: _conversion.text,
      salePrice: _salePrice.text,
      minSalePrice: _minSalePrice.text.trim().isEmpty
          ? null
          : _minSalePrice.text,
      avgCost: _avgCost.text.trim().isEmpty ? null : _avgCost.text,
      lastPurchaseCost: _lastPurchase.text.trim().isEmpty
          ? null
          : _lastPurchase.text,
      expectedLifespanMonths: _expectedLifespan.text,
      reorderPoint: _reorder.text.trim().isEmpty ? null : _reorder.text,
      isSerialized: base.isSerialized,
      trackableForMaintenance: base.trackableForMaintenance,
      isActive: base.isActive,
      imageUrl: base.imageUrl,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final session = ref.watch(authControllerProvider).valueOrNull;
    final productId = widget.productId;
    final state = ref.watch(
      productFormControllerProvider(productId: productId),
    );
    final notifier = ref.read(
      productFormControllerProvider(productId: productId).notifier,
    );

    _bindControllers(state.draft);

    final canWriteCosts = session != null && canWriteProductCosts(session);
    final canViewCosts = session != null && canViewFullProductCosts(session);

    final stepLabels = [
      l10n.productWizardStepIdentity,
      l10n.productWizardStepUnits,
      l10n.productWizardStepPricing,
      l10n.productWizardStepFlags,
      l10n.productWizardStepReview,
    ];

    Widget stepBody;
    if (state.isLoading) {
      stepBody = Center(child: Text(l10n.loading));
    } else {
      void onChanged(ProductFormDraft d) {
        notifier.updateDraft(_draftFromControllers(d));
      }

      stepBody = switch (state.stepIndex) {
        0 => ProductWizardIdentityStep(
          draft: state.draft,
          groups: state.groups,
          languageCode: locale.languageCode,
          canSelectGroup: state.canSelectGroup,
          isEdit: state.isEdit,
          onChanged: onChanged,
          nameArController: _nameAr,
          nameEnController: _nameEn,
        ),
        1 => ProductWizardUnitsStep(
          draft: state.draft,
          onChanged: onChanged,
          conversionController: _conversion,
        ),
        2 => ProductWizardPricingStep(
          draft: state.draft,
          canWriteCosts: canWriteCosts,
          onChanged: onChanged,
          salePriceController: _salePrice,
          minSalePriceController: _minSalePrice,
          avgCostController: _avgCost,
          lastPurchaseController: _lastPurchase,
        ),
        3 => ProductWizardFlagsStep(
          draft: state.draft,
          canChangeSerialized: state.canChangeSerialized,
          onChanged: onChanged,
          barcodeController: _barcode,
          expectedLifespanController: _expectedLifespan,
          reorderController: _reorder,
        ),
        _ => ProductWizardReviewStep(
          draft: state.draft,
          canViewCosts: canViewCosts,
          l10n: l10n,
        ),
      };
    }

    return AppShell(
      title: state.isEdit ? l10n.productsEdit : l10n.productWizardCreateTitle,
      currentRoute: state.isEdit
          ? '/products/${state.productId}/edit'
          : AppRoutes.productsNew,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LinearProgressIndicator(
            value: (state.stepIndex + 1) / stepLabels.length,
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              stepLabels[state.stepIndex.clamp(0, stepLabels.length - 1)],
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          if (state.errorCode != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                productsErrorMessage(l10n, state.errorCode!),
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(child: stepBody),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (state.stepIndex > 0)
                  OutlinedButton(
                    onPressed: state.isSubmitting
                        ? null
                        : () {
                            notifier.setStep(state.stepIndex - 1);
                          },
                    child: Text(l10n.productWizardBack),
                  ),
                const Spacer(),
                FilledButton(
                  onPressed: state.isSubmitting
                      ? null
                      : () async {
                          notifier.updateDraft(
                            _draftFromControllers(state.draft),
                          );
                          if (state.stepIndex < stepLabels.length - 1) {
                            if (!notifier.validateCurrentStep()) return;
                            notifier.setStep(state.stepIndex + 1);
                            return;
                          }
                          if (!notifier.validateCurrentStep()) return;
                          final result = await notifier.submit();
                          if (!context.mounted || result == null) return;
                          final s = ref
                              .read(authControllerProvider)
                              .valueOrNull;
                          if (result.isCreate) {
                            if (s != null &&
                                (s.isManager ||
                                    s.permissions.can('products.view'))) {
                              context.go('/products/${result.product.id}');
                            } else {
                              context.go(resolveHomeRoute(s!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    l10n.productCreatedSuccess(
                                      result.product.nameAr,
                                    ),
                                  ),
                                ),
                              );
                            }
                          } else {
                            context.go('/products/${result.product.id}');
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.productSavedSuccess)),
                            );
                          }
                        },
                  child: state.isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          state.stepIndex < stepLabels.length - 1
                              ? l10n.productWizardNext
                              : l10n.productWizardSubmit,
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
