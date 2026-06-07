import 'package:hs360/core/errors/products_exception.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/inventory/domain/warehouse.dart';
import 'package:hs360/features/products/data/product_unit_repository.dart';
import 'package:hs360/features/products/domain/product_unit.dart';
import 'package:hs360/features/products/domain/product_unit_form_state.dart';
import 'package:hs360/features/products/domain/unit_timeline_event.dart';

class FakeProductUnitRepository extends ProductUnitRepository {
  FakeProductUnitRepository({
    this.units = const [],
    this.unitById,
    this.timelineEvents = const [],
  }) : super(null);

  List<ProductUnit> units;
  ProductUnit? unitById;
  List<UnitTimelineEvent> timelineEvents;
  bool permissionDeniedOnCreate = false;
  ProductUnitCreateInput? lastCreateInput;
  List<ProductUnitCreateInput>? lastBulkInput;
  String? lastCorrectedSerial;
  String? lastCorrectionReason;

  @override
  Future<ProductUnit?> fetchUnitById(
    String unitId,
    AppSession session, {
    Map<String, Warehouse>? warehousesById,
  }) async {
    return unitById;
  }

  @override
  Future<List<UnitTimelineEvent>> fetchUnitTimeline(
    String unitId,
    AppSession session,
  ) async {
    return timelineEvents;
  }

  @override
  Future<String> correctSerial({
    required AppSession session,
    required String unitId,
    required String newSerial,
    required String reason,
  }) async {
    lastCorrectedSerial = newSerial;
    lastCorrectionReason = reason;
    return unitId;
  }

  @override
  Future<List<ProductUnit>> fetchUnitsByProductId(
    String productId,
    AppSession session, {
    Map<String, Warehouse>? warehousesById,
  }) async {
    return List<ProductUnit>.from(units);
  }

  @override
  Future<List<String>> createUnit({
    required AppSession session,
    required String productId,
    required String warehouseId,
    required ProductUnitCreateInput input,
  }) async {
    if (permissionDeniedOnCreate) {
      throw const ProductsException(code: ProductsException.permissionDenied);
    }
    lastCreateInput = input;
    return ['new-unit-id'];
  }

  @override
  Future<List<String>> bulkCreateUnits({
    required AppSession session,
    required String productId,
    required String warehouseId,
    required List<ProductUnitCreateInput> units,
  }) async {
    lastBulkInput = units;
    return List.generate(units.length, (i) => 'id-$i');
  }
}
