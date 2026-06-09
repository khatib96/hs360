import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/product_unit.dart';
import '../product_unit_display_helpers.dart';

class ProductUnitDetailHeader extends StatelessWidget {
  const ProductUnitDetailHeader({
    required this.unit,
    required this.l10n,
    required this.languageCode,
    super.key,
  });

  final ProductUnit unit;
  final AppLocalizations l10n;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 900;
    final location = _locationLabel();

    final chips = [
      Chip(label: Text(unitStatusLabel(l10n, unit.status))),
      Chip(label: Text(unitHealthLabel(l10n, unit.healthStatus))),
    ];

    final fields = [
      _Field(l10n.productUnitFieldSerial, unit.serialNumber),
      _Field(
        l10n.productUnitFieldBarcode,
        unit.barcode ?? l10n.productUnitDetailNoBarcode,
      ),
      _Field(l10n.productUnitDetailLocation, location),
      _Field(
        l10n.productUnitDetailMaintenanceCount,
        unit.totalMaintenanceCount.toString(),
      ),
    ];

    if (isWide) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(unit.serialNumber, style: theme.textTheme.headlineSmall),
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 8, children: chips),
              const SizedBox(height: 16),
              Wrap(
                spacing: 24,
                runSpacing: 12,
                children: fields
                    .map((field) => SizedBox(width: 220, child: field))
                    .toList(),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(unit.serialNumber, style: theme.textTheme.titleLarge),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: chips),
            const SizedBox(height: 16),
            ...fields.map(
              (field) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: field,
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _locationLabel() {
    if (unit.currentServiceLocationId != null) {
      final name = unit.serviceLocationName?.trim();
      if (name != null && name.isNotEmpty) return name;
    }

    if (unit.currentCustomerId != null) {
      final customerName = languageCode.toLowerCase() == 'ar'
          ? (unit.customerNameAr ?? unit.customerNameEn)
          : (unit.customerNameEn ?? unit.customerNameAr);
      if (customerName != null && customerName.trim().isNotEmpty) {
        return customerName;
      }
    }

    if (unit.currentWarehouseId != null) {
      final warehouseName = languageCode.toLowerCase() == 'ar'
          ? (unit.warehouseNameAr ?? unit.warehouseNameEn)
          : (unit.warehouseNameEn ?? unit.warehouseNameAr);
      if (warehouseName != null && warehouseName.trim().isNotEmpty) {
        return warehouseName;
      }
    }

    return l10n.productUnitDetailLocationUnknown;
  }
}

class _Field extends StatelessWidget {
  const _Field(this.label, this.value);

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(value),
      ],
    );
  }
}
