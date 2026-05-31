import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/message_banner.dart';
import '../../domain/customer_form_state.dart';
import '../../domain/customer_type.dart';
import '../customer_error_messages.dart';
import '../customer_form_draft.dart';

/// Single source of truth for all customer form fields, shared by the hub
/// dialog and the edit screen. Owns its controllers and validation display;
/// builds a [CustomerFormDraft], validates it, and only calls [onSubmit] with
/// a built [CustomerFormState] when the draft is valid.
class CustomerForm extends StatefulWidget {
  const CustomerForm({
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

  final CustomerFormDraft initialDraft;
  final bool isEdit;
  final bool isSubmitting;
  final String submitLabel;
  final ValueChanged<CustomerFormState> onSubmit;
  final VoidCallback onCancel;
  final String? code;
  final String? accountId;

  @override
  State<CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends State<CustomerForm> {
  late final TextEditingController _nameAr;
  late final TextEditingController _nameEn;
  late final TextEditingController _contactName;
  late final TextEditingController _contactTitle;
  late final TextEditingController _contactPhone;
  late final TextEditingController _phonePrimary;
  late final TextEditingController _phoneSecondary;
  late final TextEditingController _whatsapp;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _area;
  late final TextEditingController _city;
  late final TextEditingController _country;
  late final TextEditingController _gpsLat;
  late final TextEditingController _gpsLng;
  late final TextEditingController _paymentTerms;
  late final TextEditingController _creditLimit;
  late final TextEditingController _notes;

  late CustomerType _customerType;
  late bool _isVip;
  List<String> _errorCodes = const [];

  @override
  void initState() {
    super.initState();
    final d = widget.initialDraft;
    _nameAr = TextEditingController(text: d.nameAr);
    _nameEn = TextEditingController(text: d.nameEn);
    _contactName = TextEditingController(text: d.contactPersonName);
    _contactTitle = TextEditingController(text: d.contactPersonTitle);
    _contactPhone = TextEditingController(text: d.contactPersonPhone);
    _phonePrimary = TextEditingController(text: d.phonePrimary);
    _phoneSecondary = TextEditingController(text: d.phoneSecondary);
    _whatsapp = TextEditingController(text: d.whatsapp);
    _email = TextEditingController(text: d.email);
    _address = TextEditingController(text: d.addressLine);
    _area = TextEditingController(text: d.area);
    _city = TextEditingController(text: d.city);
    _country = TextEditingController(text: d.country);
    _gpsLat = TextEditingController(text: d.gpsLat);
    _gpsLng = TextEditingController(text: d.gpsLng);
    _paymentTerms = TextEditingController(text: d.paymentTermsDays);
    _creditLimit = TextEditingController(text: d.creditLimit);
    _notes = TextEditingController(text: d.notes);
    _customerType = d.customerType;
    _isVip = d.isVip;
  }

  @override
  void dispose() {
    for (final c in [
      _nameAr,
      _nameEn,
      _contactName,
      _contactTitle,
      _contactPhone,
      _phonePrimary,
      _phoneSecondary,
      _whatsapp,
      _email,
      _address,
      _area,
      _city,
      _country,
      _gpsLat,
      _gpsLng,
      _paymentTerms,
      _creditLimit,
      _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  CustomerFormDraft _buildDraft() {
    return CustomerFormDraft(
      customerType: _customerType,
      nameAr: _nameAr.text,
      nameEn: _nameEn.text,
      contactPersonName: _contactName.text,
      contactPersonTitle: _contactTitle.text,
      contactPersonPhone: _contactPhone.text,
      phonePrimary: _phonePrimary.text,
      phoneSecondary: _phoneSecondary.text,
      whatsapp: _whatsapp.text,
      email: _email.text,
      addressLine: _address.text,
      area: _area.text,
      city: _city.text,
      country: _country.text,
      gpsLat: _gpsLat.text,
      gpsLng: _gpsLng.text,
      paymentTermsDays: _paymentTerms.text,
      creditLimit: _creditLimit.text,
      isVip: _isVip,
      notes: _notes.text,
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
            key: const Key('customer-form-error'),
            variant: MessageBannerVariant.error,
            message: _errorCodes
                .map((code) => customerErrorMessage(l10n, code))
                .join('\n'),
          ),
          const SizedBox(height: 12),
        ],
        if (widget.isEdit) ...[
          _ReadOnlyField(label: l10n.customerFieldCode, value: widget.code),
          const SizedBox(height: 12),
          _ReadOnlyField(
            label: l10n.customerFieldAccount,
            value: widget.accountId,
          ),
          const SizedBox(height: 12),
        ],
        DropdownButtonFormField<CustomerType>(
          key: const Key('customer-type-field'),
          isExpanded: true,
          initialValue: _customerType,
          decoration: InputDecoration(labelText: l10n.customerTypeLabel),
          items: [
            DropdownMenuItem(
              value: CustomerType.individual,
              child: Text(l10n.customerTypeIndividual),
            ),
            DropdownMenuItem(
              value: CustomerType.company,
              child: Text(l10n.customerTypeCompany),
            ),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _customerType = value);
          },
        ),
        const SizedBox(height: 12),
        AppTextField(label: l10n.customerFieldNameAr, controller: _nameAr),
        const SizedBox(height: 12),
        AppTextField(label: l10n.customerFieldNameEn, controller: _nameEn),
        const SizedBox(height: 12),
        AppTextField(
          label: l10n.customerFieldPhonePrimary,
          controller: _phonePrimary,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: l10n.customerFieldPhoneSecondary,
          controller: _phoneSecondary,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: l10n.customerFieldWhatsapp,
          controller: _whatsapp,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: l10n.customerFieldEmail,
          controller: _email,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: l10n.customerFieldContactName,
          controller: _contactName,
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: l10n.customerFieldContactTitle,
          controller: _contactTitle,
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: l10n.customerFieldContactPhone,
          controller: _contactPhone,
          keyboardType: TextInputType.phone,
        ),
        const SizedBox(height: 12),
        AppTextField(label: l10n.customerFieldAddress, controller: _address),
        const SizedBox(height: 12),
        AppTextField(label: l10n.customerFieldArea, controller: _area),
        const SizedBox(height: 12),
        AppTextField(label: l10n.customerFieldCity, controller: _city),
        const SizedBox(height: 12),
        AppTextField(label: l10n.customerFieldCountry, controller: _country),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: AppTextField(
                label: l10n.customerFieldGpsLat,
                controller: _gpsLat,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: AppTextField(
                label: l10n.customerFieldGpsLng,
                controller: _gpsLng,
                keyboardType: const TextInputType.numberWithOptions(
                  signed: true,
                  decimal: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: l10n.customerFieldPaymentTerms,
          controller: _paymentTerms,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        AppTextField(
          label: l10n.customerFieldCreditLimit,
          controller: _creditLimit,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        const SizedBox(height: 4),
        SwitchListTile(
          key: const Key('customer-vip-field'),
          contentPadding: EdgeInsets.zero,
          title: Text(l10n.customerFieldVip),
          value: _isVip,
          onChanged: (v) => setState(() => _isVip = v),
        ),
        AppTextField(label: l10n.customerFieldNotes, controller: _notes),
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
              key: const Key('customer-form-submit'),
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
