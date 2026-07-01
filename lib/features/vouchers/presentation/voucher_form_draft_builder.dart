import 'package:decimal/decimal.dart';

import '../../accounting/domain/chart_account.dart';
import '../domain/voucher_form_state.dart';
import 'voucher_form_state.dart';

List<ChartAccount> filterPostingLeafAccounts(List<ChartAccount> accounts) {
  final parentIds = accounts
      .map((account) => account.parentId)
      .whereType<String>()
      .toSet();

  return accounts
      .where(
        (account) =>
            account.isActive &&
            !account.isEntityLinked &&
            !parentIds.contains(account.id),
      )
      .toList();
}

VoucherFormState buildSafeVoucherFormState(VoucherFormUiState ui) {
  final form = ui.form;
  final allocations = <VoucherAllocationInput>[];

  if (form.allocationMode == 'manual') {
    for (final invoice in ui.openInvoices) {
      final amount = ui.manualAllocationAmounts[invoice.id];
      if (amount != null && amount > Decimal.zero) {
        allocations.add(
          VoucherAllocationInput(
            invoiceId: invoice.id,
            allocatedAmount: amount,
          ),
        );
      }
    }
  }

  return VoucherFormState(
    type: form.type,
    customerId: ui.selectedCustomer?.id ?? form.customerId,
    supplierId: ui.selectedSupplier?.id ?? form.supplierId,
    accountId: form.accountId,
    date: form.date,
    amount: form.amount,
    paymentMethod: form.paymentMethod,
    cashAccountId: form.cashAccountId,
    referenceNo: form.referenceNo,
    notes: form.notes,
    allocationMode: form.allocationMode,
    allocations: allocations,
    paymentDestination: form.paymentDestination,
    cancellationReason: form.cancellationReason,
  );
}
