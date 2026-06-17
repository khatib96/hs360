import 'inventory_document_line.dart';
import 'inventory_document_summary.dart';

class InventoryDocumentDetail {
  const InventoryDocumentDetail({
    required this.summary,
    this.reasonCode,
    this.notes,
    required this.lines,
    this.journalEntryId,
  });

  final InventoryDocumentSummary summary;
  final String? reasonCode;
  final String? notes;
  final List<InventoryDocumentLine> lines;
  final String? journalEntryId;
}
