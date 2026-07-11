import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../invoices/presentation/widgets/invoice_design.dart';
import '../../domain/contract_detail.dart';
import '../../domain/contract_return_condition.dart';
import '../../domain/trial_return_draft.dart';
import '../contract_display_helpers.dart';
import '../contract_lifecycle_controller.dart';
import 'contract_cycle_day_field.dart';

Future<bool?> showContractTrialReturnDialog(
  BuildContext context,
  WidgetRef ref, {
  required ContractDetail detail,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _ContractTrialReturnDialog(detail: detail),
  );
}

class _ContractTrialReturnDialog extends ConsumerStatefulWidget {
  const _ContractTrialReturnDialog({required this.detail});

  final ContractDetail detail;

  @override
  ConsumerState<_ContractTrialReturnDialog> createState() =>
      _ContractTrialReturnDialogState();
}

class _ContractTrialReturnDialogState
    extends ConsumerState<_ContractTrialReturnDialog> {
  ContractReturnCondition _condition = ContractReturnCondition.availableUsed;
  final _reasonController = TextEditingController();

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
      title: Text(l10n.contractReturnTrialTitle),
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
              label: l10n.contractFieldReturnCondition,
              child: InputDecorator(
                decoration: InvoiceDesign.denseField(context),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<ContractReturnCondition>(
                    isExpanded: true,
                    value: _condition,
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
                              setState(() => _condition = value);
                            }
                          },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ContractLabeledField(
              label: l10n.contractFieldReturnReason,
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
              : () => Navigator.pop(context, false),
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
              : Text(l10n.contractReturnTrialAction),
        ),
      ],
    );
  }

  Future<void> _submit(ContractLifecycleController controller) async {
    final draft = TrialReturnDraft(
      trialContractId: widget.detail.id,
      returnCondition: _condition,
      reason: _reasonController.text,
    );
    final error = await controller.returnTrial(draft: draft);
    if (!mounted) return;
    if (error == null) {
      controller.clearTransientState();
      Navigator.pop(context, true);
    }
  }
}
