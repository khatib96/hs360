import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/locale_controller.dart';
import '../../domain/voucher_type.dart';
import '../voucher_form_controller.dart';
import 'voucher_account_search_field.dart';

class CashBankAccountPicker extends ConsumerWidget {
  const CashBankAccountPicker({required this.voucherType, super.key});

  final VoucherType voucherType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(localeProvider);
    final state = ref.watch(voucherFormControllerProvider(voucherType));
    final controller = ref.read(
      voucherFormControllerProvider(voucherType).notifier,
    );

    if (!state.canLoadCashAccounts) {
      return const SizedBox.shrink();
    }

    final accounts = state.cashBankAccounts;
    final selectedId = state.form.cashAccountId.trim().isEmpty
        ? null
        : state.form.cashAccountId;
    final label = switch (voucherType) {
      VoucherType.receipt =>
        locale.languageCode.startsWith('ar')
            ? 'القبض إلى حساب'
            : 'Receive into account',
      VoucherType.payment =>
        locale.languageCode.startsWith('ar')
            ? 'الدفع من حساب'
            : 'Pay from account',
    };

    return VoucherAccountSearchField(
      accounts: accounts,
      selectedAccountId: accounts.any((a) => a.id == selectedId)
          ? selectedId
          : null,
      languageCode: locale.languageCode,
      label: label,
      onSelected: controller.setCashAccountId,
    );
  }
}
