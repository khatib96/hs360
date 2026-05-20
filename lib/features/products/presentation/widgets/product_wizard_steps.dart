import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../shared/widgets/app_text_field.dart';
import '../../domain/product_group.dart';
import '../../domain/product_type.dart';
import '../../domain/unit_of_measure.dart';
import '../product_display_helpers.dart';
import '../product_form_draft.dart';

class ProductWizardIdentityStep extends StatelessWidget {
  const ProductWizardIdentityStep({
    required this.draft,
    required this.groups,
    required this.languageCode,
    required this.canSelectGroup,
    required this.isEdit,
    required this.onChanged,
    required this.skuController,
    required this.nameArController,
    required this.nameEnController,
    super.key,
  });

  final ProductFormDraft draft;
  final List<ProductGroup> groups;
  final String languageCode;
  final bool canSelectGroup;
  final bool isEdit;
  final ValueChanged<ProductFormDraft> onChanged;
  final TextEditingController skuController;
  final TextEditingController nameArController;
  final TextEditingController nameEnController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (!canSelectGroup && !isEdit)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: MaterialBanner(
              content: Text(l10n.productGroupsPermissionRequired),
              actions: [const SizedBox.shrink()],
            ),
          ),
        AppTextField(
          label: l10n.productFieldSku,
          controller: skuController,
          onFieldSubmitted: (_) => _sync(onChanged),
        ),
        const SizedBox(height: 12),
        AppTextField(label: l10n.productFieldNameAr, controller: nameArController),
        const SizedBox(height: 12),
        AppTextField(label: l10n.productFieldNameEn, controller: nameEnController),
        const SizedBox(height: 12),
        if (canSelectGroup)
          DropdownButtonFormField<String>(
            initialValue: draft.groupId.isEmpty ? null : draft.groupId,
            decoration: InputDecoration(labelText: l10n.productFieldGroup),
            items: groups
                .map(
                  (g) => DropdownMenuItem(
                    value: g.id,
                    child: Text(localizedGroupName(g, languageCode)),
                  ),
                )
                .toList(),
            onChanged: (v) {
              if (v == null) return;
              onChanged(draft..groupId = v);
            },
          )
        else if (isEdit)
          ListTile(
            title: Text(l10n.productFieldGroup),
            subtitle: Text(l10n.productsGroupUnavailable),
          ),
        const SizedBox(height: 12),
        DropdownButtonFormField<ProductType>(
          initialValue: draft.productType,
          decoration: InputDecoration(labelText: l10n.productFieldType),
          items: ProductType.values
              .map(
                (t) => DropdownMenuItem(
                  value: t,
                  child: Text(_typeLabel(l10n, t)),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            onChanged(draft..productType = v);
          },
        ),
      ],
    );
  }

  void _sync(ValueChanged<ProductFormDraft> onChanged) {
    onChanged(
      draft
        ..sku = skuController.text
        ..nameAr = nameArController.text
        ..nameEn = nameEnController.text,
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

class ProductWizardUnitsStep extends StatelessWidget {
  const ProductWizardUnitsStep({
    required this.draft,
    required this.onChanged,
    required this.conversionController,
    super.key,
  });

  final ProductFormDraft draft;
  final ValueChanged<ProductFormDraft> onChanged;
  final TextEditingController conversionController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        DropdownButtonFormField<UnitOfMeasure>(
          initialValue: draft.unitPrimary,
          decoration: InputDecoration(labelText: l10n.productFieldUnitPrimary),
          items: UnitOfMeasure.values
              .map(
                (u) => DropdownMenuItem(
                  value: u,
                  child: Text(unitOfMeasureLabel(u)),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            onChanged(draft..unitPrimary = v);
          },
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<UnitOfMeasure?>(
          initialValue: draft.unitSecondary,
          decoration:
              InputDecoration(labelText: l10n.productFieldUnitSecondary),
          items: [
            DropdownMenuItem<UnitOfMeasure?>(
              value: null,
              child: Text(l10n.productNoSecondaryUnit),
            ),
            ...UnitOfMeasure.values.map(
              (u) => DropdownMenuItem(value: u, child: Text(unitOfMeasureLabel(u))),
            ),
          ],
          onChanged: (v) {
            onChanged(
              draft
                ..unitSecondary = v
                ..conversionFactor = v == null ? '1' : draft.conversionFactor,
            );
          },
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: l10n.productFieldConversionFactor,
          controller: conversionController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
      ],
    );
  }
}

class ProductWizardPricingStep extends StatelessWidget {
  const ProductWizardPricingStep({
    required this.draft,
    required this.canWriteCosts,
    required this.onChanged,
    required this.salePriceController,
    required this.rentalPriceController,
    required this.minSalePriceController,
    required this.avgCostController,
    required this.lastPurchaseController,
    super.key,
  });

  final ProductFormDraft draft;
  final bool canWriteCosts;
  final ValueChanged<ProductFormDraft> onChanged;
  final TextEditingController salePriceController;
  final TextEditingController rentalPriceController;
  final TextEditingController minSalePriceController;
  final TextEditingController avgCostController;
  final TextEditingController lastPurchaseController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppTextField(
          label: l10n.productFieldSalePrice,
          controller: salePriceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        if (draft.productType.isRental) ...[
          const SizedBox(height: 12),
          AppTextField(
            label: l10n.productFieldRentalPrice,
            controller: rentalPriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
        if (canWriteCosts) ...[
          const SizedBox(height: 12),
          AppTextField(
            label: l10n.productFieldMinSalePrice,
            controller: minSalePriceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: l10n.productFieldAvgCost,
            controller: avgCostController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
          const SizedBox(height: 12),
          AppTextField(
            label: l10n.productFieldLastPurchaseCost,
            controller: lastPurchaseController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          ),
        ],
      ],
    );
  }
}

class ProductWizardFlagsStep extends StatelessWidget {
  const ProductWizardFlagsStep({
    required this.draft,
    required this.canChangeSerialized,
    required this.onChanged,
    required this.barcodeController,
    required this.reorderController,
    super.key,
  });

  final ProductFormDraft draft;
  final bool canChangeSerialized;
  final ValueChanged<ProductFormDraft> onChanged;
  final TextEditingController barcodeController;
  final TextEditingController reorderController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AppTextField(label: l10n.productFieldBarcode, controller: barcodeController),
        const SizedBox(height: 8),
        SwitchListTile(
          title: Text(l10n.productFieldSerialized),
          subtitle: !canChangeSerialized
              ? Text(l10n.productSerializedLocked)
              : null,
          value: draft.isSerialized,
          onChanged: canChangeSerialized
              ? (v) => onChanged(
                    draft
                      ..isSerialized = v
                      ..unitPrimary =
                          v ? UnitOfMeasure.piece : draft.unitPrimary,
                  )
              : null,
        ),
        SwitchListTile(
          title: Text(l10n.productFieldMaintenance),
          value: draft.trackableForMaintenance,
          onChanged: (v) => onChanged(draft..trackableForMaintenance = v),
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: l10n.productFieldReorderPoint,
          controller: reorderController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        SwitchListTile(
          title: Text(l10n.productFieldActive),
          value: draft.isActive,
          onChanged: (v) => onChanged(draft..isActive = v),
        ),
      ],
    );
  }
}

class ProductWizardReviewStep extends StatelessWidget {
  const ProductWizardReviewStep({
    required this.draft,
    required this.canViewCosts,
    required this.l10n,
    super.key,
  });

  final ProductFormDraft draft;
  final bool canViewCosts;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(l10n.productWizardReviewTitle,
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        _line(l10n.productFieldSku, draft.sku),
        _line(l10n.productFieldNameAr, draft.nameAr),
        _line(l10n.productFieldNameEn, draft.nameEn),
        _line(l10n.productFieldSalePrice, draft.salePrice),
        if (draft.productType.isRental)
          _line(
            l10n.productFieldRentalPrice,
            draft.rentalPriceMonthly ?? l10n.productsNotAvailable,
          ),
        if (canViewCosts && draft.minSalePrice != null)
          _line(l10n.productFieldMinSalePrice, draft.minSalePrice!),
      ],
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text('$label: $value'),
    );
  }
}
