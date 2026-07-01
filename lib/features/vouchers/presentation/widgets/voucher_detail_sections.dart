import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../finance_shared/presentation/money_display.dart';
import '../../../invoices/presentation/widgets/invoice_design.dart';
import '../../domain/voucher_detail.dart';
import '../voucher_display_helpers.dart';
import 'voucher_shared_widgets.dart';

class VoucherDetailHeader extends StatelessWidget {
  const VoucherDetailHeader({
    required this.detail,
    required this.languageCode,
    super.key,
  });

  final VoucherDetail detail;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              detail.voucherNumber ?? '—',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            voucherStatusChip(
              context,
              voucherStatusLabel(l10n, detail.status),
              cancelled: detail.status.isCancelled,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(voucherTypeLabel(l10n, detail.type)),
        const SizedBox(height: 4),
        Text(MaterialLocalizations.of(context).formatMediumDate(detail.date)),
        if (detail.referenceNo != null &&
            detail.referenceNo!.trim().isNotEmpty) ...[
          const SizedBox(height: 4),
          Text('${l10n.voucherFormReference}: ${detail.referenceNo}'),
        ],
        if (detail.notes != null && detail.notes!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(detail.notes!),
        ],
        if (detail.status.isCancelled &&
            detail.cancellationReason != null &&
            detail.cancellationReason!.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text('${l10n.voucherCancelReason}: ${detail.cancellationReason}'),
        ],
      ],
    );
  }
}

class VoucherPartySection extends StatelessWidget {
  const VoucherPartySection({
    required this.detail,
    required this.languageCode,
    super.key,
  });

  final VoucherDetail detail;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final customer = detail.customer;
    final supplier = detail.supplier;

    if (customer != null) {
      return _PartyRow(
        label: l10n.voucherFormCustomer,
        name: customer.displayName(languageCode),
        onOpen: customer.customerId == null
            ? null
            : () => context.go(
                AppRoutes.customerDetailPath(customer.customerId!),
              ),
      );
    }
    if (supplier != null) {
      return _PartyRow(
        label: l10n.voucherFormSupplier,
        name: supplier.displayName(languageCode),
        onOpen: supplier.supplierId == null
            ? null
            : () => context.go(
                AppRoutes.supplierDetailPath(supplier.supplierId!),
              ),
      );
    }
    return const SizedBox.shrink();
  }
}

class VoucherCashAccountSection extends StatelessWidget {
  const VoucherCashAccountSection({
    required this.detail,
    required this.languageCode,
    super.key,
  });

  final VoucherDetail detail;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final cashAccount = detail.cashAccount;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          voucherAccountDisplayName(
            languageCode,
            nameAr: cashAccount.nameAr,
            nameEn: cashAccount.nameEn,
            code: cashAccount.code,
          ),
        ),
      ],
    );
  }
}

class VoucherPaymentSummary extends StatelessWidget {
  const VoucherPaymentSummary({required this.detail, super.key});

  final VoucherDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return DecoratedBox(
      decoration: InvoiceDesign.headerStrip,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(12),
        child: Column(
          children: [
            _amountRow(
              context,
              l10n.voucherFormPaymentMethod,
              Text(paymentMethodLabel(l10n, detail.paymentMethod)),
            ),
            _amountRow(
              context,
              l10n.voucherFormAmount,
              MoneyDisplay(amount: detail.amount),
              emphasized: true,
            ),
            _amountRow(
              context,
              l10n.voucherAllocatedAmount,
              MoneyDisplay(amount: detail.allocatedAmount),
            ),
            _amountRow(
              context,
              l10n.voucherUnallocatedAmount,
              MoneyDisplay(amount: detail.unallocatedAmount),
            ),
          ],
        ),
      ),
    );
  }

  Widget _amountRow(
    BuildContext context,
    String label,
    Widget value, {
    bool emphasized = false,
  }) {
    final style = emphasized
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.bodyMedium;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          DefaultTextStyle.merge(style: style, child: value),
        ],
      ),
    );
  }
}

class VoucherAllocationsTable extends StatelessWidget {
  const VoucherAllocationsTable({
    required this.detail,
    required this.isWide,
    super.key,
  });

