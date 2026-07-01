import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/decimal_parser.dart';
import '../../../finance_shared/presentation/money_display.dart';
import '../../../products/presentation/product_display_helpers.dart';
import '../../domain/invoice_type.dart';
import '../invoice_form_controller.dart';
import '../invoice_form_draft_builder.dart';
import '../invoice_form_state.dart';
import 'invoice_design.dart';
import 'invoice_line_product_cell.dart';

/// Lays out one logical line row across the shared invoice grid columns.
Widget invoiceLineRowLayout({
  required Widget product,
  required Widget description,
  required Widget qty,
  required Widget unit,
  required Widget price,
  required Widget discount,
  required Widget total,
  required Widget actions,
}) {
  return Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Expanded(flex: 24, child: product),
      Expanded(flex: 20, child: description),
      SizedBox(width: 76, child: qty),
      SizedBox(width: 58, child: unit),
      SizedBox(width: 108, child: price),
      SizedBox(width: 82, child: discount),
      SizedBox(width: 124, child: total),
      SizedBox(width: 44, child: actions),
    ],
  );
}

/// Editable desktop grid row for a single invoice line.
class InvoiceLineRow extends ConsumerStatefulWidget {
  const InvoiceLineRow({
    required this.invoiceType,
    required this.lineIndex,
    required this.line,
    required this.languageCode,
    required this.decimalPlaces,
    required this.canRemove,
    required this.isLastLine,
    required this.productFocusNode,
    required this.onAdvanceLine,
    super.key,
  });

  final InvoiceType invoiceType;
  final int lineIndex;
  final InvoiceFormLineUiState line;
  final String languageCode;
  final int decimalPlaces;
  final bool canRemove;
  final bool isLastLine;
  final FocusNode productFocusNode;
  final VoidCallback onAdvanceLine;

  @override
  ConsumerState<InvoiceLineRow> createState() => _InvoiceLineRowState();
}

