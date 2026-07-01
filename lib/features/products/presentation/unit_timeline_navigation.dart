import 'package:go_router/go_router.dart';

import '../../../core/routing/app_routes.dart';
import '../../invoices/domain/invoice_type.dart';
import '../domain/unit_timeline_event.dart';

/// Navigation targets for unit timeline events (read-only integration).
String? routeForUnitTimelineEvent(UnitTimelineEvent event) {
  final sourceId = event.sourceId?.trim();
  if (sourceId == null || sourceId.isEmpty) return null;

  return switch (event.titleKey) {
    'unit_timeline.purchase_invoice' => _invoicePath(sourceId, event.metadataJson),
    _ when event.sourceTable == 'invoices' =>
      _invoicePath(sourceId, event.metadataJson),
    _ => null,
  };
}

String? _invoicePath(String invoiceId, Map<String, dynamic>? metadata) {
  final typeRaw = metadata?['invoice_type'] as String?;
  if (typeRaw == null || typeRaw.trim().isEmpty) return null;
  try {
    return AppRoutes.invoiceDetailPath(
      invoiceId,
      type: InvoiceType.fromDb(typeRaw),
    );
  } on FormatException {
    return null;
  }
}

void goToUnitTimelineEvent(GoRouter router, UnitTimelineEvent event) {
  final path = routeForUnitTimelineEvent(event);
  if (path != null) router.go(path);
}
