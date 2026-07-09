import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../finance_shared/presentation/money_display.dart';
import '../../../invoices/presentation/widgets/invoice_design.dart';
import '../../../invoices/presentation/widgets/invoice_totals_panel.dart';
import '../../domain/contract_detail.dart';
import '../contract_display_helpers.dart';
import 'contract_detail_panel.dart';

class ContractDetailHeader extends StatelessWidget {
  const ContractDetailHeader({
    required this.detail,
    required this.languageCode,
    super.key,
  });

  final ContractDetail detail;
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
              detail.contractNumber ?? '—',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            ContractStatusChip(
              label: contractStatusLabel(l10n, detail.status),
              isClosed: detail.status.isClosed,
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(contractTypeLabel(l10n, detail.type)),
        const SizedBox(height: 4),
        Text(
          contractCustomerName(
            languageCode: languageCode,
            nameAr: detail.customerNameAr,
            nameEn: detail.customerNameEn,
          ),
        ),
        if (detail.serviceLocationName?.trim().isNotEmpty == true) ...[
          const SizedBox(height: 4),
          Text(detail.serviceLocationName!),
        ],
      ],
    );
  }
}

class ContractOverviewSection extends StatelessWidget {
  const ContractOverviewSection({required this.detail, super.key});

  final ContractDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final durationMonths = contractDurationMonths(detail);
    final durationLabel = contractDurationLabel(l10n, durationMonths);
    final totalValue = contractDisplayTotalValue(detail);

    return ContractDetailPanel(
      title: l10n.contractSectionOverview,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ContractInfoRow(
            label: l10n.contractColumnStartDate,
            value: formatContractDate(detail.startDate),
          ),
          if (detail.endDate != null)
            ContractInfoRow(
              label: l10n.contractFieldEndDate,
              value: formatContractDate(detail.endDate!),
            ),
          if (detail.trialEndDate != null && detail.endDate == null)
            ContractInfoRow(
              label: l10n.contractFieldTrialEndDate,
              value: formatContractDate(detail.trialEndDate!),
            ),
          if (durationLabel != null)
            ContractInfoRow(
              label: l10n.contractFieldContractDuration,
              value: durationLabel,
            ),
          if (detail.monthlyRentalValue != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 180,
                    child: Text(
                      l10n.contractFieldMonthlyRentalValue,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  MoneyDisplay(amount: detail.monthlyRentalValue!),
                ],
              ),
            ),
          if (totalValue != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 180,
                    child: Text(
                      l10n.contractFieldTotalContractValue,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  MoneyDisplay(amount: totalValue),
                ],
              ),
            ),
          if (detail.billingDay != null)
            ContractInfoRow(
              label: l10n.contractFieldBillingDay,
              value: detail.billingDay.toString(),
            ),
          if (detail.refillDay != null)
            ContractInfoRow(
              label: l10n.contractFieldRefillDay,
              value: detail.refillDay.toString(),
            ),
          if (detail.notes?.trim().isNotEmpty == true)
            ContractInfoRow(
              label: l10n.contractFieldNotes,
              value: detail.notes!,
            ),
        ],
      ),
    );
  }
}

class ContractProductsSection extends StatelessWidget {
  const ContractProductsSection({
    required this.detail,
    required this.languageCode,
    super.key,
  });

  final ContractDetail detail;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rows = buildContractProductRows(detail);

    if (rows.isEmpty) {
      return ContractDetailPanel(
        title: l10n.contractSectionProducts,
        child: Text(l10n.contractProductsEmpty),
      );
    }

    final showSerial = rows.any(
      (row) => row.serialNumber?.trim().isNotEmpty == true,
    );

    return ContractDetailPanel(
      title: l10n.contractSectionProducts,
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          key: const Key('contract-products-table'),
          headingRowColor: WidgetStateProperty.all(InvoiceDesign.headerFill),
          headingTextStyle: InvoiceDesign.columnHeaderStyle(context),
          columns: [
            DataColumn(label: Text(l10n.contractFieldProduct)),
            DataColumn(label: Text(l10n.contractFieldProductType)),
            if (showSerial)
              DataColumn(label: Text(l10n.contractFieldSerialNumber)),
            DataColumn(label: Text(l10n.contractFieldQuantity)),
            DataColumn(label: Text(l10n.contractFieldRefillFrequency)),
          ],
          rows: [
            for (final row in rows)
              DataRow(
                cells: [
                  DataCell(
                    Text(
                      contractCustomerName(
                        languageCode: languageCode,
                        nameAr: row.productNameAr,
                        nameEn: row.productNameEn,
                      ),
                    ),
                  ),
                  DataCell(Text(contractProductTypeLabel(l10n, row.isAsset))),
                  if (showSerial)
                    DataCell(
                      Text(
                        row.serialNumber?.trim().isNotEmpty == true
                            ? row.serialNumber!
                            : '—',
                      ),
                    ),
                  DataCell(Text(row.quantity?.toString() ?? '—')),
                  DataCell(Text(row.refillFrequencyMonths?.toString() ?? '—')),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class ContractValueSummarySection extends StatelessWidget {
  const ContractValueSummarySection({required this.detail, super.key});

  final ContractDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final durationMonths = contractDurationMonths(detail);
    final durationLabel = contractDurationLabel(l10n, durationMonths);
    final totalValue = contractDisplayTotalValue(detail);
    final monthly = detail.monthlyRentalValue;

    if (monthly == null && totalValue == null && durationLabel == null) {
      return const SizedBox.shrink();
    }

    final rows = <InvoiceTotalsRow>[
      if (monthly != null)
        InvoiceTotalsRow(l10n.contractFieldMonthlyRentalValue, monthly),
    ];

    return ContractDetailPanel(
      title: l10n.contractSectionValueSummary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (durationLabel != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(child: Text(l10n.contractFieldContractDuration)),
                  Text(durationLabel),
                ],
              ),
            ),
          if (rows.isNotEmpty)
            InvoiceTotalsBlock(
              rows: [
                ...rows,
                if (totalValue != null)
                  InvoiceTotalsRow(
                    l10n.contractFieldTotalContractValue,
                    totalValue,
                    emphasized: true,
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class ContractUpcomingScheduleSection extends StatelessWidget {
  const ContractUpcomingScheduleSection({required this.detail, super.key});

  final ContractDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // No schedule RPC in M8: never infer dates from billingDay/refillDay.
    return ContractDetailPanel(
      title: l10n.contractSectionUpcomingSchedule,
      child: Text(l10n.contractScheduleEmpty),
    );
  }
}

class ContractHistorySection extends StatelessWidget {
  const ContractHistorySection({required this.detail, super.key});

  final ContractDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ContractDetailPanel(
      title: l10n.contractSectionHistory,
      child: Text(l10n.contractHistoryEmpty),
    );
  }
}
