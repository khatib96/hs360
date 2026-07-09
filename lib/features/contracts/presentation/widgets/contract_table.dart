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
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: MediaQuery.sizeOf(context).width - 32,
        ),
        child: DataTable(
          key: const Key('contract-table'),
          headingRowColor: WidgetStateProperty.all(InvoiceDesign.headerFill),
          headingTextStyle: InvoiceDesign.columnHeaderStyle(context),
          dataTextStyle: Theme.of(context).textTheme.bodyMedium,
          columnSpacing: 24,
          horizontalMargin: 14,
          dataRowMinHeight: 44,
          dataRowMaxHeight: 52,
          showCheckboxColumn: false,
          columns: [
            DataColumn(label: Text(l10n.contractColumnNumber)),
            DataColumn(label: Text(l10n.contractColumnCustomer)),
            DataColumn(label: Text(l10n.contractColumnType)),
            DataColumn(label: Text(l10n.contractColumnStatus)),
            DataColumn(label: Text(l10n.contractColumnStartDate)),
            DataColumn(
              numeric: true,
              label: Text(l10n.contractColumnMonthlyValue),
            ),
          ],
          rows: [
            for (final contract in contracts)
              DataRow(
                onSelectChanged: (_) =>
                    context.go(AppRoutes.contractDetailPath(contract.id)),
                cells: [
                  DataCell(Text(contract.contractNumber ?? '—')),
                  DataCell(
                    Text(
                      contractCustomerName(
                        languageCode: languageCode,
                        nameAr: contract.customerNameAr,
                        nameEn: contract.customerNameEn,
                      ),
                    ),
                  ),
                  DataCell(Text(contractTypeLabel(l10n, contract.type))),
                  DataCell(Text(contractStatusLabel(l10n, contract.status))),
                  DataCell(Text(formatContractDate(contract.startDate))),
                  DataCell(
                    contract.monthlyRentalValue == null
                        ? const Text('—')
                        : MoneyDisplay(amount: contract.monthlyRentalValue!),
                  ),
                ],
              ),
          ],
        ),
      ),
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
        return ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: InvoiceDesign.radius,
            side: BorderSide(color: Theme.of(context).dividerColor),
          ),
          title: Text(contract.contractNumber ?? '—'),
          subtitle: Text(
            '${contractCustomerName(languageCode: languageCode, nameAr: contract.customerNameAr, nameEn: contract.customerNameEn)} · ${contractTypeLabel(l10n, contract.type)} · ${contractStatusLabel(l10n, contract.status)}',
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
