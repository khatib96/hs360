import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/errors/customer_exception.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../data/customer_repository.dart';
import '../../domain/customer.dart';
import '../../domain/customer_permissions.dart';
import '../../domain/customer_type.dart';
import '../customer_error_messages.dart';
import '../customer_form_draft.dart';

/// Minimal customer create dialog for fast checkout flows (e.g. invoice form).
///
/// Collects only the fields required by [CustomerValidator] for create and
/// returns the created [Customer] on success. Does not leave the caller flow.
class CustomerQuickCreateDialog extends ConsumerStatefulWidget {
  const CustomerQuickCreateDialog({super.key});

  @override
  ConsumerState<CustomerQuickCreateDialog> createState() =>
      _CustomerQuickCreateDialogState();
}

class _CustomerQuickCreateDialogState
    extends ConsumerState<CustomerQuickCreateDialog> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final session = ref.read(authControllerProvider).valueOrNull;
    final l10n = AppLocalizations.of(context)!;
    if (session == null || !canCreateCustomer(session)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.financeErrorPermissionDenied)),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final draft = CustomerFormDraft(
        nameAr: _nameController.text.trim(),
        phonePrimary: _phoneController.text.trim(),
        customerType: CustomerType.individual,
      );
      final created = await ref
          .read(customerRepositoryProvider)
          .createCustomer(session, draft.toFormState());
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } on CustomerException catch (e) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(customerErrorMessage(l10n, e.code))),
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _isSubmitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(customerErrorMessage(l10n, CustomerException.unknown))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final material = MaterialLocalizations.of(context);

    return AlertDialog(
      title: Text(l10n.invoiceFormNewCustomer),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _nameController,
              autofocus: true,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(labelText: l10n.customerFieldNameAr),
              onSubmitted: (_) => FocusScope.of(context).nextFocus(),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.done,
              decoration: InputDecoration(labelText: l10n.customerFieldPhonePrimary),
              onSubmitted: (_) => _submit(),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: Text(material.cancelButtonLabel),
        ),
        FilledButton(
          onPressed: _isSubmitting ? null : _submit,
          child: _isSubmitting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(material.saveButtonLabel),
        ),
      ],
    );
  }
}
