import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/domain/finance_permissions.dart';
import '../../finance_shared/presentation/finance_placeholder_screen.dart';
import '../../finance_shared/presentation/money_display.dart';
import 'cash_bank_activity_controller.dart';
import 'cash_bank_activity_state.dart';
import 'cash_bank_csv_export.dart';
import 'journal_display_helpers.dart';
import 'widgets/cash_bank_account_picker.dart';
import 'widgets/cash_bank_activity_table.dart';
import 'widgets/journal_shared_widgets.dart';

class CashBankActivityScreen extends ConsumerWidget {
  const CashBankActivityScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(authControllerProvider).valueOrNull;
    final state = ref.watch(cashBankActivityControllerProvider);
    final controller = ref.read(cashBankActivityControllerProvider.notifier);

    if (session != null && !canViewCashBank(session)) {
      return FinancePlaceholderScreen(
        titleGetter: (l) => l.cashBankTitle,
        bodyGetter: (l) => l.financeModuleAccessUnavailable,
        canView: (_) => false,
        currentRoute: AppRoutes.cashBank,
      );
    }

    Widget content;
    if (state.accountId == null || state.accountId!.isEmpty) {
      content = Center(child: Text(l10n.cashBankSelectAccount));
    } else if (state.isLoading && state.page == null) {
      content = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.loading),
          ],
        ),
      );
    } else if (state.hasError && state.page == null) {
      content = JournalErrorState(
        message: journalErrorMessage(l10n, state.errorCode!),
        onRetry: controller.refresh,
      );
    } else if (state.page != null && state.page!.rows.isEmpty) {
      content = Center(child: Text(l10n.cashBankActivityEmpty));
    } else if (state.page != null) {
      final isWide = MediaQuery.sizeOf(context).width > 768;
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Text('${l10n.cashBankOpeningBalance}: '),
              MoneyDisplay(amount: state.page!.openingBalance),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: isWide
                ? CashBankActivityTable(rows: state.page!.rows)
                : CashBankActivityCardList(rows: state.page!.rows),
          ),
          if (state.hasMore)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: state.isLoadingMore
                  ? const Center(child: CircularProgressIndicator())
                  : Center(
                      child: OutlinedButton(
                        onPressed: controller.loadMore,
                        child: Text(l10n.loadMore),
                      ),
                    ),
            ),
        ],
      );
    } else {
      content = Center(child: Text(l10n.cashBankSelectAccount));
    }

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const CashBankAccountPicker(),
        const SizedBox(height: 12),
        _CashBankDateFilters(
          dateFrom: state.dateRange.from,
          dateTo: state.dateRange.to,
          onDateFromChanged: controller.setDateFrom,
          onDateToChanged: controller.setDateTo,
        ),
        if (state.page != null && state.page!.rows.isNotEmpty) ...[
          const SizedBox(height: 12),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: OutlinedButton.icon(
              key: const Key('cash-bank-export-loaded-rows'),
              onPressed: () => _exportLoadedRows(context, l10n, state),
              icon: const Icon(Icons.download_outlined),
              label: Text(l10n.cashBankExportLoadedRows),
            ),
          ),
        ],
        const SizedBox(height: 16),
        Expanded(child: content),
      ],
    );

    return AppShell(
      title: l10n.cashBankTitle,
      currentRoute: AppRoutes.cashBank,
      body: Stack(
        children: [
          Padding(padding: const EdgeInsetsDirectional.all(24), child: body),
          if (state.isLoading && state.page != null)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  void _exportLoadedRows(
    BuildContext context,
    AppLocalizations l10n,
    CashBankActivityState state,
  ) {
    final page = state.page;
    if (page == null || page.rows.isEmpty) return;

    final csv = buildCashBankLoadedRowsCsv(
      accountCode: page.accountCode,
      accountName: page.accountNameEn,
      openingBalance: page.openingBalance,
      rows: page.rows,
      dateColumnLabel: l10n.financeColumnDate,
      entryColumnLabel: l10n.voucherColumnNumber,
      sourceColumnLabel: l10n.journalFilterSource,
      descriptionColumnLabel: l10n.financeColumnDescription,
      debitColumnLabel: l10n.financeColumnDebit,
      creditColumnLabel: l10n.financeColumnCredit,
      balanceColumnLabel: l10n.cashBankRunningBalance,
      openingBalanceLabel: l10n.cashBankOpeningBalance,
    );
    Clipboard.setData(ClipboardData(text: csv));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.cashBankExportLoadedRowsCopied)),
    );
  }
}

class _CashBankDateFilters extends StatelessWidget {
  const _CashBankDateFilters({
    required this.dateFrom,
    required this.dateTo,
    required this.onDateFromChanged,
    required this.onDateToChanged,
  });

  final DateTime? dateFrom;
  final DateTime? dateTo;
  final ValueChanged<DateTime?> onDateFromChanged;
  final ValueChanged<DateTime?> onDateToChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isWide = MediaQuery.sizeOf(context).width > 768;
    final fromField = _DateField(
      label: l10n.inventoryMovementsFilterDateFrom,
      value: dateFrom,
      onChanged: onDateFromChanged,
    );
    final toField = _DateField(
      label: l10n.inventoryMovementsFilterDateTo,
      value: dateTo,
      onChanged: onDateToChanged,
    );

    if (isWide) {
      return Row(
        children: [
          Expanded(child: fromField),
          const SizedBox(width: 12),
          Expanded(child: toField),
        ],
      );
    }

    return Column(children: [fromField, const SizedBox(height: 12), toField]);
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;

  @override
  Widget build(BuildContext context) {
    final text = value == null
        ? ''
        : MaterialLocalizations.of(context).formatMediumDate(value!);
    return TextFormField(
      readOnly: true,
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: value != null
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () => onChanged(null),
              )
            : const Icon(Icons.calendar_today_outlined),
      ),
      controller: TextEditingController(text: text),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: value ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}
