import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../finance_shared/presentation/money_display.dart';
import '../invoice_form_draft_builder.dart';
import 'invoice_design.dart';

/// A single label/amount line inside a totals block.
class InvoiceTotalsRow {
  const InvoiceTotalsRow(this.label, this.amount, {this.emphasized = false});

  final String label;
  final Decimal amount;
  final bool emphasized;
}

/// Reusable, right-aligned, thin-bordered totals block (form + detail).
class InvoiceTotalsBlock extends StatelessWidget {
  const InvoiceTotalsBlock({
    required this.rows,
    this.note,
    super.key,
  });

  final List<InvoiceTotalsRow> rows;
  final String? note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDesktop = InvoiceDesign.isDesktop(context);

    final block = DecoratedBox(
      decoration: InvoiceDesign.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (note != null && note!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 0),
              child: Text(note!, style: theme.textTheme.bodySmall),
            ),
          for (var i = 0; i < rows.length; i++) _row(context, rows[i], i),
        ],
      ),
    );

    if (!isDesktop) return block;

    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: block,
      ),
    );
  }

  Widget _row(BuildContext context, InvoiceTotalsRow row, int index) {
    final theme = Theme.of(context);
    final emphasized = row.emphasized;
    final showDivider = index > 0 && emphasized;

    return Container(
      decoration: BoxDecoration(
        color: emphasized ? AppColors.goldSoft.withValues(alpha: 0.35) : null,
        border: showDivider
            ? const Border(top: BorderSide(color: InvoiceDesign.borderColor))
            : null,
      ),
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 14,
        vertical: 8,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              row.label,
              style: emphasized
                  ? theme.textTheme.titleSmall
                  : theme.textTheme.bodyMedium,
            ),
          ),
          MoneyDisplay(
            amount: row.amount,
            style: emphasized
                ? theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.charcoal,
                  )
                : theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

/// Estimate totals panel for the invoice FORM.
class InvoiceTotalsPanel extends ConsumerWidget {
  const InvoiceTotalsPanel({
    required this.estimate,
    required this.taxEstimateAvailable,
    super.key,
  });

  final InvoiceEstimateTotals? estimate;
  final bool taxEstimateAvailable;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (estimate == null) {
      return Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Text(
          l10n.invoiceFinalTotalsAfterConfirm,
          style: theme.textTheme.bodyMedium,
        ),
      );
    }

    final rows = <InvoiceTotalsRow>[
      InvoiceTotalsRow(l10n.invoiceTotalsSubtotal, estimate!.subtotal),
      InvoiceTotalsRow(l10n.invoiceTotalsDiscount, estimate!.discountAmount),
      if (taxEstimateAvailable && estimate!.taxAmount != null)
        InvoiceTotalsRow(l10n.invoiceTotalsTax, estimate!.taxAmount!),
      InvoiceTotalsRow(
        l10n.invoiceTotalsTotal,
        estimate!.total,
        emphasized: true,
      ),
    ];

    return InvoiceTotalsBlock(
      rows: rows,
      note: l10n.invoiceEstimatedTotalsDisclaimer,
    );
  }
}
