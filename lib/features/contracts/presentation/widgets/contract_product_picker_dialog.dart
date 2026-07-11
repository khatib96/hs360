import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../products/domain/product.dart';
import '../../../products/presentation/product_display_helpers.dart';
import '../contract_form_controller.dart';
import '../contract_form_state.dart';

Future<void> showContractProductPicker(
  BuildContext context,
  WidgetRef ref, {
  required int lineIndex,
  required ContractProductSearchTarget target,
}) async {
  final controller = ref.read(contractFormControllerProvider.notifier);
  final product = await showDialog<Product>(
    context: context,
    builder: (_) =>
        ContractProductPickerDialog(lineIndex: lineIndex, target: target),
  );
  if (product == null) return;
  switch (target) {
    case ContractProductSearchTarget.asset:
      await controller.selectAssetProduct(lineIndex, product);
    case ContractProductSearchTarget.consumable:
      controller.selectConsumableProduct(lineIndex, product);
    case ContractProductSearchTarget.rental:
      await controller.addRentalProduct(product);
  }
}

class ContractProductPickerDialog extends ConsumerStatefulWidget {
  const ContractProductPickerDialog({
    required this.lineIndex,
    required this.target,
    super.key,
  });

  final int lineIndex;
  final ContractProductSearchTarget target;

  @override
  ConsumerState<ContractProductPickerDialog> createState() =>
      _ContractProductPickerDialogState();
}

class _ContractProductPickerDialogState
    extends ConsumerState<ContractProductPickerDialog> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      ref
          .read(contractFormControllerProvider.notifier)
          .searchProducts(
            query,
            target: widget.target,
            lineIndex: widget.lineIndex,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final state = ref.watch(contractFormControllerProvider);

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.invoiceFormSelectProduct,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l10n.contractFilterSearchHint,
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: _onSearchChanged,
              ),
              if (state.isSearchingProducts)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: LinearProgressIndicator(),
                ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  itemCount: state.productSearchResults.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final product = state.productSearchResults[index];
                    return ListTile(
                      title: Text(localizedProductName(product, locale)),
                      subtitle: product.sku.isNotEmpty
                          ? Text(product.sku)
                          : null,
                      onTap: () => Navigator.of(context).pop(product),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
