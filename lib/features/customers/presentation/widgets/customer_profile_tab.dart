import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/localization/locale_controller.dart';
import '../../../../core/location/kuwait_locations.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../shared/widgets/profile_form_layout.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../domain/customer.dart';
import '../../domain/customer_permissions.dart';
import '../../domain/customer_type.dart';

class CustomerProfileTab extends ConsumerWidget {
  const CustomerProfileTab({required this.customer, super.key});

  final Customer customer;

  String _typeLabel(AppLocalizations l10n) {
    return customer.customerType == CustomerType.company
        ? l10n.customerTypeCompany
        : l10n.customerTypeIndividual;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = ref.watch(localeProvider).languageCode;
    final session = ref.watch(authControllerProvider).valueOrNull;
    final canEdit = session != null && canEditCustomer(session);
    final isCompany = customer.customerType == CustomerType.company;

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
              key: const Key('customer-profile-edit'),
              onPressed: () => context.go(AppRoutes.customerEditPath(customer.id)),
              icon: const Icon(Icons.edit_outlined),
              label: Text(l10n.customerActionEdit),
            ),
          ),
        if (canEdit) const SizedBox(height: 16),
        ProfileFormSection(
          title: l10n.customerSectionIdentity,
          children: [
            ProfileMetadataRow(label: l10n.customerFieldCode, value: customer.code),
            ProfileMetadataRow(
              label: l10n.customerTypeLabel,
              value: _typeLabel(l10n),
            ),
            ProfileMetadataRow(label: l10n.customerFieldNameAr, value: customer.nameAr),
            ProfileMetadataRow(label: l10n.customerFieldNameEn, value: customer.nameEn),
            ProfileMetadataRow(
              label: l10n.customerFieldVip,
              value: customer.isVip ? l10n.customerVip : l10n.customerNonVip,
            ),
            ProfileMetadataRow(
              label: l10n.customerColumnStatus,
              value: customer.isActive
                  ? l10n.customerStatusActive
                  : l10n.customerStatusInactive,
            ),
          ],
        ),
        ProfileFormSection(
          title: l10n.customerSectionContact,
          children: [
            ProfileMetadataRow(
              label: l10n.customerFieldPhonePrimary,
              value: customer.phonePrimary,
            ),
            ProfileMetadataRow(label: l10n.customerFieldEmail, value: customer.email),
            if (isCompany) ...[
              ProfileMetadataRow(
                label: l10n.customerFieldContactName,
                value: customer.contactPersonName,
              ),
              ProfileMetadataRow(
                label: l10n.customerFieldContactPhone,
                value: customer.contactPersonPhone,
              ),
              ProfileMetadataRow(
                label: l10n.customerFieldTaxNumber,
                value: customer.taxNumber,
              ),
            ],
          ],
        ),
        ProfileFormSection(
          title: l10n.customerSectionLocation,
          children: [
            ProfileMetadataRow(
              label: l10n.customerFieldGovernorate,
              value: customer.governorate == null || customer.governorate!.isEmpty
                  ? null
                  : governorateLabel(customer.governorate!, languageCode),
            ),
            ProfileMetadataRow(
              label: l10n.customerFieldArea,
              value: locationArea(customer.governorate, customer.area),
            ),
            ProfileMetadataRow(
              label: l10n.customerFieldAddress,
              value: customer.addressLine,
            ),
            ProfileMetadataRow(
              label: l10n.customerFieldGoogleMapsUrl,
              value: customer.googleMapsUrl,
            ),
          ],
        ),
        ProfileFormSection(
          title: l10n.customerSectionAccounting,
          children: [
            ProfileMetadataRow(
              label: l10n.customerSectionAccounting,
              value: customer.hasLinkedAccount
                  ? l10n.customerLinkedAccountYes
                  : l10n.customerLinkedAccountNo,
            ),
            if (customer.hasLinkedAccount)
              ProfileMetadataRow(
                label: l10n.customerAccountIdLabel,
                value: customer.accountId,
              ),
          ],
        ),
        if (customer.notes?.trim().isNotEmpty == true)
          ProfileFormSection(
            title: l10n.customerFieldNotes,
            children: [
              ProfileMetadataRow(label: l10n.customerFieldNotes, value: customer.notes),
            ],
          ),
      ],
    );
  }
}