  final VoucherDetail detail;
  final bool isWide;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final allocations = detail.allocations;
    if (allocations.isEmpty) {
      return const SizedBox.shrink();
    }

    final invoiceType = invoiceTypeForVoucher(detail.type);

    if (isWide) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(InvoiceDesign.headerFill),
          headingTextStyle: InvoiceDesign.columnHeaderStyle(context),
          dataRowMinHeight: 42,
          dataRowMaxHeight: 48,
          columnSpacing: 28,
          columns: [
            DataColumn(label: Text(l10n.invoiceColumnNumber)),
            DataColumn(label: Text(l10n.financeColumnDate)),
            DataColumn(label: Text(l10n.financeColumnTotal)),
            DataColumn(label: Text(l10n.voucherAllocatedAmount)),
          ],
          rows: [
            for (final alloc in allocations)
              DataRow(
                onSelectChanged: (_) => context.go(
                  AppRoutes.invoiceDetailPath(
                    alloc.invoiceId,
                    type: invoiceType,
                  ),
                ),
                cells: [
                  DataCell(Text(alloc.invoiceNumber ?? '—')),
                  DataCell(
                    Text(
                      alloc.invoiceDate == null
                          ? '—'
                          : MaterialLocalizations.of(
                              context,
                            ).formatMediumDate(alloc.invoiceDate!),
                    ),
                  ),
                  DataCell(
                    alloc.invoiceTotal == null
                        ? const Text('—')
                        : MoneyDisplay(amount: alloc.invoiceTotal!),
                  ),
                  DataCell(MoneyDisplay(amount: alloc.allocatedAmount)),
                ],
              ),
          ],
        ),
      );
    }

    return Column(
      children: [
        for (final alloc in allocations)
          ListTile(
            title: Text(alloc.invoiceNumber ?? '—'),
            subtitle: alloc.invoiceDate == null
                ? null
                : Text(
                    MaterialLocalizations.of(
                      context,
                    ).formatMediumDate(alloc.invoiceDate!),
                  ),
            trailing: MoneyDisplay(amount: alloc.allocatedAmount),
            onTap: () => context.go(
              AppRoutes.invoiceDetailPath(alloc.invoiceId, type: invoiceType),
            ),
          ),
      ],
    );
  }
}

class VoucherDetailActions extends StatelessWidget {
  const VoucherDetailActions({
    required this.canCancel,
    required this.canPreview,
    required this.isSubmitting,
    required this.onCancel,
    required this.onPreview,
    super.key,
  });

  final bool canCancel;
  final bool canPreview;
  final bool isSubmitting;
  final VoidCallback onCancel;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!canCancel && !canPreview) return const SizedBox.shrink();
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (canPreview)
          OutlinedButton.icon(
            key: const Key('voucher-detail-preview'),
            onPressed: isSubmitting ? null : onPreview,
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: Text(l10n.documentPreviewAction),
          ),
        if (canCancel)
          OutlinedButton(
            onPressed: isSubmitting ? null : onCancel,
            child: Text(l10n.voucherCancelAction),
          ),
      ],
    );
  }
}

class VoucherJournalLinks extends StatelessWidget {
  const VoucherJournalLinks({required this.detail, super.key});

  final VoucherDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (detail.journalEntryId != null)
          TextButton(
            onPressed: () =>
                context.go(AppRoutes.journalDetailPath(detail.journalEntryId!)),
            child: Text(l10n.voucherJournalEntry),
          ),
        if (detail.reversalJournalEntryId != null)
          TextButton(
            onPressed: () => context.go(
              AppRoutes.journalDetailPath(detail.reversalJournalEntryId!),
            ),
            child: Text(l10n.voucherReversalJournal),
          ),
      ],
    );
  }
}

class _PartyRow extends StatelessWidget {
  const _PartyRow({required this.label, required this.name, this.onOpen});

  final String label;
  final String name;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        if (onOpen == null)
          Text(name, style: Theme.of(context).textTheme.bodyLarge)
        else
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(onPressed: onOpen, child: Text(name)),
          ),
      ],
    );
  }
}
