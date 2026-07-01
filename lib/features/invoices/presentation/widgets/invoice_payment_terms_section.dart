import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../accounting/domain/chart_account.dart';
import '../../domain/invoice_payment_terms.dart';
import '../../domain/invoice_type.dart';
import 'invoice_design.dart';

/// Compact, UI-only payment-terms control for the invoice form.
///
/// Cash shows a helper note (no payment is posted on confirm — collection
/// happens later from vouchers). Credit reveals the existing due-date field.
class InvoicePaymentTermsSection extends StatelessWidget {
  const InvoicePaymentTermsSection({
    required this.invoiceType,
    required this.paymentTerms,
    required this.dueDate,
    required this.cashBankAccounts,
    required this.cashAccountId,
    required this.languageCode,
    required this.onTermsChanged,
    required this.onDueDateChanged,
    required this.onCashAccountChanged,
    super.key,
  });

  final InvoiceType invoiceType;
  final InvoicePaymentTerms paymentTerms;
  final DateTime? dueDate;
  final List<ChartAccount> cashBankAccounts;
  final String? cashAccountId;
  final String languageCode;
  final ValueChanged<InvoicePaymentTerms> onTermsChanged;
  final ValueChanged<DateTime?> onDueDateChanged;
  final ValueChanged<String?> onCashAccountChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    final selector = SegmentedButton<InvoicePaymentTerms>(
      style: const ButtonStyle(
        visualDensity: VisualDensity.compact,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      segments: [
        ButtonSegment(
          value: InvoicePaymentTerms.cash,
          label: Text(l10n.invoicePaymentTermsCash),
        ),
        ButtonSegment(
          value: InvoicePaymentTerms.credit,
          label: Text(l10n.invoicePaymentTermsCredit),
        ),
      ],
      selected: {paymentTerms},
      showSelectedIcon: false,
      onSelectionChanged: (selection) => onTermsChanged(selection.first),
    );

    final Widget detail;
    if (paymentTerms == InvoicePaymentTerms.cash) {
      final helper = switch (invoiceType) {
        InvoiceType.sales ||
        InvoiceType.salesReturn => l10n.invoicePaymentTermsCashHelperSales,
        InvoiceType.purchase || InvoiceType.purchaseReturn =>
          l10n.invoicePaymentTermsCashHelperPurchase,
      };
      detail = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 320,
            child: DropdownButtonFormField<String>(
              key: ValueKey('invoice-cash-account-$cashAccountId'),
              initialValue: cashAccountId,
              isExpanded: true,
              isDense: true,
              decoration: InvoiceDesign.denseField(
                context,
                hint: l10n.cashBankSelectAccount,
              ),
              items: cashBankAccounts
                  .map(
                    (account) => DropdownMenuItem(
                      value: account.id,
                      child: Text(
                        _cashBankLabel(account, languageCode),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  )
                  .toList(),
              onChanged: cashBankAccounts.isEmpty ? null : onCashAccountChanged,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.info_outline,
                size: 16,
                color: AppColors.neutral400,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  cashBankAccounts.isEmpty
                      ? l10n.cashBankChartViewRequiredBody
                      : helper,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: AppColors.neutral600,
                  ),
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      detail = SizedBox(
        width: 240,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.only(start: 2, bottom: 4),
              child: Text(
                l10n.invoiceFormDueDate,
                style: InvoiceDesign.fieldLabelStyle(context),
              ),
            ),
            _DueDateField(value: dueDate, onPick: onDueDateChanged),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.invoicePaymentTermsTitle,
          style: InvoiceDesign.fieldLabelStyle(context),
        ),
        const SizedBox(height: 8),
        selector,
        const SizedBox(height: 12),
        detail,
      ],
    );
  }
}

String _cashBankLabel(ChartAccount account, String languageCode) {
  final name = switch (account.code) {
    '1101' => languageCode == 'ar' ? 'الصندوق' : 'Cash',
    '1102' => languageCode == 'ar' ? 'البنك' : 'Bank',
    _ => account.displayName(languageCode),
  };
  return '${account.code} - $name';
}

class _DueDateField extends StatelessWidget {
  const _DueDateField({required this.value, required this.onPick});

  final DateTime? value;
  final ValueChanged<DateTime?> onPick;

  @override
  Widget build(BuildContext context) {
    final material = MaterialLocalizations.of(context);
    final text = value == null ? '' : material.formatMediumDate(value!);

    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPick(picked);
      },
      child: InputDecorator(
        decoration: InvoiceDesign.denseField(
          context,
          suffixIcon: value != null
              ? IconButton(
                  icon: const Icon(Icons.clear, size: 16),
                  onPressed: () => onPick(null),
                )
              : const Icon(Icons.calendar_today, size: 16),
        ),
        child: Text(
          text.isEmpty ? '—' : text,
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ),
    );
  }
}
