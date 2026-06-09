import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/localization/locale_controller.dart';
import '../../../../core/location/kuwait_locations.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/customer.dart';
import '../../domain/customer_service_location.dart';
import '../../domain/customer_type.dart';
import '../customer_locations_controller.dart';

class CustomerDetailHeader extends ConsumerWidget {
  const CustomerDetailHeader({
    required this.customer,
    required this.customerId,
    super.key,
  });

  final Customer customer;
  final String customerId;

  String _typeLabel(AppLocalizations l10n) {
    return customer.customerType == CustomerType.company
        ? l10n.customerTypeCompany
        : l10n.customerTypeIndividual;
  }

  String _profileLocationFallback(String languageCode) {
    final parts = <String>[];
    final gov = customer.governorate;
    if (gov != null && gov.isNotEmpty) {
      parts.add(governorateLabel(gov, languageCode));
    }
    final area = customer.area;
    if (area != null && area.isNotEmpty) {
      parts.add(areaLabel(gov, area, languageCode));
    }
    final address = customer.addressLine?.trim();
    if (address != null && address.isNotEmpty) {
      parts.add(address);
    }
    return parts.join(' · ');
  }

  String _locationSummary(
    List<CustomerServiceLocation> active,
    String languageCode,
  ) {
    CustomerServiceLocation? primary;
    for (final location in active) {
      if (location.isPrimary) {
        primary = location;
        break;
      }
    }
    primary ??= active.isNotEmpty ? active.first : null;

    if (primary != null) {
      final summary = primary.locationSummary();
      if (summary.isNotEmpty) {
        return '${primary.name} · $summary';
      }
      return primary.name;
    }

    final fallback = _profileLocationFallback(languageCode);
    return fallback.isEmpty ? '—' : fallback;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = ref.watch(localeProvider).languageCode;
    final theme = Theme.of(context);
    final locationsState = ref.watch(
      customerLocationsControllerProvider(customerId),
    );
    final locationText = _locationSummary(
      locationsState.activeLocations,
      languageCode,
    );

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            customer.displayName(languageCode),
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            '${customer.code} · ${_typeLabel(l10n)} · ${customer.phonePrimary}',
            style: theme.textTheme.bodyMedium,
          ),
          if (customer.email?.trim().isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(customer.email!.trim(), style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StatusChip(
                label: customer.isActive
                    ? l10n.customerStatusActive
                    : l10n.customerStatusInactive,
                color: customer.isActive
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              if (customer.isVip)
                _StatusChip(label: l10n.customerVip, color: AppColors.gold),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.customerPrimaryLocationSummary,
            style: theme.textTheme.labelMedium,
          ),
          const SizedBox(height: 4),
          Text(locationText, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 8),
          Text(
            customer.hasLinkedAccount
                ? '${l10n.customerAccountLinked} (${customer.accountId})'
                : l10n.customerAccountNotLinked,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 8,
        vertical: 4,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
