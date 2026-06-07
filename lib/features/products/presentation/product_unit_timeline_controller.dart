import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/products_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/product_unit_repository.dart';
import '../domain/product_unit_permissions.dart';
import '../domain/unit_timeline_event.dart';

part 'product_unit_timeline_controller.g.dart';

class ProductUnitTimelineState {
  const ProductUnitTimelineState({
    this.isLoading = true,
    this.events = const [],
    this.errorCode,
  });

  final bool isLoading;
  final List<UnitTimelineEvent> events;
  final String? errorCode;
}

@riverpod
class ProductUnitTimelineController extends _$ProductUnitTimelineController {
  @override
  ProductUnitTimelineState build(String unitId) {
    Future.microtask(() => load(unitId));
    return const ProductUnitTimelineState();
  }

  Future<void> load(String unitId) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) {
      state = const ProductUnitTimelineState(isLoading: false);
      return;
    }

    if (!canViewProductUnits(session)) {
      state = const ProductUnitTimelineState(
        isLoading: false,
        errorCode: ProductsException.permissionDenied,
      );
      return;
    }

    state = const ProductUnitTimelineState(isLoading: true);
    try {
      final events = await ref
          .read(productUnitRepositoryProvider)
          .fetchUnitTimeline(unitId, session);
      state = ProductUnitTimelineState(isLoading: false, events: events);
    } on ProductsException catch (e) {
      state = ProductUnitTimelineState(
        isLoading: false,
        errorCode: e.code,
      );
    } catch (_) {
      state = const ProductUnitTimelineState(
        isLoading: false,
        errorCode: ProductsException.unknown,
      );
    }
  }
}
