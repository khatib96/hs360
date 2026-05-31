import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/customer.dart';
import '../../domain/customer_form_state.dart';
import '../customer_error_messages.dart';
import '../customer_form_draft.dart';
import '../customer_list_controller.dart';
import 'customer_form.dart';

/// Shell only: wraps the shared [CustomerForm] in an [AlertDialog] and routes
/// create/update through [CustomerListController]. Closes on success; stays
/// open and shows a localized error on failure.
class CustomerFormDialog extends ConsumerStatefulWidget {
  const CustomerFormDialog({this.initial, super.key});

  /// Existing customer when editing; null when creating.
  final Customer? initial;

  @override
  ConsumerState<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends ConsumerState<CustomerFormDialog> {
  bool _isSubmitting = false;

  bool get _isEdit => widget.initial != null;

  Future<void> _onSubmit(CustomerFormState formState) async {
    setState(() => _isSubmitting = true);
    final controller = ref.read(customerListControllerProvider.notifier);
    final errorCode = _isEdit
        ? await controller.updateCustomer(widget.initial!.id, formState)
        : await controller.createCustomer(formState);

    if (!mounted) return;

    if (errorCode == null) {
      final l10n = AppLocalizations.of(context)!;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit ? l10n.customerUpdated : l10n.customerCreated),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(customerErrorMessage(AppLocalizations.of(context)!, errorCode)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final initial = widget.initial;
    final draft = initial == null
        ? CustomerFormDraft.empty()
        : CustomerFormDraft.fromCustomer(initial);

    return AlertDialog(
      title: Text(_isEdit ? l10n.editCustomer : l10n.createCustomerTitle),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: CustomerForm(
            initialDraft: draft,
            isEdit: _isEdit,
            code: initial?.code,
            accountId: initial?.accountId,
            isSubmitting: _isSubmitting,
            submitLabel: MaterialLocalizations.of(context).saveButtonLabel,
            onSubmit: _onSubmit,
            onCancel: () => Navigator.of(context).pop(),
          ),
        ),
      ),
    );
  }
}
