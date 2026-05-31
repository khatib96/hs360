import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/message_banner.dart';
import '../../domain/supplier_form_state.dart';
import '../supplier_error_messages.dart';
import '../supplier_form_draft.dart';

/// Single source of truth for supplier form fields, shared by the dialog and
/// any future supplier edit surface. Builds and validates a [SupplierFormDraft]
/// before calling [onSubmit].
class SupplierForm extends StatefulWidget {
  const SupplierForm({
    required this.initialDraft,
    required this.isEdit,
    required this.isSubmitting,
    required this.submitLabel,
    required this.onSubmit,
    required this.onCancel,
    this.code,
    this.accountId,
    super.key,
  });

  final SupplierFormDraft initialDraft;
  final bool isEdit;
  final bool isSubmitting;
  final String submitLabel;
  final ValueChanged<SupplierFormState> onSubmit;
  final VoidCallback onCancel;
  final String? code;
  final String? accountId;

  @override
  State<SupplierForm> createState() => _SupplierFormState();
}

class _SupplierFormState extends State<SupplierForm> {
  late final TextEditingController _nameAr;
  late final TextEditingController _nameEn;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _address;
  List<String> _errorCodes = const [];

  @override
  void initState() {
    super.initState();
    final d = widget.initialDraft;
    _nameAr = TextEditingController(text: d.nameAr);
    _nameEn = TextEditingController(text: d.nameEn);
    _phone = TextEditingController(text: d.phone);
    _email = TextEditingController(text: d.email);
    _address = TextEditingController(text: d.address);
  }

  @override
  void dispose() {
    _nameAr.dispose();
    _nameEn.dispose();
    _phone.dispose();
    _email.dispose();
    _address.dispose();
    super.dispose();
  }

  SupplierFormDraft _buildDraft() {
    return SupplierFormDraft(
      nameAr: _nameAr.text,
      nameEn: _nameEn.text,
      phone: _phone.text,
      email: _email.text,
      address: _address.text,
    );
  }

  void _submit() {
    final draft = _buildDraft();
    final codes = draft.validate();
    if (codes.isNotEmpty) {
      setState(() => _errorCodes = codes);
      return;
    }
    setState(() => _errorCodes = const []);
    widget.onSubmit(draft.toFormState());
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_errorCodes.isNotEmpty) ...[
          MessageBanner(
            key: const Key('supplier-form-error'),
            variant: MessageBannerVariant.error,
            message: _errorCodes
                .map((code) => supplierErrorMessage(l10n, code))
                .join('\n'),
          ),
          const SizedBox(height: 12),
        ],
        if (widget.isEdit) ...[
          _ReadOnlyField(label: l10n.supplierFieldCode, value: widget.code),
          const SizedBox(height: 12),
          _ReadOnlyField(
            label: l10n.supplierFieldAccount,
            value: widget.accountId,
          ),
          const SizedBox(height: 12),
        ],
        AppTextField(label: l10n.supplierFieldNameAr, controller: _nameAr),
        const SizedBox(height: 12),
        AppTextField(label: l10n.supplierFieldNameEn, controller: _nameEn),
        const SizedBox(height: 12),
        AppTextField(
          label: l10n.supplierFieldPhone,
          controller: _phone,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: l10n.supplierFieldEmail,
          controller: _email,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        AppTextField(label: l10n.supplierFieldAddress, controller: _address),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: widget.isSubmitting ? null : widget.onCancel,
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('supplier-form-submit'),
              onPressed: widget.isSubmitting ? null : _submit,
              child: Text(widget.submitLabel),
            ),
          ],
        ),
      ],
    );
  }
}

class _ReadOnlyField extends StatelessWidget {
  const _ReadOnlyField({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final display = (value == null || value!.trim().isEmpty) ? '—' : value!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(label, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        InputDecorator(
          decoration: const InputDecoration(
            isDense: true,
            enabled: false,
            contentPadding: EdgeInsetsDirectional.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
          child: Text(display),
        ),
      ],
    );
  }
}
