import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../core/location/kuwait_locations.dart';
import 'app_text_field.dart';

/// Governorate + area selectors with optional custom area entry.
class KuwaitLocationFields extends StatelessWidget {
  const KuwaitLocationFields({
    required this.languageCode,
    required this.governorate,
    required this.area,
    required this.useCustomArea,
    required this.customAreaController,
    required this.onGovernorateChanged,
    required this.onAreaChanged,
    required this.onUseCustomAreaChanged,
    super.key,
  });

  final String languageCode;
  final String? governorate;
  final String? area;
  final bool useCustomArea;
  final TextEditingController customAreaController;
  final ValueChanged<String?> onGovernorateChanged;
  final ValueChanged<String?> onAreaChanged;
  final ValueChanged<bool> onUseCustomAreaChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final govValues = governorateDropdownValues(currentValue: governorate);
    final areaValues = areaDropdownValues(
      governorateCanonical: governorate,
      currentValue: useCustomArea ? null : area,
    );

    String govLabel(String value) {
      final gov = kuwaitGovernorateByCanonical(value);
      if (gov == null) return value;
      return languageCode == 'en' ? gov.nameEn : gov.nameAr;
    }

    String areaLabelFor(String value) {
      if (value == kuwaitAreaOtherCanonical) {
        return l10n.locationAreaOther;
      }
      final a = kuwaitAreaByCanonical(governorate, value);
      if (a == null) return value;
      return a.label(languageCode);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          key: const Key('location-governorate-field'),
          isExpanded: true,
          initialValue: governorate?.isEmpty == true ? null : governorate,
          decoration: InputDecoration(labelText: l10n.customerFieldGovernorate),
          items: [
            DropdownMenuItem<String>(
              value: null,
              child: Text(l10n.customerFilterAll),
            ),
            ...govValues.map(
              (v) => DropdownMenuItem(value: v, child: Text(govLabel(v))),
            ),
          ],
          onChanged: onGovernorateChanged,
        ),
        const SizedBox(height: 12),
        if (!useCustomArea)
          DropdownButtonFormField<String>(
            key: const Key('location-area-field'),
            isExpanded: true,
            initialValue: area?.isEmpty == true ? null : area,
            decoration: InputDecoration(labelText: l10n.customerFieldArea),
            items: [
              DropdownMenuItem<String>(
                value: null,
                child: Text(l10n.customerFilterAll),
              ),
              ...areaValues.map(
                (v) => DropdownMenuItem(value: v, child: Text(areaLabelFor(v))),
              ),
            ],
            onChanged: onAreaChanged,
          )
        else
          AppTextField(
            label: l10n.customerFieldArea,
            controller: customAreaController,
          ),
        if (governorate != null && governorate!.isNotEmpty) ...[
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton(
              onPressed: () => onUseCustomAreaChanged(!useCustomArea),
              child: Text(
                useCustomArea
                    ? l10n.locationUseCatalogArea
                    : l10n.locationEnterCustomArea,
              ),
            ),
          ),
        ],
      ],
    );
  }
}
