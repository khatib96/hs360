import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/utils/decimal_parser.dart';
import '../../../finance_shared/presentation/money_display.dart';
import '../../../products/presentation/product_display_helpers.dart';
import '../../domain/invoice_type.dart';
import '../invoice_form_controller.dart';
import '../invoice_form_draft_builder.dart';
import '../invoice_form_state.dart';
import 'invoice_design.dart';
import 'invoice_line_product_cell.dart';

/// Compact stacked line editor used on narrow/mobile widths.
class InvoiceLineCards extends ConsumerWidget {
  const InvoiceLineCards({
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
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final controller = ref.read(
      invoiceFormControllerProvider(invoiceType).notifier,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < lines.length; i++)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 10),
            child: _LineCard(
              key: ValueKey('invoice-line-card-$i'),
              invoiceType: invoiceType,
              lineIndex: i,
              line: lines[i],
              languageCode: languageCode,
              decimalPlaces: decimalPlaces,
              canRemove: lines.length > 1,
            ),
          ),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: OutlinedButton.icon(
            onPressed: controller.addLine,
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.invoiceFormAddLine),
          ),
        ),
      ],
    );
  }
}

class _LineCard extends ConsumerStatefulWidget {
  const _LineCard({
    required this.invoiceType,
    required this.lineIndex,
    required this.line,
    required this.languageCode,
    required this.decimalPlaces,
    required this.canRemove,
    super.key,
  });

  final InvoiceType invoiceType;
  final int lineIndex;
  final InvoiceFormLineUiState line;
  final String languageCode;
  final int decimalPlaces;
  final bool canRemove;

  @override
  ConsumerState<_LineCard> createState() => _LineCardState();
}

class _LineCardState extends ConsumerState<_LineCard> {
  late final TextEditingController _qty;
  late final TextEditingController _price;
  late final TextEditingController _discount;
  final _qtyFocus = FocusNode();
  final _priceFocus = FocusNode();
  final _discountFocus = FocusNode();

  @override
  void initState() {
    super.initState();
    _qty = TextEditingController(text: widget.line.qty.toString());
    _price = TextEditingController(text: widget.line.unitPrice.toString());
    _discount = TextEditingController(text: widget.line.discountPct.toString());
  }

  @override
  void didUpdateWidget(_LineCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync(_qty, _qtyFocus, widget.line.qty);
    _sync(_price, _priceFocus, widget.line.unitPrice);
    _sync(_discount, _discountFocus, widget.line.discountPct);
  }

  void _sync(TextEditingController c, FocusNode f, Decimal value) {
    if (f.hasFocus) return;
    if (tryParseDecimal(c.text) == value) return;
    c.text = value.toString();
  }

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

    return DecoratedBox(
      decoration: InvoiceDesign.panel,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                border: InvoiceDesign.box,
                borderRadius: InvoiceDesign.radiusSmall,
              ),
              child: InvoiceLineProductCell(
                invoiceType: widget.invoiceType,
                lineIndex: widget.lineIndex,
                product: product,
                languageCode: widget.languageCode,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _field(
                    l10n.invoiceFormQty,
                    _qty,
                    _qtyFocus,
                    (v) => _controller.setLineQty(
                      widget.lineIndex,
                      tryParseDecimal(v) ?? Decimal.zero,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _readOnly(
                    l10n.invoiceColumnUnit,
                    product == null
                        ? '—'
                        : unitOfMeasureLabel(product.unitPrimary),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _field(
                    l10n.invoiceFormUnitPrice,
                    _price,
                    _priceFocus,
                    (v) => _controller.setLineUnitPrice(
                      widget.lineIndex,
                      tryParseDecimal(v) ?? Decimal.zero,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _field(
                    l10n.invoiceFormDiscount,
                    _discount,
                    _discountFocus,
                    (v) => _controller.setLineDiscountPct(
                      widget.lineIndex,
                      tryParseDecimal(v) ?? Decimal.zero,
                    ),
                  ),
                ),
              ],
            ),
            if (product?.isSerialized == true) ...[
              const SizedBox(height: 10),
              _serialized(context, l10n),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Text(
                  '${l10n.invoiceColumnLineTotal}: ',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                MoneyDisplay(
                  amount: lineTotal,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                if (widget.canRemove)
                  TextButton(
                    onPressed: () => _controller.removeLine(widget.lineIndex),
                    child: Text(
                      MaterialLocalizations.of(context).deleteButtonTooltip,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    String label,
    TextEditingController controller,
    FocusNode focus,
    ValueChanged<String> onChanged,
  ) {
    return TextField(
      controller: controller,
      focusNode: focus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      style: Theme.of(context).textTheme.bodyMedium,
      decoration: InvoiceDesign.denseField(context, label: label),
      onChanged: onChanged,
    );
  }

  Widget _readOnly(String label, String value) {
    return InputDecorator(
      decoration: InvoiceDesign.denseField(context, label: label),
      child: Text(value, style: Theme.of(context).textTheme.bodyMedium),
    );
  }

  Widget _serialized(BuildContext context, AppLocalizations l10n) {
    if (widget.invoiceType.isSalesDirection ||
        widget.invoiceType == InvoiceType.purchaseReturn) {
      return TextFormField(
        initialValue: widget.line.productUnitId,
        decoration: InvoiceDesign.denseField(
          context,
          label: l10n.invoiceFormSerialNumber,
        ),
        onChanged: (value) => _controller.setLineProductUnitId(
          widget.lineIndex,
          value.trim().isEmpty ? null : value.trim(),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < widget.line.units.length; i++)
          Padding(
            padding: const EdgeInsetsDirectional.only(bottom: 8),
            child: TextFormField(
              initialValue: widget.line.units[i].serialNumber,
              decoration: InvoiceDesign.denseField(
                context,
                label: '${l10n.invoiceFormSerialNumber} ${i + 1}',
              ),
              onChanged: (value) =>
                  _controller.setPurchaseUnitSerial(widget.lineIndex, i, value),
            ),
          ),
      ],
    );
  }
}
