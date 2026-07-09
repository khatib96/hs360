import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/utils/decimal_parser.dart';
import '../../../finance_shared/presentation/money_display.dart';
import '../../domain/returnable_invoice_line.dart';
import '../invoice_form_mapper.dart';

class InvoiceReturnLineEditor extends ConsumerWidget {
  const InvoiceReturnLineEditor({
    required this.line,
    required this.qty,
    required this.onQtyChanged,
    super.key,
  });

  final ReturnableInvoiceLine line;
  final Decimal qty;
  final ValueChanged<Decimal> onQtyChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final credit = qty > Decimal.zero
        ? estimateReturnLineCredit(
            ReturnableLineEstimateInput(
              qty: qty,
              unitPrice: line.unitPrice,
              discountPct: line.discountPct,
            ),
          )
        : Decimal.zero;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${l10n.invoiceFormSelectProduct}: ${line.productId}',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            Text(
              '${l10n.invoiceFormQty}: ${line.returnableQty} max',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            TextFormField(
              initialValue: qty > Decimal.zero ? qty.toString() : '',
              decoration: InputDecoration(labelText: l10n.invoiceFormQty),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (value) {
                final parsed = tryParseDecimal(value) ?? Decimal.zero;
                onQtyChanged(parsed);
              },
            ),
            if (qty > Decimal.zero) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(l10n.invoiceEstimatedCreditPreview),
                  const Spacer(),
                  MoneyDisplay(amount: credit),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class InvoiceReturnCreditPanel extends ConsumerWidget {
  const InvoiceReturnCreditPanel({
    required this.lines,
    required this.qtyByLineId,
    super.key,
  });

  final List<ReturnableInvoiceLine> lines;
  final Map<String, Decimal> qtyByLineId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    var total = Decimal.zero;
    for (final line in lines) {
      final qty = qtyByLineId[line.originalLineId] ?? Decimal.zero;
      if (qty <= Decimal.zero) continue;
      total += estimateReturnLineCredit(
        ReturnableLineEstimateInput(
          qty: qty,
          unitPrice: line.unitPrice,
          discountPct: line.discountPct,
        ),
      );
    }

    if (total <= Decimal.zero) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.invoiceEstimatedTotalsDisclaimer,
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Text(
                  l10n.invoiceEstimatedCreditPreview,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                MoneyDisplay(amount: total),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
