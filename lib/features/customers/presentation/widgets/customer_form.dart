import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/localization/locale_controller.dart';
import '../../../../core/location/kuwait_locations.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/kuwait_location_fields.dart';
import '../../../../shared/widgets/message_banner.dart';
import '../../../../shared/widgets/profile_form_layout.dart';
import '../../domain/customer_form_state.dart';
import '../../domain/customer_type.dart';
import '../customer_error_messages.dart';
import '../customer_form_draft.dart';
import 'google_maps_link_field.dart';

/// Shared customer form fields for dialog and edit screen.
class CustomerForm extends ConsumerStatefulWidget {
  const CustomerForm({
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

  final CustomerFormDraft initialDraft;
  final bool isEdit;
  final bool isSubmitting;
  final String submitLabel;
  final ValueChanged<CustomerFormState> onSubmit;
  final VoidCallback onCancel;
  final String? code;
  final bool hasLinkedAccount;
  final bool canEnsureAccount;
  final bool isEnsuringAccount;
  final Future<void> Function()? onEnsureAccount;

  @override
  ConsumerState<CustomerForm> createState() => _CustomerFormState();
}

class _CustomerFormState extends ConsumerState<CustomerForm> {
  late final TextEditingController _nameAr;
  late final TextEditingController _nameEn;
  late final TextEditingController _contactName;
  late final TextEditingController _contactPhone;
  late final TextEditingController _phonePrimary;
  late final TextEditingController _email;
  late final TextEditingController _taxNumber;
  late final TextEditingController _address;
  late final TextEditingController _googleMaps;
  late final TextEditingController _notes;
  late final TextEditingController _customArea;

  late CustomerType _customerType;
  late bool _isVip;
  late bool _createAccount;
  late bool _useCustomArea;
  String? _governorate;
  String? _area;
  List<String> _errorCodes = const [];
  bool _mapLinkBusy = false;
  final _googleMapsKey = GlobalKey<GoogleMapsLinkFieldState>();

  @override
  void initState() {
    super.initState();
    final d = widget.initialDraft;
    _nameAr = TextEditingController(text: d.nameAr);
    _nameEn = TextEditingController(text: d.nameEn);
    _contactName = TextEditingController(text: d.contactPersonName);
    _contactPhone = TextEditingController(text: d.contactPersonPhone);
    _phonePrimary = TextEditingController(text: d.phonePrimary);
    _email = TextEditingController(text: d.email);
    _taxNumber = TextEditingController(text: d.taxNumber);
    _address = TextEditingController(text: d.addressLine);
    _googleMaps = TextEditingController(text: d.googleMapsUrl);
    _notes = TextEditingController(text: d.notes);
    _customArea = TextEditingController(text: d.customArea);
    _customerType = d.customerType;
    _isVip = d.isVip;
    _createAccount = d.createAccount;
    _useCustomArea = d.useCustomArea;
    _governorate = d.governorate.isEmpty ? null : d.governorate;
    _area = d.area.isEmpty ? null : d.area;
  }

  @override
  void dispose() {
    _nameAr.dispose();
    _nameEn.dispose();
    _contactName.dispose();
    _contactPhone.dispose();
    _phonePrimary.dispose();
    _email.dispose();
    _taxNumber.dispose();
    _address.dispose();
    _googleMaps.dispose();
    _notes.dispose();
    _customArea.dispose();
    super.dispose();
  }

  CustomerFormDraft _buildDraft() {
    return CustomerFormDraft(
      customerType: _customerType,
      nameAr: _nameAr.text,
      nameEn: _nameEn.text,
      contactPersonName: _contactName.text,
      contactPersonPhone: _contactPhone.text,
      phonePrimary: _phonePrimary.text,
      email: _email.text,
      taxNumber: _taxNumber.text,
      addressLine: _address.text,
      governorate: _governorate ?? '',
      area: _area ?? '',
      country: kuwaitCountryCanonical,
      googleMapsUrl: _googleMaps.text,
      isVip: _isVip,
      notes: _notes.text,
      createAccount: _createAccount,
      useCustomArea: _useCustomArea,
      customArea: _customArea.text,
    );
  }

  Future<void> _submit() async {
    final draft = _buildDraft();
    final codes = draft.validate();
    if (codes.isNotEmpty) {
      setState(() => _errorCodes = codes);
      return;
    }
    setState(() => _errorCodes = const []);
    final hasMapLink = draft.googleMapsUrl.trim().isNotEmpty;
    final coordinates = await _googleMapsKey.currentState?.resolveForSubmit();
    if (!mounted || (hasMapLink && coordinates == null)) return;
    widget.onSubmit(draft.toFormState(coordinates: coordinates));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = ref.watch(localeProvider).languageCode;
    final isCompany = _customerType == CustomerType.company;

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
          ProfileMetadataRow(label: l10n.customerFieldCode, value: widget.code),
          const SizedBox(height: 8),
          ProfileMetadataRow(
            label: l10n.customerSectionAccounting,
            value: widget.hasLinkedAccount
                ? l10n.customerLinkedAccountYes
                : l10n.customerLinkedAccountNo,
          ),
          if (!widget.hasLinkedAccount &&
              widget.canEnsureAccount &&
              widget.onEnsureAccount != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton(
                key: const Key('customer-ensure-account'),
                onPressed: widget.isSubmitting || widget.isEnsuringAccount
                    ? null
                    : widget.onEnsureAccount,
                child: widget.isEnsuringAccount
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(l10n.customerEnsureAccount),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],
        ProfileFormSection(
          title: l10n.customerSectionIdentity,
          children: [
            ProfileFormLayout(
              children: [
                ProfileLabeledField(
                  label: l10n.customerTypeLabel,
                  child: DropdownButtonFormField<CustomerType>(
                    key: const Key('customer-type-field'),
                    isExpanded: true,
                    initialValue: _customerType,
                    decoration: const InputDecoration(
                      isDense: true,
                      contentPadding: EdgeInsetsDirectional.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
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
                ),
                AppTextField(
                  label: l10n.customerFieldNameAr,
                  controller: _nameAr,
                ),
                if (isCompany)
                  AppTextField(
                    label: l10n.customerFieldNameEn,
                    controller: _nameEn,
                  ),
                SwitchListTile(
                  key: const Key('customer-vip-field'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.customerFieldVip),
                  value: _isVip,
                  onChanged: (v) => setState(() => _isVip = v),
                ),
              ],
            ),
          ],
        ),
        ProfileFormSection(
          title: l10n.customerSectionContact,
          children: [
            ProfileFormLayout(
              children: [
                AppTextField(
                  label: l10n.customerFieldPhonePrimary,
                  controller: _phonePrimary,
                  keyboardType: TextInputType.phone,
                ),
                AppTextField(
                  label: l10n.customerFieldEmail,
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                ),
                if (isCompany) ...[
                  AppTextField(
                    label: l10n.customerFieldTaxNumber,
                    controller: _taxNumber,
                  ),
                  AppTextField(
                    label: l10n.customerFieldContactName,
                    controller: _contactName,
                  ),
                  AppTextField(
                    label: l10n.customerFieldContactPhone,
                    controller: _contactPhone,
                    keyboardType: TextInputType.phone,
                  ),
                ],
              ],
            ),
          ],
        ),
        ProfileFormSection(
          title: l10n.customerSectionLocation,
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
              label: l10n.customerFieldAddress,
              controller: _address,
            ),
            const SizedBox(height: 12),
            GoogleMapsLinkField(
              key: _googleMapsKey,
              controller: _googleMaps,
              onBusyChanged: (value) {
                if (mounted) setState(() => _mapLinkBusy = value);
              },
            ),
          ],
        ),
        if (!widget.isEdit)
          ProfileFormSection(
            title: l10n.customerSectionAccounting,
            children: [
              SwitchListTile(
                key: const Key('customer-create-account-field'),
                contentPadding: EdgeInsets.zero,
                title: Text(l10n.customerFieldCreateAccount),
                subtitle: Text(l10n.customerFieldCreateAccountHint),
                value: _createAccount,
                onChanged: (v) => setState(() => _createAccount = v),
              ),
            ],
          ),
        AppTextField(label: l10n.customerFieldNotes, controller: _notes),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            TextButton(
              onPressed: widget.isSubmitting || _mapLinkBusy
                  ? null
                  : widget.onCancel,
              child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
            ),
            const SizedBox(width: 8),
            FilledButton(
              key: const Key('customer-form-submit'),
              onPressed: widget.isSubmitting || _mapLinkBusy ? null : _submit,
              child: Text(widget.submitLabel),
            ),
          ],
        ),
      ],
    );
  }
}
