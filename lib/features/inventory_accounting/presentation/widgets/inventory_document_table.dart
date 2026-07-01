import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/routing/app_routes.dart';
import '../../domain/inventory_document_summary.dart';
import '../inventory_document_display_helpers.dart';
import 'inventory_document_shared_widgets.dart';

class InventoryDocumentTable extends StatelessWidget {
  const InventoryDocumentTable({
    required this.documents,
    required this.languageCode,
    super.key,
  });

  final List<InventoryDocumentSummary> documents;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: DataTable(
        columns: [
          DataColumn(label: Text(l10n.inventoryDocumentNumber)),
          DataColumn(label: Text(l10n.inventoryDocumentKind)),
          DataColumn(label: Text(l10n.inventoryDocumentWarehouse)),
          DataColumn(label: Text(l10n.inventoryDocumentDate)),
          DataColumn(label: Text(l10n.financeColumnStatus)),
        ],
        rows: [
          for (final doc in documents)
            DataRow(
              onSelectChanged: (_) =>
                  context.go(AppRoutes.inventoryDocumentDetailPath(doc.id)),
              cells: [
                DataCell(Text(doc.documentNumber ?? '—')),
                DataCell(Text(inventoryDocumentKindLabel(l10n, doc.kind))),
                DataCell(
                  Text(
                    localizedWarehouseName(
                      languageCode: languageCode,
                      nameAr: doc.warehouseNameAr,
                      nameEn: doc.warehouseNameEn,
                    ),
                  ),
                ),
                DataCell(Text(_formatDate(context, doc.date))),
                DataCell(
                  inventoryDocumentStatusChip(
                    context,
                    inventoryDocumentStatusLabel(l10n, doc.status),
                    cancelled: doc.status == InventoryDocumentStatus.cancelled,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class InventoryDocumentCardList extends StatelessWidget {
  const InventoryDocumentCardList({
    required this.documents,
    required this.languageCode,
    super.key,
  });

  final List<InventoryDocumentSummary> documents;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return ListView.separated(
      itemCount: documents.length,
      separatorBuilder: (_, _) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final doc = documents[index];
        return Card(
          child: InkWell(
            onTap: () =>
                context.go(AppRoutes.inventoryDocumentDetailPath(doc.id)),
            child: Padding(
              padding: const EdgeInsetsDirectional.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          doc.documentNumber ?? '—',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      inventoryDocumentStatusChip(
                        context,
                        inventoryDocumentStatusLabel(l10n, doc.status),
                        cancelled:
                            doc.status == InventoryDocumentStatus.cancelled,
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(inventoryDocumentKindLabel(l10n, doc.kind)),
                  const SizedBox(height: 4),
                  Text(
                    localizedWarehouseName(
                      languageCode: languageCode,
                      nameAr: doc.warehouseNameAr,
                      nameEn: doc.warehouseNameEn,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(_formatDate(context, doc.date)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

String _formatDate(BuildContext context, DateTime date) {
  return MaterialLocalizations.of(context).formatMediumDate(date);
}
