import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/localization/locale_controller.dart';
import '../../../../core/location/kuwait_locations.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../shared/widgets/app_status_badge.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../calendar/domain/calendar_permissions.dart';
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
              AppStatusBadge(
                label: customer.isActive
                    ? l10n.customerStatusActive
                    : l10n.customerStatusInactive,
                tone: customer.isActive
                    ? AppStatusTone.success
                    : AppStatusTone.neutral,
              ),
              if (customer.isVip)
                AppStatusBadge(
                  label: l10n.customerVip,
                  tone: AppStatusTone.brand,
                ),
            ],
          ),
          const SizedBox(height: 8),
          _CustomerOpenInCalendarButton(customerId: customerId),
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

class _CustomerOpenInCalendarButton extends ConsumerWidget {
  const _CustomerOpenInCalendarButton({required this.customerId});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(authControllerProvider).valueOrNull;
    if (session == null || !canAccessCalendar(session)) {
      return const SizedBox.shrink();
    }
    final l10n = AppLocalizations.of(context)!;
    return TextButton.icon(
      key: const Key('customer-view-in-calendar'),
      onPressed: () =>
          context.push(AppRoutes.calendarPath(customerId: customerId)),
      icon: const Icon(Icons.calendar_month_outlined, size: 18),
      label: Text(l10n.calendarOpenInCalendar),
    );
  }
}
