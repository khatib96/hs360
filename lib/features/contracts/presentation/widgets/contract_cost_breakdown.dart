import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../finance_shared/presentation/money_display.dart';
import '../../../invoices/presentation/widgets/invoice_design.dart';

class ContractCostRow {
  const ContractCostRow({
    required this.productName,
    this.productGroupName,
    required this.quantity,
    required this.unitCost,
    required this.monthlyCost,
  });

  final String productName;
  final String? productGroupName;
  final Decimal quantity;
  final Decimal unitCost;
  final Decimal monthlyCost;
}

class ContractCostBreakdown extends StatelessWidget {
  const ContractCostBreakdown({
    required this.rows,
    this.totalMonthlyCost,
    this.netMonthlyProfit,
    super.key,
  });

  final List<ContractCostRow> rows;
  final Decimal? totalMonthlyCost;
  final Decimal? netMonthlyProfit;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (rows.isNotEmpty)
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 620) {
                return _CostCards(rows: rows);
              }
              return _CostTable(rows: rows);
            },
          ),
        if (totalMonthlyCost != null)
          _FinancialTotal(
            label: l10n.contractFieldTotalMonthlyCost,
            amount: totalMonthlyCost!,
          ),
        if (netMonthlyProfit != null)
          _FinancialTotal(
            label: l10n.contractFieldNetMonthlyProfit,
            amount: netMonthlyProfit!,
            emphasized: true,
          ),
      ],
    );
  }
}

class _CostTable extends StatelessWidget {
  const _CostTable({required this.rows});

  final List<ContractCostRow> rows;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final showGroup = rows.any(
      (row) => row.productGroupName?.trim().isNotEmpty == true,
    );
    return Table(
      columnWidths: showGroup
          ? const {
              0: FlexColumnWidth(1.6),
              1: FlexColumnWidth(),
              2: FixedColumnWidth(90),
              3: FixedColumnWidth(130),
              4: FixedColumnWidth(150),
            }
          : const {
              0: FlexColumnWidth(1.6),
              1: FixedColumnWidth(90),
              2: FixedColumnWidth(130),
              3: FixedColumnWidth(150),
            },
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      border: const TableBorder(
        horizontalInside: BorderSide(color: InvoiceDesign.borderColor),
      ),
      children: [
        TableRow(
          decoration: const BoxDecoration(color: InvoiceDesign.headerFill),
          children: [
            _header(context, l10n.contractFieldProduct),
            if (showGroup) _header(context, l10n.productFieldGroup),
            _header(context, l10n.contractFieldQuantity),
            _header(context, l10n.contractFieldUnitCost),
            _header(context, l10n.contractFieldMonthlyCost),
          ],
        ),
        for (final row in rows)
          TableRow(
            children: [
              _textCell(row.productName),
              if (showGroup) _textCell(row.productGroupName ?? ''),
              _textCell(row.quantity.toString(), alignEnd: true),
              _moneyCell(row.unitCost),
              _moneyCell(row.monthlyCost, emphasized: true),
            ],
          ),
      ],
    );
  }
}

class _CostCards extends StatelessWidget {
  const _CostCards({required this.rows});

  final List<ContractCostRow> rows;

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
                  rows[index].productName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 6),
                if (rows[index].productGroupName?.trim().isNotEmpty == true)
                  _CardRow(
                    label: l10n.productFieldGroup,
                    value: Text(rows[index].productGroupName!),
                  ),
                _CardRow(
                  label: l10n.contractFieldQuantity,
                  value: Text(rows[index].quantity.toString()),
                ),
                _CardRow(
                  label: l10n.contractFieldUnitCost,
                  value: MoneyDisplay(amount: rows[index].unitCost),
                ),
                _CardRow(
                  label: l10n.contractFieldMonthlyCost,
                  value: MoneyDisplay(amount: rows[index].monthlyCost),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          value,
        ],
      ),
    );
  }
}

class _FinancialTotal extends StatelessWidget {
  const _FinancialTotal({
    required this.label,
    required this.amount,
    this.emphasized = false,
  });

  final String label;
  final Decimal amount;
  final bool emphasized;

  @override
  Widget build(BuildContext context) {
    final style = emphasized ? Theme.of(context).textTheme.titleSmall : null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: InvoiceDesign.borderColor)),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          MoneyDisplay(amount: amount, style: style),
        ],
      ),
    );
  }
}

Widget _header(BuildContext context, String label) {
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

Widget _textCell(String value, {bool alignEnd = false}) {
  return Padding(
    padding: InvoiceDesign.cellPadding,
    child: Align(
      alignment: alignEnd
          ? AlignmentDirectional.centerEnd
          : AlignmentDirectional.centerStart,
      child: Text(value, maxLines: 2, overflow: TextOverflow.ellipsis),
    ),
  );
}

Widget _moneyCell(Decimal amount, {bool emphasized = false}) {
  return Padding(
    padding: InvoiceDesign.cellPadding,
    child: Align(
      alignment: AlignmentDirectional.centerEnd,
      child: MoneyDisplay(
        amount: amount,
        style: emphasized ? const TextStyle(fontWeight: FontWeight.w600) : null,
      ),
    ),
  );
}
