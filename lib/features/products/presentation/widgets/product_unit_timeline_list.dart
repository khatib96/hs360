import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/unit_timeline_event.dart';

class ProductUnitTimelineList extends StatelessWidget {
  const ProductUnitTimelineList({
    required this.l10n,
    required this.isLoading,
    required this.events,
    required this.errorCode,
    super.key,
  });

  final AppLocalizations l10n;
  final bool isLoading;
  final List<UnitTimelineEvent> events;
  final String? errorCode;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (errorCode != null) {
      return Center(child: Text(l10n.productErrorUnknown));
    }

    if (events.isEmpty) {
      return Center(child: Text(l10n.productUnitTimelineEmpty));
    }

    return Column(
      children: [
        for (var i = 0; i < events.length; i++) ...[
          if (i > 0) const Divider(height: 1),
          ListTile(
            title: Text(_titleForEvent(l10n, events[i])),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_formatDateTime(events[i].occurredAt)),
                if (events[i].notes != null &&
                    events[i].notes!.trim().isNotEmpty)
                  Text(events[i].notes!),
              ],
            ),
            isThreeLine: events[i].notes != null &&
                events[i].notes!.trim().isNotEmpty,
          ),
        ],
      ],
    );
  }

  String _titleForEvent(AppLocalizations l10n, UnitTimelineEvent event) {
    return switch (event.titleKey) {
      'unit_timeline.acquisition' => l10n.productUnitTimelineAcquisition,
      'unit_timeline.purchase_invoice' => l10n.productUnitTimelinePurchaseInvoice,
      'unit_timeline.inventory_movement' =>
        l10n.productUnitTimelineInventoryMovement,
      'unit_timeline.reconciled' => l10n.productUnitTimelineReconciled,
      'unit_timeline.serial_correction' =>
        l10n.productUnitTimelineSerialCorrection,
      _ => event.eventType,
    };
  }

  String _formatDateTime(DateTime value) {
    final local = value.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final h = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $h:$min';
  }
}
