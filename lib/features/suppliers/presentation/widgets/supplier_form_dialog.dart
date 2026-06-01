import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../auth/presentation/auth_controller.dart';
import '../../domain/supplier.dart';
import '../../domain/supplier_form_state.dart';
import '../../domain/supplier_permissions.dart';
import '../supplier_error_messages.dart';
import '../supplier_form_draft.dart';
import '../supplier_list_controller.dart';
import 'supplier_form.dart';

class SupplierFormDialog extends ConsumerStatefulWidget {
  const SupplierFormDialog({this.initial, super.key});

  final Supplier? initial;

  @override
  ConsumerState<SupplierFormDialog> createState() => _SupplierFormDialogState();
}

class _SupplierFormDialogState extends ConsumerState<SupplierFormDialog> {
  bool _isSubmitting = false;
  bool _isEnsuringAccount = false;

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
        content: Text(supplierErrorMessage(AppLocalizations.of(context)!, errorCode)),
      ),
    );
  }

  Future<void> _onEnsureAccount() async {
    final supplier = widget.initial;
    if (supplier == null) return;
    setState(() => _isEnsuringAccount = true);
    final errorCode = await ref
        .read(supplierListControllerProvider.notifier)
        .ensureAccount(supplier.id);
    if (!mounted) return;
    setState(() => _isEnsuringAccount = false);
    final l10n = AppLocalizations.of(context)!;
    if (errorCode == null) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.supplierAccountLinked)),
      );
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(supplierErrorMessage(l10n, errorCode))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final initial = widget.initial;
    final draft = initial == null
        ? SupplierFormDraft.empty()
        : SupplierFormDraft.fromSupplier(initial);
    final session = ref.watch(authControllerProvider).valueOrNull;
    final width = MediaQuery.sizeOf(context).width;
    final dialogWidth = width >= 1000 ? 960.0 : (width >= 720 ? 900.0 : width * 0.95);

    return AlertDialog(
      title: Text(_isEdit ? l10n.editSupplierTitle : l10n.createSupplierTitle),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: SupplierForm(
            initialDraft: draft,
            isEdit: _isEdit,
            code: initial?.code,
            hasLinkedAccount: initial?.hasLinkedAccount ?? false,
            canEnsureAccount: session != null && canEditSupplier(session),
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
