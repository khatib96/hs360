import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/finance_shared/domain/pagination_cursor.dart';
import 'package:hs360/features/inventory_accounting/data/inventory_document_repository.dart';
import 'package:hs360/features/inventory_accounting/domain/inventory_adjustment_reason.dart';
import 'package:hs360/features/inventory_accounting/domain/inventory_document_detail.dart';
import 'package:hs360/features/inventory_accounting/domain/inventory_document_filters.dart';
import 'package:hs360/features/inventory_accounting/domain/inventory_document_summary.dart';
import 'package:hs360/features/inventory_accounting/domain/stock_count_draft.dart';
import 'package:hs360/domain/validators/opening_stock_validator.dart';

class FakeInventoryDocumentRepository extends InventoryDocumentRepository {
  FakeInventoryDocumentRepository({
    List<InventoryDocumentSummary> documents = const [],
    this.fetchError,
    this.detailById = const {},
    this.reasons = const [],
  }) : documents = List<InventoryDocumentSummary>.from(documents),
       super(null);

  List<InventoryDocumentSummary> documents;
  Object? fetchError;
  Object? cancelError;
  Map<String, InventoryDocumentDetail> detailById;
  List<InventoryAdjustmentReason> reasons;

  PaginationCursor? lastPage;
  String? lastRecordedIdempotencyKey;

  @override
  Future<List<InventoryDocumentSummary>> listDocuments(
    AppSession session, {
    InventoryDocumentFilters filters = const InventoryDocumentFilters(),
    PaginationCursor page = const PaginationCursor(),
  }) async {
    if (fetchError != null) throw fetchError!;
    lastPage = page;
    final start = page.offset;
    final end = start + page.limit;
    if (start >= documents.length) return const [];
    return documents.sublist(
      start,
      end > documents.length ? documents.length : end,
    );
  }

  @override
  Future<InventoryDocumentDetail> getDetail(
    AppSession session,
    String documentId,
  ) async {
    if (fetchError != null) throw fetchError!;
    final detail = detailById[documentId];
    if (detail == null) {
      throw const FinanceException(code: FinanceException.notFound);
    }
    return detail;
  }

  @override
  Future<List<InventoryAdjustmentReason>> listReasons(
    AppSession session, {
    String? direction,
    String? documentType,
  }) async {
    return reasons;
  }

  @override
  Future<String> recordOpeningStock(
    AppSession session,
    OpeningStockInput input,
    String idempotencyKey,
  ) async {
    lastRecordedIdempotencyKey = idempotencyKey;
    return 'doc-new';
  }

  @override
  Future<String> recordStockCount(
    AppSession session,
    StockCountDraft draft,
    String idempotencyKey,
  ) async {
    lastRecordedIdempotencyKey = idempotencyKey;
    return 'doc-count';
  }

  @override
  Future<String> cancelDocument(
    AppSession session,
    String documentId,
    String reason,
    String idempotencyKey,
  ) async {
    if (cancelError != null) throw cancelError!;
    return documentId;
  }
}

InventoryDocumentSummary sampleInventoryDocumentSummary({
  String id = 'doc-1',
  InventoryDocumentKind kind = InventoryDocumentKind.stockIn,
}) {
  return InventoryDocumentSummary(
    id: id,
    documentNumber: 'STI-001',
    kind: kind,
    status: InventoryDocumentStatus.confirmed,
    date: DateTime(2026, 6, 1),
    warehouseId: 'wh-1',
    warehouseNameEn: 'Main',
  );
}