class _InvoiceLineRowState extends ConsumerState<InvoiceLineRow> {
  late final TextEditingController _qty;
  late final TextEditingController _price;
  late final TextEditingController _discount;
  final _qtyFocus = FocusNode();
  final _priceFocus = FocusNode();
  final _discountFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _qty = TextEditingController(text: _fmt(widget.line.qty));
    _price = TextEditingController(text: _fmt(widget.line.unitPrice));
    _discount = TextEditingController(text: _fmt(widget.line.discountPct));
  }

  @override
  void didUpdateWidget(InvoiceLineRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncIfIdle(_qty, _qtyFocus, widget.line.qty);
    _syncIfIdle(_price, _priceFocus, widget.line.unitPrice);
    _syncIfIdle(_discount, _discountFocus, widget.line.discountPct);
  }

  void _syncIfIdle(TextEditingController c, FocusNode f, Decimal value) {
    if (f.hasFocus) return;
    final current = tryParseDecimal(c.text);
    if (current == value) return;
    c.text = _fmt(value);
  }

  String _fmt(Decimal value) => value.toString();

  @override
  void dispose() {
    _qty.dispose();
    _price.dispose();
    _discount.dispose();
    _qtyFocus.dispose();
    _priceFocus.dispose();
    _discountFocus.dispose();
    super.dispose();
  }

  InvoiceFormController get _controller =>
      ref.read(invoiceFormControllerProvider(widget.invoiceType).notifier);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final product = widget.line.product;
    final lineTotal = lineNetTotalEstimate(
      qty: widget.line.qty,
      unitPrice: widget.line.unitPrice,
      discountPct: widget.line.discountPct,
      decimalPlaces: widget.decimalPlaces,
    );

    final description = product == null
        ? ''
        : _localizedDescription(product.descriptionAr, product.descriptionEn);

    final mainRow = invoiceLineRowLayout(
      product: InvoiceLineProductCell(
        invoiceType: widget.invoiceType,
        lineIndex: widget.lineIndex,
        product: product,
        languageCode: widget.languageCode,
        isLastLine: widget.isLastLine,
        focusNode: widget.productFocusNode,
        onAdvanceLine: widget.onAdvanceLine,
      ),
      description: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
        child: Text(
          description.isEmpty ? '—' : description,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      qty: _numberField(_qty, _qtyFocus, (v) {
        _controller.setLineQty(
          widget.lineIndex,
          tryParseDecimal(v) ?? Decimal.zero,
        );
      }),
      unit: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 4),
        child: Text(
          product == null ? '—' : unitOfMeasureLabel(product.unitPrimary),
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ),
      price: _numberField(_price, _priceFocus, (v) {
        _controller.setLineUnitPrice(
          widget.lineIndex,
          tryParseDecimal(v) ?? Decimal.zero,
        );
      }),
      discount: _numberField(
        _discount,
        _discountFocus,
        (v) {
          _controller.setLineDiscountPct(
            widget.lineIndex,
            tryParseDecimal(v) ?? Decimal.zero,
          );
        },
        onSubmitted: widget.isLastLine ? widget.onAdvanceLine : null,
      ),
      total: Padding(
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 8),
        child: Align(
          alignment: AlignmentDirectional.centerEnd,
          child: MoneyDisplay(
            amount: lineTotal,
            includeSymbol: false,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ),
      actions: widget.canRemove
          ? IconButton(
              tooltip: MaterialLocalizations.of(context).deleteButtonTooltip,
              icon: const Icon(
                Icons.close,
                size: 18,
                color: AppColors.neutral400,
              ),
              onPressed: () => _controller.removeLine(widget.lineIndex),
            )
          : const SizedBox.shrink(),
    );

    final serialized = _serializedSection(context, l10n);

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(vertical: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [mainRow, ?serialized],
      ),
    );
  }

  Widget _numberField(
    TextEditingController controller,
    FocusNode focus,
    ValueChanged<String> onChanged, {
    VoidCallback? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      focusNode: focus,
      textAlign: TextAlign.end,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: onSubmitted != null
          ? TextInputAction.done
          : TextInputAction.next,
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InvoiceDesign.cellField(context),
      onChanged: onChanged,
      onSubmitted: onSubmitted == null ? null : (_) => onSubmitted(),
    );
  }

  Widget? _serializedSection(BuildContext context, AppLocalizations l10n) {
    final product = widget.line.product;
    if (product?.isSerialized != true) return null;

    if (widget.invoiceType.isSalesDirection ||
        widget.invoiceType == InvoiceType.purchaseReturn) {
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 8, 6),
        child: TextFormField(
          initialValue: widget.line.productUnitId,
          decoration: InvoiceDesign.denseField(
            context,
            label: l10n.invoiceFormSerialNumber,
          ),
          style: Theme.of(context).textTheme.bodySmall,
          onChanged: (value) => _controller.setLineProductUnitId(
            widget.lineIndex,
            value.trim().isEmpty ? null : value.trim(),
          ),
        ),
      );
    }

    if (widget.invoiceType == InvoiceType.purchase &&
        widget.line.units.isNotEmpty) {
      return Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(8, 6, 8, 6),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < widget.line.units.length; i++)
              SizedBox(
                width: 200,
                child: TextFormField(
                  initialValue: widget.line.units[i].serialNumber,
                  decoration: InvoiceDesign.denseField(
                    context,
                    label: '${l10n.invoiceFormSerialNumber} ${i + 1}',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                  onChanged: (value) => _controller.setPurchaseUnitSerial(
                    widget.lineIndex,
                    i,
                    value,
                  ),
                ),
              ),
          ],
        ),
      );
    }
    return null;
  }

  String _localizedDescription(String? ar, String? en) {
    final preferAr = widget.languageCode.toLowerCase().startsWith('ar');
    final a = ar?.trim() ?? '';
    final e = en?.trim() ?? '';
    if (preferAr) return a.isNotEmpty ? a : e;
    return e.isNotEmpty ? e : a;
  }
}
