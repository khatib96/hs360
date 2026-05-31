import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/supplier.dart';
import '../../domain/supplier_form_state.dart';
import '../supplier_error_messages.dart';
import '../supplier_form_draft.dart';
import '../supplier_list_controller.dart';
import 'supplier_form.dart';

/// Shell only: wraps [SupplierForm] in an [AlertDialog] and routes
/// create/update through [SupplierListController]. Closes on success; stays
/// open and shows a localized error on failure.
class SupplierFormDialog extends ConsumerStatefulWidget {
  const SupplierFormDialog({this.initial, super.key});

  final Supplier? initial;

  @override
  ConsumerState<SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends ConsumerState<SupplierFormDialog> {
  bool _isSubmitting = false;

  bool get _isEdit => widget.initial != null;

  Future<void> _onSubmit(SupplierFormState formState) async {
    setState(() => _isSubmitting = true);
    final controller = ref.read(supplierListControllerProvider.notifier);
    final errorCode = _isEdit
        ? await controller.updateSupplier(widget.initial!.id, formState)
        : await controller.createSupplier(formState);

    if (!mounted) return;

    if (errorCode == null) {
      final l10n = AppLocalizations.of(context)!;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_isEdit ? l10n.supplierUpdated : l10n.supplierCreated),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(supplierErrorMessage(AppLocalizations.of(context)!, errorCode)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final initial = widget.initial;
    final draft = initial == null
        ? SupplierFormDraft.empty()
        : SupplierFormDraft.fromSupplier(initial);

    return AlertDialog(
      title: Text(_isEdit ? l10n.editSupplierTitle : l10n.createSupplierTitle),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: SupplierForm(
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
