import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/finance_exception.dart';
import '../../../core/network/supabase_providers.dart';
import '../../../domain/validators/inventory_adjustment_document_validator.dart';
import '../../../domain/validators/opening_stock_validator.dart';
import '../../auth/domain/app_session.dart';
import '../../finance_shared/domain/date_range.dart';
import '../../finance_shared/domain/finance_permissions.dart';
import '../../finance_shared/domain/pagination_cursor.dart';
import '../domain/inventory_adjustment_reason.dart';
import '../domain/inventory_document_detail.dart';
import '../domain/inventory_document_filters.dart';
import '../domain/inventory_document_summary.dart';
import '../domain/stock_count_draft.dart';
import 'inventory_document_rpc_mapper.dart';

part 'inventory_document_repository.g.dart';

@Riverpod(keepAlive: true)
InventoryDocumentRepository inventoryDocumentRepository(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return InventoryDocumentRepository(client);
}

class InventoryDocumentRepository {
  InventoryDocumentRepository(this._client);

  static const defaultPageSize = 50;

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) throw FinanceException.notConfigured();
    return client;
  }

  void _assertCanView(AppSession session) {
    if (!canViewInventoryDocuments(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
  }

  Future<List<InventoryDocumentSummary>> listDocuments(
    AppSession session, {
    InventoryDocumentFilters filters = const InventoryDocumentFilters(),
    PaginationCursor page = const PaginationCursor(),
  }) async {
    _assertCanView(session);
    try {
      final rows = await _requireClient.rpc(
        'list_inventory_documents',
        params: {
          'p_document_type': filters.kind?.toDb(),
          'p_warehouse_id': filters.warehouseId,
          'p_date_from': dateRangeToIsoDate(filters.dateRange.from),
          'p_date_to': dateRangeToIsoDate(filters.dateRange.to),
          'p_limit': page.limit,
          'p_offset': page.offset,
        },
      );

      final list = _asJsonList(rows);
      return list
          .map(
            (r) => mapInventoryDocumentSummary(
              Map<String, dynamic>.from(r as Map),
            ),
          )
          .toList();
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<InventoryDocumentDetail> getDetail(
    AppSession session,
    String documentId,
  ) async {
    _assertCanView(session);
    try {
      final json = await _requireClient.rpc(
        'get_inventory_document_detail',
        params: {'p_document_id': documentId},
      );
      return mapInventoryDocumentDetail(Map<String, dynamic>.from(json as Map));
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<List<InventoryAdjustmentReason>> listReasons(
    AppSession session, {
    String? direction,
    String? documentType,
  }) async {
    if (!(canViewInventoryDocuments(session) ||
        canCreateInventoryAdjustment(session) ||
        canCreateStockCount(session))) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    try {
      final rows = await _requireClient.rpc(
        'list_inventory_adjustment_reasons',
        params: {
          'p_direction': direction,
          'p_document_type': documentType,
        },
      );
      final list = _asJsonList(rows);
      return list
          .map(
            (r) => mapInventoryAdjustmentReason(
              Map<String, dynamic>.from(r as Map),
            ),
          )
          .toList();
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<String> recordOpeningStock(
    AppSession session,
    OpeningStockInput input,
    String idempotencyKey,
  ) async {
    if (!canCreateOpeningStock(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    try {
      final id = await _requireClient.rpc(
        'record_opening_stock',
        params: {
          'p_data': openingStockPayload(input),
          'p_idempotency_key': idempotencyKey,
        },
      );
      return id as String;
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<String> recordAdjustment(
    AppSession session,
    InventoryAdjustmentDocumentInput input,
    String idempotencyKey,
  ) async {
    if (!canCreateInventoryAdjustment(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    try {
      final id = await _requireClient.rpc(
        'record_inventory_document',
        params: {
          'p_data': inventoryDocumentPayload(input),
          'p_idempotency_key': idempotencyKey,
        },
      );
      return id as String;
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<String> recordStockCount(
    AppSession session,
    StockCountDraft draft,
    String idempotencyKey,
  ) async {
    if (!canCreateStockCount(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    try {
      final id = await _requireClient.rpc(
        'record_stock_count',
        params: {
          'p_data': stockCountPayload(draft),
          'p_idempotency_key': idempotencyKey,
        },
      );
      return id as String;
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<String> cancelDocument(
    AppSession session,
    String documentId,
    String reason,
    String idempotencyKey,
  ) async {
    if (!canCancelInventoryDocument(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
    try {
      final id = await _requireClient.rpc(
        'cancel_inventory_document',
        params: cancelInventoryDocumentParams(
          documentId: documentId,
          reason: reason,
          idempotencyKey: idempotencyKey,
        ),
      );
      return id as String;
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }
}

List<Map<String, dynamic>> _asJsonList(dynamic rows) {
  if (rows is List) {
    return rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
  }
  return const [];
}
