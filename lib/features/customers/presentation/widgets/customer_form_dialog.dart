import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/customer.dart';
import '../../domain/customer_form_state.dart';
import '../../domain/customer_permissions.dart';
import '../customer_error_messages.dart';
import '../customer_form_draft.dart';
import '../customer_list_controller.dart';
import '../../../auth/presentation/auth_controller.dart';
import 'customer_form.dart';

class CustomerFormDialog extends ConsumerStatefulWidget {
  const CustomerFormDialog({this.initial, super.key});

  final Customer? initial;

  @override
  ConsumerState<CustomerFormDialog> createState() => _CustomerFormDialogState();
}

class _CustomerFormDialogState extends ConsumerState<CustomerFormDialog> {
  bool _isSubmitting = false;
  bool _isEnsuringAccount = false;

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
        content: Text(
          customerErrorMessage(AppLocalizations.of(context)!, errorCode),
        ),
      ),
    );
  }

  Future<void> _onEnsureAccount() async {
    final customer = widget.initial;
    if (customer == null) return;
    setState(() => _isEnsuringAccount = true);
    final errorCode = await ref
        .read(customerListControllerProvider.notifier)
        .ensureAccount(customer.id);
    if (!mounted) return;
    setState(() => _isEnsuringAccount = false);
    final l10n = AppLocalizations.of(context)!;
    if (errorCode == null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.customerAccountLinked)));
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(customerErrorMessage(l10n, errorCode))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final initial = widget.initial;
    final draft = initial == null
        ? CustomerFormDraft.empty()
        : CustomerFormDraft.fromCustomer(initial);
    final session = ref.watch(authControllerProvider).valueOrNull;
    final width = MediaQuery.sizeOf(context).width;
    final dialogWidth = width >= 1000
        ? 960.0
        : (width >= 720 ? 900.0 : width * 0.95);

    return AlertDialog(
      title: Text(_isEdit ? l10n.editCustomer : l10n.createCustomerTitle),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: CustomerForm(
            initialDraft: draft,
            isEdit: _isEdit,
            code: initial?.code,
            hasLinkedAccount: initial?.hasLinkedAccount ?? false,
            canEnsureAccount: session != null && canEditCustomer(session),
            isEnsuringAccount: _isEnsuringAccount,
            onEnsureAccount: _isEdit ? _onEnsureAccount : null,
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
