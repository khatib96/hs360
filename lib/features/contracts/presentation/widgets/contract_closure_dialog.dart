import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../invoices/presentation/widgets/invoice_design.dart';
import '../../domain/closure_draft.dart';
import '../../domain/contract_detail.dart';
import '../../domain/contract_return_condition.dart';
import '../contract_display_helpers.dart';
import '../contract_lifecycle_controller.dart';
import 'contract_cycle_day_field.dart';

Future<DateTime?> showContractClosureDialog(
  BuildContext context,
  WidgetRef ref, {
  required ContractDetail detail,
}) {
  return showDialog<DateTime?>(
    context: context,
    builder: (context) => _ContractClosureDialog(detail: detail),
  );
}

class _ContractClosureDialog extends ConsumerStatefulWidget {
  const _ContractClosureDialog({required this.detail});

  final ContractDetail detail;

  @override
  ConsumerState<_ContractClosureDialog> createState() =>
      _ContractClosureDialogState();
}

class _ContractClosureDialogState
    extends ConsumerState<_ContractClosureDialog> {
  ContractClosureType _closureType = ContractClosureType.normal;
  ContractReturnCondition _returnCondition =
      ContractReturnCondition.availableUsed;
  late DateTime _closeDate;
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _closeDate = DateTime(now.year, now.month, now.day);
  }

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lifecycle = ref.watch(contractLifecycleControllerProvider);
    final controller = ref.read(contractLifecycleControllerProvider.notifier);
    final material = MaterialLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.contractCloseRentalTitle),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (lifecycle.validationCodes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  contractValidationMessages(
                    l10n,
                    lifecycle.validationCodes,
                  ).join('\n'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (lifecycle.errorCode != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  contractErrorMessage(l10n, lifecycle.errorCode!),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ContractLabeledField(
              label: l10n.contractFieldCloseDate,
              child: ContractDatePickerField(
                value: _closeDate,
                firstDate: widget.detail.startDate,
                onPick: (date) {
                  if (date != null) setState(() => _closeDate = date);
                },
              ),
            ),
            const SizedBox(height: 12),
            ContractLabeledField(
              label: l10n.contractFieldClosureType,
              child: InputDecorator(
                decoration: InvoiceDesign.denseField(context),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ContractClosureType>(
                    isExpanded: true,
                    value: _closureType,
                    items: [
                      DropdownMenuItem(
                        value: ContractClosureType.normal,
                        child: Text(l10n.contractClosureTypeNormal),
                      ),
                      DropdownMenuItem(
                        value: ContractClosureType.earlyTermination,
                        child: Text(l10n.contractClosureTypeEarlyTermination),
                      ),
                    ],
                    onChanged: lifecycle.isSubmitting
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _closureType = value);
                            }
                          },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ContractLabeledField(
              label: l10n.contractFieldReturnCondition,
              child: InputDecorator(
                decoration: InvoiceDesign.denseField(context),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ContractReturnCondition>(
                    isExpanded: true,
                    value: _returnCondition,
                    items: [
                      for (final condition in ContractReturnCondition.values)
                        DropdownMenuItem(
                          value: condition,
                          child: Text(
                            contractReturnConditionLabel(l10n, condition),
                          ),
                        ),
                    ],
                    onChanged: lifecycle.isSubmitting
                        ? null
                        : (value) {
                            if (value != null) {
                              setState(() => _returnCondition = value);
                            }
                          },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ContractLabeledField(
              label: l10n.contractFieldClosureReason,
              child: TextFormField(
                controller: _reasonController,
                decoration: InvoiceDesign.denseField(context),
                maxLines: 3,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: lifecycle.isSubmitting
              ? null
              : () => Navigator.pop(context, null),
          child: Text(material.cancelButtonLabel),
        ),
        FilledButton(
          onPressed: lifecycle.isSubmitting ? null : () => _submit(controller),
          child: lifecycle.isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(l10n.contractCloseRentalAction),
        ),
      ],
    );
  }

  Future<void> _submit(ContractLifecycleController controller) async {
    final draft = ClosureDraft(
      contractId: widget.detail.id,
      closureType: _closureType,
      closeReason: _reasonController.text,
      returnCondition: _returnCondition,
      closeDate: _closeDate,
    );
    final error = await controller.closeContract(
      draft: draft,
      detail: widget.detail,
    );
    if (!mounted) return;
    if (error == null) {
      controller.clearTransientState();
      Navigator.pop(context, _closeDate);
    }
  }
}
