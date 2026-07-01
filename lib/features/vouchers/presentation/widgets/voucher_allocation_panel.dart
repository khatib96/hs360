import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/localization/locale_controller.dart';
import '../../../../core/utils/money_formatter.dart';
import '../../../invoices/presentation/widgets/invoice_design.dart';
import '../../data/voucher_rpc_mapper.dart';
import '../../domain/voucher_type.dart';
import '../voucher_display_helpers.dart';
import '../voucher_form_controller.dart';

class VoucherAllocationPanel extends ConsumerWidget {
  const VoucherAllocationPanel({required this.voucherType, super.key});

  final VoucherType voucherType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final state = ref.watch(voucherFormControllerProvider(voucherType));
    final controller = ref.read(
      voucherFormControllerProvider(voucherType).notifier,
    );
    final theme = Theme.of(context);

    if (voucherType == VoucherType.payment) {
      final destination = state.form.paymentDestination ?? 'supplier';
      return _VoucherLedgerPanel(
        title: l10n.voucherAllocationsTitle,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.voucherPaymentDestinationSupplier,
                    style: theme.textTheme.titleSmall,
                  ),
                ),
                SegmentedButton<String>(
                  style: const ButtonStyle(
                    visualDensity: VisualDensity.compact,
                  ),
                  segments: [
                    ButtonSegment(
                      value: 'supplier',
                      label: Text(l10n.voucherPaymentDestinationSupplier),
                    ),
                    ButtonSegment(
                      value: 'account',
                      label: Text(l10n.voucherPaymentDestinationAccount),
                    ),
                  ],
                  selected: {destination},
                  onSelectionChanged: (values) {
                    controller.setPaymentDestination(values.first);
                  },
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (destination == 'account')
              _DirectAccountPicker(
                languageCode: locale.languageCode,
                voucherType: voucherType,
              )
            else if (state.showAllocationPanel)
              _OpenInvoicesSection(
                voucherType: voucherType,
                languageCode: locale.languageCode,
              )
            else
              Padding(
                padding: const EdgeInsetsDirectional.symmetric(vertical: 18),
                child: Text(
                  l10n.voucherOpenInvoices,
                  style: Theme.of(context).textTheme.bodyMedium,
                  textAlign: TextAlign.center,
                ),
              ),
          ],
        ),
      );
    }

    if (!state.showAllocationPanel) {
      return _VoucherLedgerPanel(
        title: l10n.voucherAllocationsTitle,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(vertical: 18),
          child: Text(
            l10n.voucherOpenInvoices,
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return _VoucherLedgerPanel(
      title: l10n.voucherAllocationsTitle,
      child: _OpenInvoicesSection(
        voucherType: voucherType,
        languageCode: locale.languageCode,
      ),
    );
  }
}

class _VoucherLedgerPanel extends StatelessWidget {
  const _VoucherLedgerPanel({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: InvoiceDesign.panel,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 12,
              vertical: 8,
            ),
            decoration: const BoxDecoration(
              color: InvoiceDesign.headerFill,
              border: Border(
                bottom: BorderSide(color: InvoiceDesign.borderColor),
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: Text(title, style: InvoiceDesign.columnHeaderStyle(context)),
          ),
          Padding(padding: const EdgeInsetsDirectional.all(12), child: child),
        ],
      ),
    );
  }
}

class _DirectAccountPicker extends ConsumerWidget {
  const _DirectAccountPicker({
    required this.languageCode,
    required this.voucherType,
  });

  final String languageCode;
  final VoucherType voucherType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(voucherFormControllerProvider(voucherType));
    final controller = ref.read(
      voucherFormControllerProvider(voucherType).notifier,
    );

    if (!state.canLoadCashAccounts) {
      return const SizedBox.shrink();
    }

    final accounts = state.postingAccounts;
    final selectedId = state.form.accountId;

