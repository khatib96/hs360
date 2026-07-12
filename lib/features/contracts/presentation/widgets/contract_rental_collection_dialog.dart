import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../accounting/domain/chart_account.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../finance_shared/domain/payment_method.dart';
import '../../../finance_shared/presentation/finance_display_helpers.dart';
import '../../../invoices/presentation/widgets/invoice_design.dart';
import '../../domain/contract_detail.dart';
import '../../domain/contract_permissions.dart';
import '../contract_display_helpers.dart';
import '../contract_rental_collection_controller.dart';
import 'contract_cycle_day_field.dart';

Future<bool?> showContractRentalCollectionDialog(
  BuildContext context,
  WidgetRef ref, {
  required ContractDetail detail,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _ContractRentalCollectionDialog(detail: detail),
  );
}

class _ContractRentalCollectionDialog extends ConsumerStatefulWidget {
  const _ContractRentalCollectionDialog({required this.detail});

  final ContractDetail detail;

  @override
  ConsumerState<_ContractRentalCollectionDialog> createState() =>
      _ContractRentalCollectionDialogState();
}

class _ContractRentalCollectionDialogState
    extends ConsumerState<_ContractRentalCollectionDialog> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref
          .read(
            contractRentalCollectionControllerProvider(
              widget.detail.id,
            ).notifier,
          )
          .initialize(widget.detail);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final material = MaterialLocalizations.of(context);
    final session = ref.watch(authControllerProvider).valueOrNull;
    final canCollect = session != null && canCollectRentalPayment(session);
    final state = ref.watch(
      contractRentalCollectionControllerProvider(widget.detail.id),
    );
    final controller = ref.read(
      contractRentalCollectionControllerProvider(widget.detail.id).notifier,
    );

    return AlertDialog(
      title: Text(l10n.contractCollectRentalTitle),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.isLoadingMonths || state.isLoadingMeta)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: CircularProgressIndicator()),
                )
              else ...[
                if (state.validationCodes.isNotEmpty)
                  _errorText(
                    context,
                    contractValidationMessages(
                      l10n,
                      state.validationCodes,
                    ).join('\n'),
                  ),
                if (state.errorCode != null)
                  _errorText(
                    context,
                    contractErrorMessage(l10n, state.errorCode!),
                  ),
                if (state.eligibleMonthKeys.isEmpty)
                  Text(l10n.contractCollectNoEligibleMonths),
                if (state.eligibleMonthKeys.isNotEmpty) ...[
                  ContractLabeledField(
                    label: l10n.contractCollectCoverageMonths,
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final month in state.eligibleMonthKeys)
                          FilterChip(
                            key: Key('collect-month-$month'),
                            label: Text(month),
                            selected: state.selectedMonthKeys.contains(month),
                            onSelected: state.isSubmitting
                                ? null
                                : (_) async {
                                    controller.toggleMonth(
                                      month,
                                      widget.detail,
                                    );
                                    await controller.refreshPreview(
                                      widget.detail,
                                    );
                                  },
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  ContractLabeledField(
                    label: l10n.contractCollectCollectionDate,
                    child: ContractDatePickerField(
                      value: state.collectionDate ?? DateTime.now(),
                      firstDate: widget.detail.startDate,
                      onPick: (date) async {
                        if (date == null) return;
                        controller.setCollectionDate(date);
                        await controller.refreshPreview(widget.detail);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  ContractLabeledField(
                    label: l10n.contractCollectPaymentMethod,
                    child: InputDecorator(
                      decoration: InvoiceDesign.denseField(context),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<PaymentMethod>(
                          isExpanded: true,
                          value: state.paymentMethod,
                          items: PaymentMethod.values
                              .map(
                                (method) => DropdownMenuItem(
                                  value: method,
                                  child: Text(paymentMethodLabel(l10n, method)),
                                ),
                              )
                              .toList(),
                          onChanged: state.isSubmitting
                              ? null
                              : (value) async {
                                  if (value == null) return;
                                  controller.setPaymentMethod(value);
                                  await controller.refreshPreview(
                                    widget.detail,
                                  );
                                },
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ContractLabeledField(
                    label: l10n.contractCollectCashAccount,
                    child:
                        state.canLoadCashAccounts &&
                            state.cashBankAccounts.isNotEmpty
                        ? InputDecorator(
                            decoration: InvoiceDesign.denseField(context),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                isExpanded: true,
                                value: state.cashAccountId.trim().isEmpty
                                    ? null
                                    : state.cashAccountId,
                                items: [
                                  for (final account in state.cashBankAccounts)
                                    DropdownMenuItem(
                                      value: account.id,
                                      child: Text(_accountLabel(account)),
                                    ),
                                ],
                                onChanged: state.isSubmitting
                                    ? null
                                    : (value) async {
                                        if (value == null) return;
                                        controller.setCashAccountId(value);
                                        await controller.refreshPreview(
                                          widget.detail,
                                        );
                                      },
                              ),
                            ),
                          )
                        : Text(l10n.contractCollectCashAccountsUnavailable),
                  ),
                  const SizedBox(height: 12),
                  ContractLabeledField(
                    label: l10n.contractCollectReferenceNo,
                    child: TextFormField(
                      initialValue: state.referenceNo,
                      decoration: InvoiceDesign.denseField(context),
                      onChanged: controller.setReferenceNo,
                      onEditingComplete: () =>
                          controller.refreshPreview(widget.detail),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ContractLabeledField(
                    label: l10n.contractFieldNotes,
                    child: TextFormField(
                      initialValue: state.notes,
                      decoration: InvoiceDesign.denseField(context),
                      maxLines: 2,
                      onChanged: controller.setNotes,
                    ),
                  ),
                  if (state.preview != null) ...[
                    const SizedBox(height: 16),
                    Text(
                      l10n.contractCollectPreviewSubtotal,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(_money(state.preview!.subtotal)),
                    Text(
                      l10n.contractCollectPreviewTax,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(_money(state.preview!.taxAmount)),
                    Text(
                      l10n.contractCollectPreviewTotal,
                      style: Theme.of(context).textTheme.labelLarge,
                    ),
                    Text(_money(state.preview!.invoiceTotal)),
                    const SizedBox(height: 8),
                    Text(
                      l10n.contractCollectExpectedAmount,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      _money(state.preview!.expectedCollectedAmount),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                  if (state.showSuccessActions && state.lastResult != null) ...[
                    const SizedBox(height: 16),
                    Text(l10n.contractCollectSuccess),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          key: const Key('collect-view-invoice'),
                          onPressed: () => context.push(
                            AppRoutes.invoiceDetailPath(
                              state.lastResult!.invoiceId,
                            ),
                          ),
                          child: Text(l10n.contractCollectViewInvoice),
                        ),
                        OutlinedButton(
                          key: const Key('collect-view-receipt'),
                          onPressed: () => context.push(
                            AppRoutes.voucherDetailPath(
                              state.lastResult!.voucherId,
                            ),
                          ),
                          child: Text(l10n.contractCollectViewReceipt),
                        ),
                      ],
                    ),
                  ],
                ],
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: state.isSubmitting
              ? null
              : () {
                  controller.clearTransientState();
                  Navigator.pop(context, state.showSuccessActions);
                },
          child: Text(material.closeButtonLabel),
        ),
        if (canCollect && !state.showSuccessActions)
          FilledButton(
            key: const Key('collect-rental-submit'),
            onPressed: state.canConfirm ? () => _submit(controller) : null,
            child: state.isSubmitting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.contractCollectConfirmAction),
          ),
      ],
    );
  }

  Widget _errorText(BuildContext context, String message) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        message,
        style: TextStyle(color: Theme.of(context).colorScheme.error),
      ),
    );
  }

  String _accountLabel(ChartAccount account) {
    return '${account.code} · ${account.nameEn}';
  }

  String _money(Decimal? value) => value?.toString() ?? '—';

  Future<void> _submit(ContractRentalCollectionController controller) async {
    final result = await controller.submit(widget.detail);
    if (!mounted) return;
    if (result != null) {
      setState(() {});
    }
  }
}
