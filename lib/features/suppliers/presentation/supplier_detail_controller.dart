import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/supplier_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/supplier_repository.dart';
import '../domain/supplier_permissions.dart';
import 'supplier_detail_state.dart';

part 'supplier_detail_controller.g.dart';

@riverpod
class SupplierDetailController extends _$SupplierDetailController {
  @override
  SupplierDetailState build(String supplierId) {
    Future.microtask(() => load(supplierId));
    return const SupplierDetailState();
  }

  Future<void> load(String supplierId) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null || !canViewSuppliers(session)) {
      state = const SupplierDetailState(
        isLoading: false,
        errorCode: SupplierException.permissionDenied,
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final supplier = await ref
          .read(supplierRepositoryProvider)
          .fetchSupplierById(session, supplierId);
      state = SupplierDetailState(isLoading: false, supplier: supplier);
    } on SupplierException catch (e) {
      state = SupplierDetailState(isLoading: false, errorCode: e.code);
    } catch (_) {
      state = const SupplierDetailState(
        isLoading: false,
        errorCode: SupplierException.unknown,
      );
    }
  }
}
