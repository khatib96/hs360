import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/localization/locale_controller.dart';
import '../journal_display_helpers.dart';
import '../cash_bank_activity_controller.dart';

class CashBankAccountPicker extends ConsumerWidget {
  const CashBankAccountPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final state = ref.watch(cashBankActivityControllerProvider);
    final controller = ref.read(cashBankActivityControllerProvider.notifier);

    if (!state.canLoadCashAccounts) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.cashBankChartViewRequiredTitle,
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Text(
                l10n.cashBankChartViewRequiredBody,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    if (state.isLoadingMeta && state.cashBankAccounts.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final accounts = state.cashBankAccounts;
    final selectedId = state.accountId;

    return DropdownButtonFormField<String>(
      initialValue: accounts.any((a) => a.id == selectedId) ? selectedId : null,
      decoration: InputDecoration(labelText: l10n.cashBankSelectAccount),
      items: accounts
          .map(
            (account) => DropdownMenuItem(
              value: account.id,
              child: Text(
                journalAccountDisplayName(
                  locale.languageCode,
                  nameAr: account.nameAr,
                  nameEn: account.nameEn,
                  code: account.code,
                ),
              ),
            ),
          )
          .toList(),
      onChanged: controller.setAccountId,
    );
  }
}
