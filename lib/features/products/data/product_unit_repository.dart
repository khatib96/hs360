import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/products_exception.dart';
import '../../../core/network/supabase_providers.dart';
import '../../auth/domain/app_session.dart';
import '../../inventory/domain/warehouse.dart';
import '../domain/product_cost_access.dart';
import '../domain/product_unit.dart';
import '../domain/product_unit_bulk_parser.dart';
import '../domain/product_unit_columns.dart';
import '../domain/product_unit_form_state.dart';
import '../domain/product_unit_permissions.dart';
import '../domain/unit_timeline_event.dart';

part 'product_unit_repository.g.dart';

@Riverpod(keepAlive: true)
ProductUnitRepository productUnitRepository(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return ProductUnitRepository(client);
}

class ProductUnitRepository {
  ProductUnitRepository(this._client);

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) throw ProductsException.notConfigured();
    return client;
  }

  Future<ProductUnit?> fetchUnitById(
    String unitId,
    AppSession session, {
    Map<String, Warehouse>? warehousesById,
  }) async {
    if (!canViewProductUnits(session)) {
      throw const ProductsException(code: ProductsException.permissionDenied);
    }

    try {
      final columns = ProductUnitColumns.forSession(session);
      final row = await _requireClient
          .from('product_units')
          .select(columns)
          .eq('id', unitId)
          .maybeSingle();

      if (row == null) return null;

      final map = Map<String, dynamic>.from(row);
      await _enrichUnitLocationNames(map, session);

      String? nameAr;
      String? nameEn;
      final whId = map['current_warehouse_id'] as String?;
      if (whId != null && warehousesById != null) {
        final wh = warehousesById[whId];
        nameAr = wh?.nameAr;
        nameEn = wh?.nameEn;
      }

      return ProductUnit.fromRow(
        map,
        warehouseNameAr: nameAr,
        warehouseNameEn: nameEn,
      );
    } catch (e, st) {
      throw ProductsException.fromSupabase(e, st);
    }
  }

  Future<List<UnitTimelineEvent>> fetchUnitTimeline(
    String unitId,
    AppSession session,
  ) async {
    if (!canViewProductUnits(session)) {
      throw const ProductsException(code: ProductsException.permissionDenied);
    }

    try {
      final rows = await _requireClient
          .from('v_unit_timeline')
          .select()
          .eq('product_unit_id', unitId)
          .order('occurred_at', ascending: false);

      return (rows as List)
          .map((r) => UnitTimelineEvent.fromRow(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e, st) {
      throw ProductsException.fromSupabase(e, st);
    }
  }

  Future<String> correctSerial({
    required AppSession session,
    required String unitId,
    required String newSerial,
    required String reason,
  }) async {
    if (!canCorrectProductUnitSerial(session)) {
      throw const ProductsException(code: ProductsException.permissionDenied);
    }

    final trimmedSerial = newSerial.trim();
    final trimmedReason = reason.trim();
    if (trimmedSerial.isEmpty || trimmedReason.isEmpty) {
      throw const ProductsException(code: ProductsException.validationFailed);
    }

    try {
      final response = await _requireClient.rpc(
        'correct_product_unit_serial',
        params: {
          'p_unit_id': unitId,
          'p_new_serial': trimmedSerial,
          'p_reason': trimmedReason,
        },
      );
      return response as String;
    } catch (e, st) {
      throw ProductsException.fromSupabase(e, st);
    }
  }

  Future<void> _enrichUnitLocationNames(
    Map<String, dynamic> map,
    AppSession session,
  ) async {
    final customerId = map['current_customer_id'] as String?;
    if (customerId != null) {
      final customer = await _requireClient
          .from('customers')
          .select('name_ar, name_en')
          .eq('id', customerId)
          .maybeSingle();
      if (customer != null) {
        map['customer_name_ar'] = customer['name_ar'];
        map['customer_name_en'] = customer['name_en'];
      }
    }

    final locationId = map['current_service_location_id'] as String?;
    if (locationId != null) {
      final location = await _requireClient
          .from('customer_service_locations')
          .select('name')
          .eq('id', locationId)
          .maybeSingle();
      if (location != null) {
        map['service_location_name'] = location['name'];
      }
    }
  }

  Future<List<ProductUnit>> fetchUnitsByProductId(
    String productId,
    AppSession session, {
    Map<String, Warehouse>? warehousesById,
  }) async {
    if (!canViewProductUnits(session)) {
      throw const ProductsException(code: ProductsException.permissionDenied);
    }

    try {
      final columns = ProductUnitColumns.forSession(session);
      final rows = await _requireClient
          .from('product_units')
          .select(columns)
          .eq('product_id', productId)
          .order('serial_number');

      return (rows as List).map((r) {
        final map = Map<String, dynamic>.from(r);
        String? nameAr;
        String? nameEn;
        final whId = map['current_warehouse_id'] as String?;
        if (whId != null && warehousesById != null) {
          final wh = warehousesById[whId];
          nameAr = wh?.nameAr;
          nameEn = wh?.nameEn;
        }
        return ProductUnit.fromRow(
          map,
          warehouseNameAr: nameAr,
          warehouseNameEn: nameEn,
        );
      }).toList();
    } catch (e, st) {
      throw ProductsException.fromSupabase(e, st);
    }
  }

  Future<List<String>> createUnit({
    required AppSession session,
    required String productId,
    required String warehouseId,
    required ProductUnitCreateInput input,
  }) async {
    return bulkCreateUnits(
      session: session,
      productId: productId,
      warehouseId: warehouseId,
      units: [input],
    );
  }

  Future<List<String>> bulkCreateUnits({
    required AppSession session,
    required String productId,
    required String warehouseId,
    required List<ProductUnitCreateInput> units,
  }) async {
    if (!canCreateProductUnits(session)) {
      throw const ProductsException(code: ProductsException.permissionDenied);
    }
    if (units.isEmpty) {
      throw const ProductsException(code: ProductsException.validationFailed);
    }
    if (units.length > ProductUnitBulkParser.maxUnitsPerBatch) {
      throw const ProductsException(code: ProductsException.bulkLimitExceeded);
    }

    final jsonUnits = units.map((u) => _unitToJson(session, u)).toList();

    try {
      final response = await _requireClient.rpc(
        'create_product_units',
        params: {
          'p_product_id': productId,
          'p_warehouse_id': warehouseId,
          'p_units': jsonUnits,
        },
      );
      return (response as List).map((id) => id as String).toList();
    } catch (e, st) {
      throw ProductsException.fromSupabase(e, st);
    }
  }

  Future<List<String>> prepareSerialTracking({
    required AppSession session,
    required String productId,
    required String warehouseId,
    required List<String> serials,
    required String reason,
  }) async {
    if (!canReconcileProductUnitSerials(session)) {
      throw const ProductsException(code: ProductsException.permissionDenied);
    }
    final cleaned = serials.map((s) => s.trim()).where((s) => s.isNotEmpty);
    final values = cleaned.toList();
    if (values.isEmpty || reason.trim().isEmpty) {
      throw const ProductsException(code: ProductsException.validationFailed);
    }

    try {
      final response = await _requireClient.rpc(
        'prepare_product_serial_tracking',
        params: {
          'p_product_id': productId,
          'p_warehouse_id': warehouseId,
          'p_serials': values,
          'p_reason': reason.trim(),
        },
      );
      return (response as List).map((id) => id as String).toList();
    } catch (e, st) {
      throw ProductsException.fromSupabase(e, st);
    }
  }

  Future<String> updateUnitSafe({
    required AppSession session,
    required String unitId,
    required ProductUnitSafeEditInput input,
  }) async {
    if (!canEditProductUnits(session)) {
      throw const ProductsException(code: ProductsException.permissionDenied);
    }

    try {
      final response = await _requireClient.rpc(
        'update_product_unit_safe',
        params: {
          'p_unit_id': unitId,
          'p_barcode': input.barcode,
          'p_notes': input.notes,
          'p_health_status': input.healthStatus?.toDb(),
        },
      );
      return response as String;
    } catch (e, st) {
      throw ProductsException.fromSupabase(e, st);
    }
  }

  Map<String, dynamic> _unitToJson(
    AppSession session,
    ProductUnitCreateInput input,
  ) {
    final map = <String, dynamic>{
      'serial_number': input.serialNumber.trim(),
      if (input.barcode != null && input.barcode!.trim().isNotEmpty)
        'barcode': input.barcode!.trim(),
      'health_status': input.healthStatus.toDb(),
      if (input.acquiredAt != null)
        'acquired_at': _formatDate(input.acquiredAt!),
      if (input.notes != null && input.notes!.trim().isNotEmpty)
        'notes': input.notes!.trim(),
    };

    if (canViewFullProductCosts(session) && input.purchaseCost != null) {
      map['purchase_cost'] = input.purchaseCost!.toString();
    }

    return map;
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-'
        '${date.day.toString().padLeft(2, '0')}';
  }
}
