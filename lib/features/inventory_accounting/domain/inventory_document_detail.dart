import 'inventory_document_line.dart';
import 'inventory_document_movement.dart';
import 'inventory_document_summary.dart';

class InventoryDocumentDetail {
  const InventoryDocumentDetail({
    required this.summary,
    this.reasonCode,
    this.gainReasonCode,
    this.lossReasonCode,
    this.notes,
    this.importKey,
    required this.lines,
    required this.movements,
    this.journalEntryId,
    this.reversalJournalEntryId,
  });

  final InventoryDocumentSummary summary;
  final String? reasonCode;
  final String? gainReasonCode;
  final String? lossReasonCode;
  final String? notes;
  final String? importKey;
  final List<InventoryDocumentLine> lines;
  final List<InventoryDocumentMovement> movements;
  final String? journalEntryId;
  final String? reversalJournalEntryId;

  bool get isSerialized =>
      lines.any((line) => line.productUnitIds.isNotEmpty);

  bool get isCancelled =>
      summary.status == InventoryDocumentStatus.cancelled;
}
