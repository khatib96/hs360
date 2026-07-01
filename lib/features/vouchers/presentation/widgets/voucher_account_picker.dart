import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/localization/locale_controller.dart';
import '../../domain/voucher_type.dart';
import '../voucher_form_controller.dart';
import 'voucher_account_search_field.dart';

class VoucherAccountPicker extends ConsumerWidget {
  const VoucherAccountPicker({required this.voucherType, super.key});

  final VoucherType voucherType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = ref.watch(localeProvider).languageCode;
    final state = ref.watch(voucherFormControllerProvider(voucherType));
    final controller = ref.read(
      voucherFormControllerProvider(voucherType).notifier,
    );

    if (!state.canLoadCashAccounts) {
      return const SizedBox.shrink();
    }

    final sourceAccountId = state.form.cashAccountId.trim();
    final accounts = state.postingAccounts
        .where((account) => account.id != sourceAccountId)
        .toList();
    final selectedId =
        accounts.any((account) => account.id == state.form.accountId)
        ? state.form.accountId
        : null;
    final label = switch (voucherType) {
      VoucherType.receipt =>
        languageCode.startsWith('ar') ? 'قبض من حساب' : 'Receive from account',
      VoucherType.payment => l10n.voucherPaymentDestinationAccount,
    };

    return VoucherAccountSearchField(
      accounts: accounts,
      selectedAccountId: selectedId,
      languageCode: languageCode,
      label: label,
      onSelected: controller.setAccountId,
    );
  }
}