    return _VoucherRowShell(
      columns: [
        Expanded(
          flex: 3,
          child: DropdownButtonFormField<String>(
            initialValue: accounts.any((a) => a.id == selectedId)
                ? selectedId
                : null,
            isDense: true,
            decoration: InvoiceDesign.denseField(
              context,
              label: l10n.voucherPaymentDestinationAccount,
            ),
            items: accounts
                .map(
                  (account) => DropdownMenuItem(
                    value: account.id,
                    child: Text(
                      voucherAccountDisplayName(
                        languageCode,
                        nameAr: account.nameAr,
                        nameEn: account.nameEn,
                        code: account.code,
                      ),
                    ),
                  ),
                )
                .toList(),
            onChanged: controller.setAccountId,
          ),
        ),
        Expanded(
          child: Text(
            l10n.financeColumnAmount,
            textAlign: TextAlign.end,
            style: InvoiceDesign.columnHeaderStyle(context),
          ),
        ),
      ],
    );
  }
}

class _VoucherRowShell extends StatelessWidget {
  const _VoucherRowShell({required this.columns});

  final List<Widget> columns;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: InvoiceDesign.borderColor)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < columns.length; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              columns[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _OpenInvoicesSection extends ConsumerWidget {
  const _OpenInvoicesSection({
    required this.voucherType,
    required this.languageCode,
  });

  final VoucherType voucherType;
  final String languageCode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(voucherFormControllerProvider(voucherType));
    final controller = ref.read(
      voucherFormControllerProvider(voucherType).notifier,
    );
    final allocationMode = state.form.allocationMode ?? 'fifo';
    final isManual = allocationMode == 'manual';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text(l10n.voucherAllocationFifo),
              selected: allocationMode == 'fifo',
              onSelected: (_) => controller.setAllocationMode('fifo'),
            ),
            ChoiceChip(
              label: Text(l10n.voucherAllocationManual),
              selected: allocationMode == 'manual',
              onSelected: (_) => controller.setAllocationMode('manual'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (state.isLoadingOpenInvoices)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: LinearProgressIndicator(),
          )
        else if (state.openInvoices.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              l10n.invoiceListEmpty,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          )
        else ...[
          const SizedBox(height: 6),
          _OpenInvoiceHeader(),
          for (final invoice in state.openInvoices)
            _OpenInvoiceRow(
              invoice: invoice,
              languageCode: languageCode,
              isManual: isManual,
              allocatedAmount: state.manualAllocationAmounts[invoice.id],
              onAllocationChanged: (amount) {
                controller.updateManualAllocation(invoice.id, amount);
              },
            ),
        ],
      ],
    );
  }
}

class _OpenInvoiceHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      color: InvoiceDesign.headerFill,
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              l10n.invoiceColumnNumber,
              style: InvoiceDesign.columnHeaderStyle(context),
            ),
          ),
          Expanded(
            child: Text(
              l10n.financeColumnOutstanding,
              textAlign: TextAlign.end,
              style: InvoiceDesign.columnHeaderStyle(context),
            ),
          ),
          Expanded(
            child: Text(
              l10n.financeColumnAmount,
              textAlign: TextAlign.end,
              style: InvoiceDesign.columnHeaderStyle(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _OpenInvoiceRow extends StatelessWidget {
  const _OpenInvoiceRow({
    required this.invoice,
    required this.languageCode,
    required this.isManual,
    required this.allocatedAmount,
    required this.onAllocationChanged,
  });

  final OpenInvoiceAllocationOption invoice;
  final String languageCode;
  final bool isManual;
  final Decimal? allocatedAmount;
  final ValueChanged<Decimal?> onAllocationChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final number = invoice.invoiceNumber ?? invoice.id;
    final outstanding = formatMoney(invoice.outstanding, locale: languageCode);

    return DecoratedBox(
      decoration: const BoxDecoration(
        color: InvoiceDesign.sheetFill,
        border: Border(bottom: BorderSide(color: InvoiceDesign.borderColor)),
      ),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: 10,
          vertical: 8,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              flex: 3,
              child: Text(
                number,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Expanded(
              child: Text(
                outstanding,
                textAlign: TextAlign.end,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: isManual
                  ? TextFormField(
                      initialValue: allocatedAmount?.toString() ?? '',
                      decoration: InvoiceDesign.cellField(
                        context,
                        hint: l10n.financeColumnAmount,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      textAlign: TextAlign.end,
                      onChanged: (value) {
                        final trimmed = value.trim();
                        if (trimmed.isEmpty) {
                          onAllocationChanged(null);
                          return;
                        }
                        onAllocationChanged(Decimal.tryParse(trimmed));
                      },
                    )
                  : Text(
                      outstanding,
                      textAlign: TextAlign.end,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
