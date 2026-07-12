import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../auth/domain/app_session.dart';
import '../../../finance_shared/presentation/money_display.dart';
import '../../../invoices/presentation/widgets/invoice_design.dart';
import '../../../invoices/presentation/widgets/invoice_totals_panel.dart';
import '../../domain/contract_detail.dart';
import '../../domain/contract_permissions.dart';
import '../../domain/contract_schedule_event.dart';
import '../contract_display_helpers.dart';
import '../contract_product_row.dart';
import 'contract_cost_breakdown.dart';
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

    return ContractDetailPanel(
      title: l10n.contractSectionProducts,
      child: LayoutBuilder(
        key: const Key('contract-products-table'),
        builder: (context, constraints) {
          if (constraints.maxWidth < 620) {
            return _ContractProductCards(
              rows: rows,
              languageCode: languageCode,
            );
          }
          return _ContractProductsTable(rows: rows, languageCode: languageCode);
        },
      ),
    );
  }
}

class _ContractProductsTable extends StatelessWidget {
  const _ContractProductsTable({
    required this.rows,
    required this.languageCode,
  });

  final List<ContractProductRow> rows;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Table(
      columnWidths: const {
        0: FixedColumnWidth(105),
        1: FlexColumnWidth(1.5),
        2: FlexColumnWidth(1.25),
        3: FlexColumnWidth(),
        4: FixedColumnWidth(76),
        5: FixedColumnWidth(110),
      },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: const TableBorder(
        horizontalInside: BorderSide(color: InvoiceDesign.borderColor),
      ),
      children: [
        TableRow(
          decoration: const BoxDecoration(color: InvoiceDesign.headerFill),
          children: [
            _productHeader(context, l10n.productColumnSku),
            _productHeader(context, l10n.contractFieldProduct),
            _productHeader(context, l10n.contractFieldSerialNumber),
            _productHeader(context, l10n.productFieldGroup),
            _productHeader(context, l10n.contractFieldQuantity),
            _productHeader(context, l10n.contractFieldRefillFrequency),
          ],
        ),
        for (final row in rows)
          TableRow(
            children: [
              _productCell(row.productSku),
              _productCell(
                contractCustomerName(
                  languageCode: languageCode,
                  nameAr: row.productNameAr,
                  nameEn: row.productNameEn,
                ),
              ),
              _productCell(row.serialNumber, emptyWhenMissing: true),
              _productCell(
                contractCustomerName(
                  languageCode: languageCode,
                  nameAr: row.productGroupNameAr,
                  nameEn: row.productGroupNameEn,
                ),
              ),
              _productCell(
                row.quantity?.toString(),
                emptyWhenMissing: true,
                alignEnd: true,
              ),
              _productCell(
                row.refillFrequencyMonths?.toString(),
                emptyWhenMissing: true,
                alignEnd: true,
              ),
            ],
          ),
      ],
    );
  }
}

class _ContractProductCards extends StatelessWidget {
  const _ContractProductCards({required this.rows, required this.languageCode});

