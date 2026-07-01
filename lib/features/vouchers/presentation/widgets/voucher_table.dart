import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../finance_shared/presentation/money_display.dart';
import '../../../finance_shared/domain/party_reference.dart';
import '../../../invoices/presentation/widgets/invoice_design.dart';
import '../../domain/voucher_summary.dart';
import '../../domain/voucher_type.dart';
import '../voucher_display_helpers.dart';
import 'voucher_shared_widgets.dart';

class VoucherTable extends StatelessWidget {
  const VoucherTable({
    required this.vouchers,
    required this.languageCode,
    super.key,
  });

  final List<VoucherSummary> vouchers;
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
          headingRowColor: WidgetStateProperty.all(InvoiceDesign.headerFill),
          headingTextStyle: InvoiceDesign.columnHeaderStyle(context),
          dataTextStyle: Theme.of(context).textTheme.bodyMedium,
          columnSpacing: 28,
          horizontalMargin: 14,
          dataRowMinHeight: 44,
          dataRowMaxHeight: 52,
          showCheckboxColumn: false,
          columns: [
            DataColumn(label: Text(l10n.voucherColumnNumber)),
            DataColumn(label: Text(l10n.voucherFilterType)),
            DataColumn(label: Text(l10n.financeColumnParty)),
            DataColumn(label: Text(l10n.financeColumnDate)),
            DataColumn(numeric: true, label: Text(l10n.financeColumnAmount)),
            DataColumn(numeric: true, label: Text(l10n.voucherAllocatedAmount)),
            DataColumn(
              numeric: true,
              label: Text(l10n.voucherUnallocatedAmount),
            ),
            DataColumn(label: Text(l10n.financeColumnStatus)),
          ],
          rows: [
            for (final voucher in vouchers)
              DataRow(
                onSelectChanged: (_) =>
                    context.go(AppRoutes.voucherDetailPath(voucher.id)),
                cells: [
                  DataCell(Text(voucher.voucherNumber ?? '—')),
                  DataCell(Text(voucherTypeLabel(l10n, voucher.type))),
                  DataCell(Text(_partyName(voucher))),
                  DataCell(Text(_formatDate(context, voucher.date))),
                  DataCell(MoneyDisplay(amount: voucher.amount)),
                  DataCell(MoneyDisplay(amount: voucher.allocatedAmount)),
                  DataCell(MoneyDisplay(amount: voucher.unallocatedAmount)),
                  DataCell(_statusCell(context, l10n, voucher)),
                ],
              ),
          ],
        ),
      ),
    );
  }

  String _partyName(VoucherSummary voucher) {
    final party = _partyFor(voucher);
    if (party == null) return '—';
    return party.displayName(languageCode);
  }
}

class VoucherCardList extends StatelessWidget {
  const VoucherCardList({
    required this.vouchers,
    required this.languageCode,
    super.key,
  });

  final List<VoucherSummary> vouchers;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView.separated(
      itemCount: vouchers.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final voucher = vouchers[index];
        final party = _partyFor(voucher);
        return Card(
          margin: EdgeInsets.zero,
          child: InkWell(
            onTap: () => context.go(AppRoutes.voucherDetailPath(voucher.id)),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          voucher.voucherNumber ?? '—',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      _statusCell(context, l10n, voucher),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(voucherTypeLabel(l10n, voucher.type)),
                  const SizedBox(height: 4),
                  Text(party?.displayName(languageCode) ?? '—'),
                  const SizedBox(height: 4),
                  Text(_formatDate(context, voucher.date)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Text('${l10n.financeColumnAmount}: '),
                      MoneyDisplay(amount: voucher.amount),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text('${l10n.voucherUnallocatedAmount}: '),
                      MoneyDisplay(amount: voucher.unallocatedAmount),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

Widget _statusCell(
  BuildContext context,
  AppLocalizations l10n,
  VoucherSummary voucher,
) {
  return voucherStatusChip(
    context,
    voucherStatusLabel(l10n, voucher.status),
    cancelled: voucher.status.isCancelled,
  );
}

String _formatDate(BuildContext context, DateTime date) {
  return MaterialLocalizations.of(context).formatMediumDate(date);
}

PartyReference? _partyFor(VoucherSummary voucher) {
  return switch (voucher.type) {
    VoucherType.receipt => voucher.customer,
    VoucherType.payment => voucher.supplier,
  };
}
