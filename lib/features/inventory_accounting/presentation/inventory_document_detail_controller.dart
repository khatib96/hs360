import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/finance_exception.dart';
import '../../../domain/validators/cancellation_reason_validator.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/domain/finance_idempotency.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product_filters.dart';
import '../../products/domain/product_permissions.dart';
import '../data/inventory_document_repository.dart';
import '../domain/inventory_document_detail.dart';
import '../domain/inventory_document_permissions.dart';
import 'inventory_document_detail_state.dart';

part 'inventory_document_detail_controller.g.dart';

@riverpod
class InventoryDocumentDetailController
    extends _$InventoryDocumentDetailController {
  FinanceIdempotencySession? _idempotency;

  @override
  InventoryDocumentDetailState build(String documentId) {
    Future.microtask(load);
    return const InventoryDocumentDetailState(isLoading: true);
  }

  AppSession? get _session => ref.read(authControllerProvider).valueOrNull;

  bool canShowCancelButton(AppSession session) {
    final detail = state.detail;
    if (detail == null) return false;
    if (!canCancelInventoryDocument(session)) return false;
    if (detail.isCancelled) return false;
    if (detail.isSerialized) return false;
    if (state.cancelBlocked) return false;
    return true;
  }

  Future<void> load() async {
    final session = _session;
    if (session == null || !canViewInventoryDocuments(session)) {
      state = const InventoryDocumentDetailState(
        isLoading: false,
        errorCode: FinanceException.permissionDenied,
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearValidation: true,
      cancelBlocked: false,
    );

    try {
      final detail = await ref
          .read(inventoryDocumentRepositoryProvider)
          .getDetail(session, documentId);
      final labels = await _loadProductLabels(session, detail);
      state = InventoryDocumentDetailState(
        isLoading: false,
        detail: detail,
        productLabels: labels,
      );
    } on FinanceException catch (e) {
      state = InventoryDocumentDetailState(isLoading: false, errorCode: e.code);
    } catch (_) {
      state = const InventoryDocumentDetailState(
        isLoading: false,
        errorCode: FinanceException.unknown,
      );
    }
  }

  Future<Map<String, String>> _loadProductLabels(
    AppSession session,
    InventoryDocumentDetail detail,
  ) async {
    if (!canViewProductsList(session)) return const {};
    final productIds = detail.lines.map((l) => l.productId).toSet().toList();
    if (productIds.isEmpty) return const {};

    try {
      final products = await ref
          .read(productRepositoryProvider)
          .fetchProducts(const ProductFilters(isActive: null), session);
      final labels = <String, String>{};
      for (final product in products) {
        if (productIds.contains(product.id)) {
          labels[product.id] = product.nameEn.isNotEmpty
              ? product.nameEn
              : product.nameAr;
        }
      }
      return labels;
    } catch (_) {
      return const {};
    }
  }

  Future<String?> cancel(String reason) async {
    final session = _session;
    if (session == null) return FinanceException.unknown;
    if (!canCancelInventoryDocument(session)) {
      return FinanceException.permissionDenied;
    }

    final validation = const CancellationReasonValidator().validate(reason);
    if (!validation.isValid) {
      state = state.copyWith(validationCodes: validation.codes);
      return validation.codes.first;
    }

    _idempotency ??= FinanceIdempotencySession();
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearValidation: true,
    );

    try {
      await ref
          .read(inventoryDocumentRepositoryProvider)
          .cancelDocument(session, documentId, reason, _idempotency!.key);
      _idempotency!.clear();
      await load();
      state = state.copyWith(isSubmitting: false);
      return null;
    } on FinanceException catch (e) {
      if (_idempotency != null && !_idempotency!.shouldPreserveKeyOn(e)) {
        _idempotency!.clear();
      }
      if (e.code == FinanceException.correctionDocumentRequired) {
        state = state.copyWith(
          isSubmitting: false,
          errorCode: e.code,
          cancelBlocked: true,
        );
      } else {
        state = state.copyWith(isSubmitting: false, errorCode: e.code);
      }
      return e.code;
    } catch (_) {
      _idempotency?.clear();
      state = state.copyWith(
        isSubmitting: false,
        errorCode: FinanceException.unknown,
      );
      return FinanceException.unknown;
    }
  }
}
