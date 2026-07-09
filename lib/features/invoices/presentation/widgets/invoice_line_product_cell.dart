import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../products/domain/product.dart';
import '../../../products/presentation/product_display_helpers.dart';
import '../../domain/invoice_type.dart';
import '../invoice_form_controller.dart';
import 'invoice_design.dart';

/// Compact product cell used inside the desktop lines grid.
class InvoiceLineProductCell extends ConsumerStatefulWidget {
  const InvoiceLineProductCell({
    required this.invoiceType,
    required this.lineIndex,
    required this.product,
    required this.languageCode,
    this.isLastLine = false,
    this.focusNode,
    this.onAdvanceLine,
    super.key,
  });

  final InvoiceType invoiceType;
  final int lineIndex;
  final Product? product;
  final String languageCode;
  final bool isLastLine;
  final FocusNode? focusNode;
  final VoidCallback? onAdvanceLine;

  @override
  ConsumerState<InvoiceLineProductCell> createState() =>
      _InvoiceLineProductCellState();
}

class _InvoiceLineProductCellState
    extends ConsumerState<InvoiceLineProductCell> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final selected = widget.product != null;
    final label = selected
        ? localizedProductName(widget.product!, widget.languageCode)
        : l10n.invoiceFormSelectProduct;

    final cell = InkWell(
      borderRadius: InvoiceDesign.radiusSmall,
      onTap: _openPicker,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 8,
          vertical: 8,
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: selected ? AppColors.ink : AppColors.neutral400,
                      fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
                    ),
                  ),
                  if (selected && widget.product!.sku.isNotEmpty)
                    Text(
                      widget.product!.sku,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                ],
              ),
            ),
            const Icon(
              Icons.unfold_more,
              size: 16,
              color: AppColors.neutral400,
            ),
          ],
        ),
      ),
    );

    final focusNode = widget.focusNode;
    if (focusNode == null) return cell;

    return Focus(
      key: Key('invoice-line-product-${widget.lineIndex}'),
      focusNode: focusNode,
      onKeyEvent: (node, event) {
        if (event is! KeyDownEvent) return KeyEventResult.ignored;
        if (event.logicalKey != LogicalKeyboardKey.enter) {
          return KeyEventResult.ignored;
        }
        if (selected && widget.isLastLine) {
          widget.onAdvanceLine?.call();
          return KeyEventResult.handled;
        }
        _openPicker();
        return KeyEventResult.handled;
      },
      child: cell,
    );
  }

  Future<void> _openPicker() async {
    await showInvoiceProductPicker(
      context,
      ref,
      invoiceType: widget.invoiceType,
      lineIndex: widget.lineIndex,
      languageCode: widget.languageCode,
      advanceLineOnSelect: widget.isLastLine,
    );
  }
}

Future<void> showInvoiceProductPicker(
  BuildContext context,
  WidgetRef ref, {
  required InvoiceType invoiceType,
  required int lineIndex,
  required String languageCode,
  bool advanceLineOnSelect = false,
}) async {
  final controller = ref.read(
    invoiceFormControllerProvider(invoiceType).notifier,
  );
  final product = await showDialog<Product>(
    context: context,
    builder: (_) => _ProductPickerDialog(
      invoiceType: invoiceType,
      languageCode: languageCode,
    ),
  );
  if (product != null) {
    controller.selectProduct(
      lineIndex,
      product,
      advanceLine: advanceLineOnSelect,
    );
  }
}

class _ProductPickerDialog extends ConsumerStatefulWidget {
  const _ProductPickerDialog({
    required this.invoiceType,
    required this.languageCode,
  });

  final InvoiceType invoiceType;
  final String languageCode;

  @override
  ConsumerState<_ProductPickerDialog> createState() =>
      _ProductPickerDialogState();
}

class _ProductPickerDialogState extends ConsumerState<_ProductPickerDialog> {
  final _searchController = TextEditingController();
  Timer? _debounce;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(invoiceFormControllerProvider(widget.invoiceType));
    final controller = ref.read(
      invoiceFormControllerProvider(widget.invoiceType).notifier,
    );

    return Dialog(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
        child: Padding(
          padding: const EdgeInsetsDirectional.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.invoiceFormSelectProduct,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _searchController,
                autofocus: true,
                decoration: InvoiceDesign.denseField(
                  context,
                  hint: l10n.invoiceFilterSearch,
                  prefixIcon: const Icon(Icons.search, size: 18),
                ),
                onChanged: (value) {
                  _debounce?.cancel();
                  _debounce = Timer(
                    const Duration(milliseconds: 300),
                    () => controller.searchProducts(value),
                  );
                },
              ),
              const SizedBox(height: 8),
              if (state.isSearchingProducts) const LinearProgressIndicator(),
              Flexible(
                child: state.productSearchResults.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsetsDirectional.all(24),
                          child: Text(
                            l10n.invoiceFilterSearch,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: state.productSearchResults.length,
                        separatorBuilder: (_, _) => const Divider(
                          height: 1,
                          color: InvoiceDesign.borderColor,
                        ),
                        itemBuilder: (context, index) {
                          final p = state.productSearchResults[index];
                          return ListTile(
                            dense: true,
                            title: Text(
                              localizedProductName(p, widget.languageCode),
                            ),
                            subtitle: p.sku.isNotEmpty ? Text(p.sku) : null,
                            onTap: () => Navigator.pop(context, p),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    MaterialLocalizations.of(context).cancelButtonLabel,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
