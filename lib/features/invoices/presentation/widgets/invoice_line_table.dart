import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/invoice_type.dart';
import '../invoice_form_controller.dart';
import '../invoice_form_state.dart';
import 'invoice_design.dart';
import 'invoice_line_row.dart';

/// Desktop lines grid: header + editable rows + compact add-line affordance.
class InvoiceLineTable extends ConsumerStatefulWidget {
  const InvoiceLineTable({
    required this.invoiceType,
    required this.lines,
    required this.languageCode,
    required this.decimalPlaces,
    super.key,
  });

  final InvoiceType invoiceType;
  final List<InvoiceFormLineUiState> lines;
  final String languageCode;
  final int decimalPlaces;

  @override
  ConsumerState<InvoiceLineTable> createState() => _InvoiceLineTableState();
}

class _InvoiceLineTableState extends ConsumerState<InvoiceLineTable> {
  final _productFocusNodes = <FocusNode>[];

  @override
  void dispose() {
    for (final node in _productFocusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  void _ensureFocusNodes(int count) {
    while (_productFocusNodes.length < count) {
      _productFocusNodes.add(FocusNode());
    }
    while (_productFocusNodes.length > count) {
      _productFocusNodes.removeLast().dispose();
    }
  }

  void _focusProductAt(int index) {
    if (index < 0 || index >= _productFocusNodes.length) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _productFocusNodes[index].requestFocus();
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    ref.watch(invoiceFormControllerProvider(widget.invoiceType));
    final controller = ref.read(
      invoiceFormControllerProvider(widget.invoiceType).notifier,
    );

    ref.listen<int?>(
      invoiceFormControllerProvider(
        widget.invoiceType,
      ).select((s) => s.productFocusRequestIndex),
      (previous, next) {
        if (next == null) return;
        _ensureFocusNodes(widget.lines.length);
        _focusProductAt(next);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          controller.clearProductFocusRequest();
        });
      },
    );

    _ensureFocusNodes(widget.lines.length);

    return DecoratedBox(
      decoration: InvoiceDesign.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _header(context, l10n),
          for (var i = 0; i < widget.lines.length; i++) ...[
            if (i > 0)
              const Divider(height: 1, color: InvoiceDesign.borderColor),
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: 8,
                vertical: 2,
              ),
              child: InvoiceLineRow(
                key: ValueKey('invoice-line-$i'),
                invoiceType: widget.invoiceType,
                lineIndex: i,
                line: widget.lines[i],
                languageCode: widget.languageCode,
                decimalPlaces: widget.decimalPlaces,
                canRemove: widget.lines.length > 1,
                isLastLine: i == widget.lines.length - 1,
                productFocusNode: _productFocusNodes[i],
                onAdvanceLine: controller.addLineAndFocusProduct,
              ),
            ),
          ],
          const Divider(height: 1, color: InvoiceDesign.borderColor),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Padding(
              padding: const EdgeInsetsDirectional.all(6),
              child: TextButton.icon(
                onPressed: controller.addLineAndFocusProduct,
                icon: const Icon(Icons.add, size: 18),
                label: Text(l10n.invoiceFormAddLine),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _header(BuildContext context, AppLocalizations l10n) {
    Widget label(String text, {TextAlign align = TextAlign.start}) {
      return Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
        child: Text(
          text,
          textAlign: align,
          style: InvoiceDesign.columnHeaderStyle(context),
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: InvoiceDesign.headerFill,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
        border: Border(bottom: BorderSide(color: InvoiceDesign.borderColor)),
      ),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 8,
        vertical: 10,
      ),
      child: invoiceLineRowLayout(
        product: label(l10n.invoiceFormSelectProduct),
        description: label(l10n.invoiceColumnDescription),
        qty: label(l10n.invoiceFormQty, align: TextAlign.end),
        unit: label(l10n.invoiceColumnUnit, align: TextAlign.center),
        price: label(l10n.invoiceFormUnitPrice, align: TextAlign.end),
        discount: label(l10n.invoiceFormDiscount, align: TextAlign.end),
        total: label(l10n.invoiceColumnLineTotal, align: TextAlign.end),
        actions: const SizedBox.shrink(),
      ),
    );
  }
}
