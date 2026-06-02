import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/localization/locale_controller.dart' show localeProvider;
import '../../../../core/location/kuwait_locations.dart';
import '../../../../shared/widgets/app_text_field.dart';
import '../../../../shared/widgets/kuwait_location_fields.dart';
import '../../domain/customer_service_location.dart';
import '../../domain/customer_service_location_form_state.dart';
import '../../domain/service_location_type.dart';
import '../customer_error_messages.dart';
import '../service_location_type_labels.dart';

class CustomerServiceLocationFormDialog extends ConsumerStatefulWidget {
  const CustomerServiceLocationFormDialog({
    this.initial,
    super.key,
  });

  final CustomerServiceLocation? initial;

  @override
  ConsumerState<CustomerServiceLocationFormDialog> createState() =>
      _CustomerServiceLocationFormDialogState();
}

class _CustomerServiceLocationFormDialogState
    extends ConsumerState<CustomerServiceLocationFormDialog> {
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _googleMaps;
  late final TextEditingController _contactName;
  late final TextEditingController _contactPhone;
  late final TextEditingController _customArea;
  late final TextEditingController _notes;

  late ServiceLocationType _type;
  late bool _isPrimary;
  late bool _useCustomArea;
  String? _governorate;
  String? _area;

  @override
  void initState() {
    super.initState();
    final initial = widget.initial;
    final form = initial != null
        ? CustomerServiceLocationFormState.fromLocation(initial)
        : CustomerServiceLocationFormState(name: '');
    _name = TextEditingController(text: form.name);
    _address = TextEditingController(text: form.addressLine ?? '');
    _googleMaps = TextEditingController(text: form.googleMapsUrl ?? '');
    _contactName = TextEditingController(text: form.contactPersonName ?? '');
    _contactPhone = TextEditingController(text: form.contactPersonPhone ?? '');
    _notes = TextEditingController(text: form.notes ?? '');
    _customArea = TextEditingController();
    _type = form.locationType;
    _isPrimary = form.isPrimary;
    _governorate = form.governorate;
    _area = form.area;
    _useCustomArea = form.area != null &&
        kuwaitAreaByCanonical(form.governorate, form.area) == null &&
        form.area!.isNotEmpty;
    if (_useCustomArea) {
      _customArea.text = form.area!;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _address.dispose();
    _googleMaps.dispose();
    _contactName.dispose();
    _contactPhone.dispose();
    _customArea.dispose();
    _notes.dispose();
    super.dispose();
  }

  CustomerServiceLocationFormState _buildFormState() {
    final area = _useCustomArea ? _customArea.text.trim() : _area?.trim();
    return CustomerServiceLocationFormState(
      name: _name.text,
      locationType: _type,
      isPrimary: _isPrimary,
      governorate: _governorate?.trim(),
      area: area?.isEmpty == true ? null : area,
      addressLine: _address.text.trim().isEmpty ? null : _address.text.trim(),
      googleMapsUrl:
          _googleMaps.text.trim().isEmpty ? null : _googleMaps.text.trim(),
      contactPersonName:
          _contactName.text.trim().isEmpty ? null : _contactName.text.trim(),
      contactPersonPhone:
          _contactPhone.text.trim().isEmpty ? null : _contactPhone.text.trim(),
      notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider).languageCode;
    final isEdit = widget.initial != null;

    return AlertDialog(
      title: Text(isEdit ? l10n.serviceLocationEdit : l10n.serviceLocationAdd),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppTextField(
                controller: _name,
                label: l10n.serviceLocationFieldName,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<ServiceLocationType>(
                isExpanded: true,
                initialValue: _type,
                decoration:
                    InputDecoration(labelText: l10n.serviceLocationFieldType),
                items: ServiceLocationType.values
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(serviceLocationTypeLabel(l10n, t)),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _type = v);
                },
              ),
              const SizedBox(height: 12),
              KuwaitLocationFields(
                languageCode: locale,
                governorate: _governorate,
                area: _area,
                useCustomArea: _useCustomArea,
                customAreaController: _customArea,
                onGovernorateChanged: (v) => setState(() {
                  _governorate = v;
                  _area = null;
                }),
                onAreaChanged: (v) => setState(() => _area = v),
                onUseCustomAreaChanged: (v) => setState(() {
                  _useCustomArea = v;
                  if (!v) _customArea.clear();
                }),
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _address,
                label: l10n.customerFieldAddress,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _googleMaps,
                label: l10n.customerFieldGoogleMapsUrl,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _contactName,
                label: l10n.serviceLocationFieldContactName,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _contactPhone,
                label: l10n.serviceLocationFieldContactPhone,
              ),
              const SizedBox(height: 12),
              AppTextField(
                controller: _notes,
                label: l10n.customerFieldNotes,
              ),
              if (!isEdit) ...[
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isPrimary,
                  onChanged: (v) => setState(() => _isPrimary = v ?? false),
                  title: Text(l10n.serviceLocationSetPrimary),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(MaterialLocalizations.of(context).cancelButtonLabel),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(_buildFormState());
          },
          child: Text(MaterialLocalizations.of(context).saveButtonLabel),
        ),
      ],
    );
  }
}

Future<CustomerServiceLocationFormState?> showCustomerServiceLocationFormDialog(
  BuildContext context, {
  CustomerServiceLocation? initial,
}) {
  return showDialog<CustomerServiceLocationFormState>(
    context: context,
    builder: (context) => CustomerServiceLocationFormDialog(initial: initial),
  );
}

void showServiceLocationErrorSnackBar(BuildContext context, String code) {
  final l10n = AppLocalizations.of(context)!;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(customerErrorMessage(l10n, code))),
  );
}
