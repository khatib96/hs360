import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../invoices/presentation/widgets/invoice_design.dart';
import '../../domain/contract_detail.dart';
import '../../domain/trial_extension_draft.dart';
import '../contract_display_helpers.dart';
import '../contract_lifecycle_controller.dart';
import 'contract_cycle_day_field.dart';

Future<bool?> showContractTrialExtensionDialog(
  BuildContext context,
  WidgetRef ref, {
  required ContractDetail detail,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => _ContractTrialExtensionDialog(detail: detail),
  );
}

class _ContractTrialExtensionDialog extends ConsumerStatefulWidget {
  const _ContractTrialExtensionDialog({required this.detail});

  final ContractDetail detail;

  @override
  ConsumerState<_ContractTrialExtensionDialog> createState() =>
      _ContractTrialExtensionDialogState();
}

class _ContractTrialExtensionDialogState
    extends ConsumerState<_ContractTrialExtensionDialog> {
  late DateTime _newEndDate;
  final _reasonController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final current = widget.detail.trialEndDate ?? widget.detail.startDate;
    _newEndDate = current.add(const Duration(days: 7));
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
    final minDate = widget.detail.trialEndDate ?? widget.detail.startDate;

    return AlertDialog(
      title: Text(l10n.contractExtendTrialTitle),
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
              label: l10n.contractFieldTrialEndDate,
              child: ContractDatePickerField(
                value: _newEndDate,
                firstDate: minDate.add(const Duration(days: 1)),
                onPick: (date) {
                  if (date != null) setState(() => _newEndDate = date);
                },
              ),
            ),
            const SizedBox(height: 12),
            ContractLabeledField(
              label: l10n.contractFieldExtensionReason,
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
              : Text(l10n.contractExtendTrialAction),
        ),
      ],
    );
  }

  Future<void> _submit(ContractLifecycleController controller) async {
    final draft = TrialExtensionDraft(
      trialContractId: widget.detail.id,
      newTrialEndDate: _newEndDate,
      reason: _reasonController.text,
    );
    final error = await controller.extendTrial(
      draft: draft,
      detail: widget.detail,
    );
    if (!mounted) return;
    if (error == null) {
      controller.clearTransientState();
      Navigator.pop(context, true);
    }
  }
}
