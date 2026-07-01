import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/localization/locale_controller.dart';
import '../../../../core/location/kuwait_locations.dart';
import '../../domain/supplier.dart';

class SupplierDetailHeader extends ConsumerWidget {
  const SupplierDetailHeader({required this.supplier, super.key});

  final Supplier supplier;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final languageCode = ref.watch(localeProvider).languageCode;
    final theme = Theme.of(context);

    final locationParts = <String>[];
    final gov = supplier.governorate;
    if (gov != null && gov.isNotEmpty) {
      locationParts.add(governorateLabel(gov, languageCode));
    }
    final area = supplier.area;
    if (area != null && area.isNotEmpty) {
      locationParts.add(areaLabel(gov, area, languageCode));
    }
    final locationText = locationParts.isEmpty ? '—' : locationParts.join(' · ');

    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            supplier.displayName(languageCode),
            key: const Key('supplier-detail-name'),
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 4),
          Text(
            '${supplier.code} · ${supplier.isActive ? l10n.supplierStatusActive : l10n.supplierStatusInactive}',
            style: theme.textTheme.bodyMedium,
          ),
          if (supplier.phone?.isNotEmpty == true) ...[
            const SizedBox(height: 4),
            Text(supplier.phone!, style: theme.textTheme.bodyMedium),
          ],
          const SizedBox(height: 4),
          Text(locationText, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}
