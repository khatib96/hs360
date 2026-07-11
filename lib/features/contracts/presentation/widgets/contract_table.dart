import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../finance_shared/presentation/money_display.dart';
import '../../../invoices/presentation/widgets/invoice_design.dart';
import '../../domain/contract_summary.dart';
import '../contract_display_helpers.dart';

class ContractTable extends StatelessWidget {
  const ContractTable({
    required this.contracts,
    required this.languageCode,
    super.key,
  });

  final List<ContractSummary> contracts;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxWidth < 760;
        final padding = compact ? 6.0 : 10.0;
        final columnWidths = <int, TableColumnWidth>{
          0: FixedColumnWidth(compact ? 118 : 138),
          1: const FlexColumnWidth(),
          2: FixedColumnWidth(compact ? 52 : 72),
          3: FixedColumnWidth(compact ? 58 : 78),
          4: FixedColumnWidth(compact ? 110 : 128),
          5: FixedColumnWidth(compact ? 102 : 116),
        };

        return Table(
          key: const Key('contract-table'),
          columnWidths: columnWidths,
          defaultVerticalAlignment: TableCellVerticalAlignment.middle,
          border: const TableBorder(
            horizontalInside: BorderSide(color: InvoiceDesign.borderColor),
          ),
          children: [
            TableRow(
              decoration: const BoxDecoration(color: InvoiceDesign.headerFill),
              children: [
                _headerCell(context, l10n.contractColumnNumber, padding),
                _headerCell(context, l10n.contractColumnCustomer, padding),
                _headerCell(context, l10n.contractColumnType, padding),
                _headerCell(context, l10n.contractColumnStatus, padding),
                _headerCell(context, l10n.contractColumnDates, padding),
                _headerCell(
                  context,
                  l10n.contractColumnMonthlyValue,
                  padding,
                  alignEnd: true,
                ),
              ],
            ),
            for (final contract in contracts)
              TableRow(
                children: [
                  _cell(
                    context,
                    FittedBox(
                      alignment: AlignmentDirectional.centerStart,
                      fit: BoxFit.scaleDown,
                      child: Text(contract.contractNumber ?? '—'),
                    ),
                    padding,
                    onTap: () =>
                        context.go(AppRoutes.contractDetailPath(contract.id)),
                  ),
                  _cell(
                    context,
                    _ContractCustomerCell(
                      name: contractCustomerName(
                        languageCode: languageCode,
                        nameAr: contract.customerNameAr,
                        nameEn: contract.customerNameEn,
                      ),
                      address: contractLocationSummary(
                        governorate: contract.locationGovernorate,
                        area: contract.locationArea,
                      ),
                    ),
                    padding,
                    onTap: () =>
                        context.go(AppRoutes.contractDetailPath(contract.id)),
                  ),
                  _cell(
                    context,
                    Text(contractTypeLabel(l10n, contract.type)),
                    padding,
                    onTap: () =>
                        context.go(AppRoutes.contractDetailPath(contract.id)),
                  ),
                  _cell(
                    context,
                    Text(contractStatusLabel(l10n, contract.status)),
                    padding,
                    onTap: () =>
                        context.go(AppRoutes.contractDetailPath(contract.id)),
                  ),
                  _cell(
                    context,
                    _ContractDatesCell(
                      startDate: contract.startDate,
                      endDate: contract.endDate,
                    ),
                    padding,
                    onTap: () =>
                        context.go(AppRoutes.contractDetailPath(contract.id)),
                  ),
                  _cell(
                    context,
                    contract.monthlyRentalValue == null
                        ? const Text('—')
                        : MoneyDisplay(amount: contract.monthlyRentalValue!),
                    padding,
                    alignEnd: true,
                    onTap: () =>
                        context.go(AppRoutes.contractDetailPath(contract.id)),
                  ),
                ],
              ),
          ],
        );
      },
    );
  }

  Widget _headerCell(
    BuildContext context,
    String text,
    double padding, {
    bool alignEnd = false,
  }) {
    return Padding(
      padding: EdgeInsetsDirectional.symmetric(
        horizontal: padding,
        vertical: 9,
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textAlign: alignEnd ? TextAlign.end : null,
        style: InvoiceDesign.columnHeaderStyle(context),
      ),
    );
  }

  Widget _cell(
    BuildContext context,
    Widget child,
    double padding, {
    required VoidCallback onTap,
    bool alignEnd = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: padding,
          vertical: 12,
        ),
        child: Align(
          alignment: alignEnd
              ? AlignmentDirectional.centerEnd
              : AlignmentDirectional.centerStart,
          child: DefaultTextStyle.merge(
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _ContractDatesCell extends StatelessWidget {
  const _ContractDatesCell({required this.startDate, required this.endDate});

  final DateTime startDate;
  final DateTime? endDate;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          formatContractDate(startDate),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style,
        ),
        Text(
          endDate == null ? '—' : formatContractDate(endDate!),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: style?.copyWith(color: Theme.of(context).hintColor),
        ),
      ],
    );
  }
}

class _ContractCustomerCell extends StatelessWidget {
  const _ContractCustomerCell({required this.name, required this.address});

  final String name;
  final String address;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(name, maxLines: 1, overflow: TextOverflow.ellipsis),
        if (address.isNotEmpty)
          Text(
            address,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: Theme.of(context).hintColor),
          ),
      ],
    );
  }
}

class ContractCardList extends StatelessWidget {
  const ContractCardList({
    required this.contracts,
    required this.languageCode,
    super.key,
  });

  final List<ContractSummary> contracts;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView.separated(
      itemCount: contracts.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final contract = contracts[index];
        final address = contractLocationSummary(
          governorate: contract.locationGovernorate,
          area: contract.locationArea,
        );
        return ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: InvoiceDesign.radius,
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
          title: Text(contract.contractNumber ?? '—'),
          subtitle: Text(
            '${contractCustomerName(languageCode: languageCode, nameAr: contract.customerNameAr, nameEn: contract.customerNameEn)}${address.isEmpty ? '' : ' · $address'} · ${contractTypeLabel(l10n, contract.type)} · ${contractStatusLabel(l10n, contract.status)}',
          ),
          trailing: contract.monthlyRentalValue == null
              ? null
              : MoneyDisplay(amount: contract.monthlyRentalValue!),
          onTap: () => context.go(AppRoutes.contractDetailPath(contract.id)),
        );
      },
    );
  }
}