  final List<ContractProductRow> rows;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        for (var index = 0; index < rows.length; index++) ...[
          if (index > 0) const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  contractCustomerName(
                    languageCode: languageCode,
                    nameAr: rows[index].productNameAr,
                    nameEn: rows[index].productNameEn,
                  ),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  '${l10n.productColumnSku}: ${rows[index].productSku ?? ''}',
                ),
                Text(
                  '${l10n.productFieldGroup}: ${contractCustomerName(languageCode: languageCode, nameAr: rows[index].productGroupNameAr, nameEn: rows[index].productGroupNameEn)}',
                ),
                Text(
                  '${l10n.contractFieldSerialNumber}: ${rows[index].serialNumber ?? ''}',
                ),
                if (rows[index].quantity != null)
                  Text(
                    '${l10n.contractFieldQuantity}: ${rows[index].quantity}',
                  ),
                if (rows[index].refillFrequencyMonths != null)
                  Text(
                    '${l10n.contractFieldRefillFrequency}: ${rows[index].refillFrequencyMonths}',
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

Widget _productHeader(BuildContext context, String label) {
  return Padding(
    padding: InvoiceDesign.cellPadding,
    child: Text(
      label,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: InvoiceDesign.columnHeaderStyle(context),
    ),
  );
}

Widget _productCell(
  String? value, {
  bool emptyWhenMissing = false,
  bool alignEnd = false,
}) {
  final display = value?.trim().isNotEmpty == true
      ? value!.trim()
      : (emptyWhenMissing ? '' : '—');
  return Padding(
    padding: InvoiceDesign.cellPadding,
    child: Align(
      alignment: alignEnd
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Text(display, maxLines: 2, overflow: TextOverflow.ellipsis),
    ),
  );
}

class ContractValueSummarySection extends StatelessWidget {
  const ContractValueSummarySection({
    required this.detail,
    required this.session,
    super.key,
  });

  final ContractDetail detail;
  final AppSession? session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = Localizations.localeOf(context).languageCode;
    final durationMonths = contractDurationMonths(detail);
    final durationLabel = contractDurationLabel(l10n, durationMonths);
    final totalValue = contractDisplayTotalValue(detail);
    final monthly = detail.monthlyRentalValue;
    final canViewAssetCosts =
        session != null && canViewContractDeviceCost(session!);
    final canViewConsumableCosts =
        session != null && canViewContractOilCost(session!);
    final costRows = buildContractProductRows(detail)
        .where(
          (row) =>
              row.snapshotUnitCost != null &&
              row.snapshotMonthlyCost != null &&
              (row.isAsset ? canViewAssetCosts : canViewConsumableCosts),
        )
        .map(
          (row) => ContractCostRow(
            productName: contractCustomerName(
              languageCode: languageCode,
              nameAr: row.productNameAr,
              nameEn: row.productNameEn,
            ),
            productGroupName: contractCustomerName(
              languageCode: languageCode,
              nameAr: row.productGroupNameAr,
              nameEn: row.productGroupNameEn,
            ),
            quantity: row.isAsset ? Decimal.one : row.quantity ?? Decimal.one,
            unitCost: row.snapshotUnitCost!,
            monthlyCost: row.snapshotMonthlyCost!,
          ),
        )
        .toList();
    final totalMonthlyCost =
        session != null && canViewContractTotalCost(session!)
        ? detail.snapshotTotalMonthlyCost
        : null;
    final netMonthlyProfit = session != null && canViewContractProfit(session!)
        ? detail.snapshotMonthlyProfit
        : null;

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
          if (costRows.isNotEmpty ||
              totalMonthlyCost != null ||
              netMonthlyProfit != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Material(
                color: Colors.transparent,
                child: ExpansionTile(
                  key: const Key('contract-detail-financial-details'),
                  tilePadding: EdgeInsets.zero,
                  childrenPadding: EdgeInsets.zero,
                  title: Text(l10n.contractFinancialDetails),
                  children: [
                    ContractCostBreakdown(
                      key: const Key('contract-cost-breakdown'),
                      rows: costRows,
                      totalMonthlyCost: totalMonthlyCost,
                      netMonthlyProfit: netMonthlyProfit,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ContractUpcomingScheduleSection extends StatelessWidget {
  const ContractUpcomingScheduleSection({
    required this.detail,
    required this.languageCode,
    super.key,
  });

  final ContractDetail detail;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final events = detail.upcomingSchedule;

    if (events.isEmpty) {
      return ContractDetailPanel(
        key: const Key('contract-upcoming-schedule-section'),
        title: l10n.contractSectionUpcomingSchedule,
        child: Text(
          l10n.contractScheduleEmpty,
          key: const Key('contract-upcoming-schedule-empty'),
        ),
      );
    }

    return ContractDetailPanel(
      key: const Key('contract-upcoming-schedule-section'),
      title: l10n.contractSectionUpcomingSchedule,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < events.length; i++) ...[
            if (i > 0) const Divider(height: 20),
            _ScheduleEventRow(
              key: Key('contract-upcoming-schedule-event-$i'),
              event: events[i],
              languageCode: languageCode,
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleEventRow extends StatelessWidget {
  const _ScheduleEventRow({
    required this.event,
    required this.languageCode,
    super.key,
  });

  final ContractScheduleEvent event;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final productName = contractScheduleProductName(
      languageCode: languageCode,
      nameAr: event.productNameAr,
      nameEn: event.productNameEn,
    );
    final showProduct = productName != '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          contractScheduleEventTypeLabel(l10n, event.type),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        ContractInfoRow(
          label: l10n.contractFieldEffectiveDate,
          value: formatContractDate(event.scheduledDate),
        ),
        if (event.daysRemaining != null)
          ContractInfoRow(
            label: l10n.contractScheduleRemaining,
            value: formatRemainingDays(l10n, event.daysRemaining!),
          ),
        if (showProduct)
          ContractInfoRow(
            label: l10n.contractProductTypeConsumable,
            value: productName,
          ),
        if (event.isConsumableChange)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.contractScheduleEventConsumableChange,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class ContractHistorySection extends StatelessWidget {
  const ContractHistorySection({required this.detail, super.key});

  final ContractDetail detail;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rows = <Widget>[];

    if (detail.extensionReason?.trim().isNotEmpty == true) {
      rows.add(
        ContractInfoRow(
          label: l10n.contractFieldExtensionReason,
          value: detail.extensionReason!,
        ),
      );
    }
    if (detail.returnReason?.trim().isNotEmpty == true) {
      rows.add(
        ContractInfoRow(
          label: l10n.contractFieldReturnReason,
          value: detail.returnReason!,
        ),
      );
    }
    if (detail.closureReason?.trim().isNotEmpty == true) {
      rows.add(
        ContractInfoRow(
          label: l10n.contractFieldClosureReason,
          value: detail.closureReason!,
        ),
      );
    }
    if (detail.returnedAt != null) {
      rows.add(
        ContractInfoRow(
          label: l10n.contractFieldReturnedAt,
          value: formatContractDate(detail.returnedAt!),
        ),
      );
    }
    if (detail.closedAt != null) {
      rows.add(
        ContractInfoRow(
          label: l10n.contractFieldClosedAt,
          value: formatContractDate(detail.closedAt!),
        ),
      );
    }

    return ContractDetailPanel(
      title: l10n.contractSectionHistory,
      child: rows.isEmpty
          ? Text(l10n.contractHistoryEmpty)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: rows,
            ),
    );
  }
}
