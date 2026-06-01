import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/localization/locale_controller.dart';
import '../../../../core/location/kuwait_locations.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/kuwait_location_fields.dart';
import '../../../../shared/widgets/message_banner.dart';
import '../../../../shared/widgets/profile_form_layout.dart';
import '../../domain/supplier_form_state.dart';
import '../supplier_error_messages.dart';
import '../supplier_form_draft.dart';

class SupplierForm extends ConsumerStatefulWidget {
  const SupplierForm({
    required this.initialDraft,
    required this.isEdit,
    required this.isSubmitting,
    required this.submitLabel,
    required this.onSubmit,
    required this.onCancel,
    this.code,
    this.hasLinkedAccount = false,
    this.canEnsureAccount = false,
    this.isEnsuringAccount = false,
    this.onEnsureAccount,
    super.key,
  });

  final SupplierFormDraft initialDraft;
  final bool isEdit;
  final bool isSubmitting;
  final String submitLabel;
  final ValueChanged<SupplierFormState> onSubmit;
  final VoidCallback onCancel;
  final String? code;
  final bool hasLinkedAccount;
  final bool canEnsureAccount;
  final bool isEnsuringAccount;
  final Future<void> Function()? onEnsureAccount;

  @override
  ConsumerState<SupplierForm> createState() => _SupplierFormState();
}

class _SupplierFormState extends ConsumerState<SupplierForm> {
  late final TextEditingController _nameAr;
  late final TextEditingController _nameEn;
  late final TextEditingController _phone;
  late final TextEditingController _email;
  late final TextEditingController _taxNumber;
  late final TextEditingController _address;
  late final TextEditingController _googleMaps;
  late final TextEditingController _notes;
  late final TextEditingController _customArea;

  late bool _createAccount;
  late bool _useCustomArea;
  String? _governorate;
  String? _area;
  List<String> _errorCodes = const [];

  @override
  void initState() {
    super.initState();
    final d = widget.initialDraft;
    _nameAr = TextEditingController(text: d.nameAr);
    _nameEn = TextEditingController(text: d.nameEn);
    _phone = TextEditingController(text: d.phone);
    _email = TextEditingController(text: d.email);
    _taxNumber = TextEditingController(text: d.taxNumber);
    _address = TextEditingController(text: d.addressLine);
    _googleMaps = TextEditingController(text: d.googleMapsUrl);
    _notes = TextEditingController(text: d.notes);
    _customArea = TextEditingController(text: d.customArea);
    _createAccount = d.createAccount;
    _useCustomArea = d.useCustomArea;
    _governorate = d.governorate.isEmpty ? null : d.governorate;
    _area = d.area.isEmpty ? null : d.area;
  }

  @override
  void dispose() {
    _nameAr.dispose();
    _nameEn.dispose();
    _phone.dispose();
    _email.dispose();
    _taxNumber.dispose();
    _address.dispose();
    _googleMaps.dispose();
    _notes.dispose();
    _customArea.dispose();
    super.dispose();
  }

  SupplierFormDraft _buildDraft() {
    return SupplierFormDraft(
      nameAr: _nameAr.text,
      nameEn: _nameEn.text,
      phone: _phone.text,
      email: _email.text,
      taxNumber: _taxNumber.text,
      addressLine: _address.text,
      governorate: _governorate ?? '',
      area: _area ?? '',
      country: kuwaitCountryCanonical,
      googleMapsUrl: _googleMaps.text,
      notes: _notes.text,
      createAccount: _createAccount,
      useCustomArea: _useCustomArea,
      customArea: _customArea.text,
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
    final languageCode = ref.watch(localeProvider).languageCode;

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
          ProfileMetadataRow(label: l10n.supplierFieldCode, value: widget.code),
          const SizedBox(height: 8),
          ProfileMetadataRow(
            label: l10n.supplierSectionAccounting,
            value: widget.hasLinkedAccount
                ? l10n.supplierLinkedAccountYes
                : l10n.supplierLinkedAccountNo,
          ),
          if (!widget.hasLinkedAccount &&
              widget.canEnsureAccount &&
              widget.onEnsureAccount != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                key: const Key('supplier-ensure-account'),
                onPressed: widget.isSubmitting || widget.isEnsuringAccount
                    ? null
                    : widget.onEnsureAccount,
                child: widget.isEnsuringAccount
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.supplierEnsureAccount),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
        ProfileFormSection(
          title: l10n.supplierSectionIdentity,
          children: [
            ProfileFormLayout(
              children: [
                AppTextField(
                  label: l10n.supplierFieldNameAr,
                  controller: _nameAr,
                ),
                AppTextField(
                  label: l10n.supplierFieldNameEn,
                  controller: _nameEn,
                ),
              ],
            ),
          ],
        ),
        ProfileFormSection(
          title: l10n.supplierSectionContact,
          children: [
            ProfileFormLayout(
              children: [
                AppTextField(
                  label: l10n.supplierFieldPhone,
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                ),
                AppTextField(
                  label: l10n.supplierFieldEmail,
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                ),
                AppTextField(
                  label: l10n.supplierFieldTaxNumber,
                  controller: _taxNumber,
                ),
              ],
            ),
          ],
        ),
        ProfileFormSection(
          title: l10n.supplierSectionLocation,
          children: [
            KuwaitLocationFields(
              languageCode: languageCode,
              governorate: _governorate,
              area: _area,
              useCustomArea: _useCustomArea,
              customAreaController: _customArea,
              onGovernorateChanged: (value) {
                setState(() {
                  _governorate = value;
                  _area = null;
                  _useCustomArea = false;
                });
              },
              onAreaChanged: (value) {
                setState(() {
                  if (value == kuwaitAreaOtherCanonical) {
                    _useCustomArea = true;
                    _area = null;
                  } else {
                    _area = value;
                    _useCustomArea = false;
                  }
                });
              },
              onUseCustomAreaChanged: (useCustom) {
                setState(() {
                  _useCustomArea = useCustom;
                  if (!useCustom) _customArea.clear();
                });
              },
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: l10n.supplierFieldAddress,
              controller: _address,
            ),
            const SizedBox(height: 12),
            AppTextField(
              label: l10n.supplierFieldGoogleMapsUrl,
              controller: _googleMaps,
              keyboardType: TextInputType.url,
            ),
          ],
        ),
        if (!widget.isEdit)
          ProfileFormSection(
            title: l10n.supplierSectionAccounting,
            children: [
              SwitchListTile(
                key: const Key('supplier-create-account-field'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.supplierFieldCreateAccount),
                subtitle: Text(l10n.supplierFieldCreateAccountHint),
                value: _createAccount,
                onChanged: (v) => setState(() => _createAccount = v),
              ),
            ],
          ),
        AppTextField(label: l10n.supplierFieldNotes, controller: _notes),
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
