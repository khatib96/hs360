import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/localization/locale_controller.dart';
import '../../../../core/location/kuwait_locations.dart';
import '../../../../shared/widgets/profile_form_layout.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../domain/supplier.dart';
import '../../domain/supplier_permissions.dart';
import 'supplier_form_dialog.dart';

class SupplierProfileTab extends ConsumerWidget {
  const SupplierProfileTab({required this.supplier, super.key});

  final Supplier supplier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = ref.watch(localeProvider).languageCode;
    final session = ref.watch(authControllerProvider).valueOrNull;
    final canEdit = session != null && canEditSupplier(session);

    String locationArea(String? governorate, String? area) {
      if (area == null || area.isEmpty) return '—';
      return areaLabel(governorate, area, languageCode);
    }

    return ListView(
      padding: const EdgeInsetsDirectional.all(16),
      children: [
        if (canEdit)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton.icon(
              key: const Key('supplier-profile-edit'),
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => SupplierFormDialog(initial: supplier),
              ),
              icon: const Icon(Icons.edit_outlined),
              label: Text(l10n.supplierActionEdit),
            ),
          ),
        if (canEdit) const SizedBox(height: 16),
        ProfileFormSection(
          title: l10n.supplierSectionIdentity,
          children: [
            ProfileMetadataRow(
              label: l10n.supplierFieldCode,
              value: supplier.code,
            ),
            ProfileMetadataRow(
              label: l10n.supplierFieldNameAr,
              value: supplier.nameAr,
            ),
            ProfileMetadataRow(
              label: l10n.supplierFieldNameEn,
              value: supplier.nameEn ?? '—',
            ),
            ProfileMetadataRow(
              label: l10n.supplierColumnStatus,
              value: supplier.isActive
                  ? l10n.supplierStatusActive
                  : l10n.supplierStatusInactive,
            ),
          ],
        ),
        ProfileFormSection(
          title: l10n.supplierSectionContact,
          children: [
            ProfileMetadataRow(
              label: l10n.supplierFieldPhone,
              value: supplier.phone ?? '—',
            ),
            ProfileMetadataRow(
              label: l10n.supplierFieldEmail,
              value: supplier.email ?? '—',
            ),
            ProfileMetadataRow(
              label: l10n.supplierFieldTaxNumber,
              value: supplier.taxNumber ?? '—',
            ),
          ],
        ),
        ProfileFormSection(
          title: l10n.supplierSectionLocation,
          children: [
            ProfileMetadataRow(
              label: l10n.customerFieldGovernorate,
              value: supplier.governorate == null
                  ? '—'
                  : governorateLabel(supplier.governorate!, languageCode),
            ),
            ProfileMetadataRow(
              label: l10n.customerFieldArea,
              value: locationArea(supplier.governorate, supplier.area),
            ),
            ProfileMetadataRow(
              label: l10n.supplierFieldAddress,
              value: supplier.addressLine ?? '—',
            ),
          ],
        ),
        if (supplier.notes?.trim().isNotEmpty == true)
          ProfileFormSection(
            title: l10n.customerFieldNotes,
            children: [
              ProfileMetadataRow(
                label: l10n.customerFieldNotes,
                value: supplier.notes!,
              ),
            ],
          ),
      ],
    );
  }
}
