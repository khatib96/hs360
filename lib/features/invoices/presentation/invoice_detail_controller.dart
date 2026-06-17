import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/finance_exception.dart';
import '../../../domain/validators/cancellation_reason_validator.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/domain/finance_idempotency.dart';
import '../data/invoice_repository.dart';
import '../domain/invoice_permissions.dart';
import '../domain/invoice_type.dart';
import 'invoice_detail_state.dart';

part 'invoice_detail_controller.g.dart';

@riverpod
class InvoiceDetailController extends _$InvoiceDetailController {
  FinanceIdempotencySession? _idempotency;

  @override
  InvoiceDetailState build(String invoiceId, {InvoiceType? type}) {
    Future.microtask(load);
    return const InvoiceDetailState(isLoading: true);
  }

  Future<void> load() async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null || !canViewAnyInvoices(session)) {
      state = const InvoiceDetailState(
        isLoading: false,
        errorCode: FinanceException.permissionDenied,
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearValidation: true,
    );
    try {
      final detail = await ref
          .read(invoiceRepositoryProvider)
          .fetchInvoiceDetail(invoiceId, session, type: type);
      if (!_canViewLoadedType(session, detail.type)) {
        state = const InvoiceDetailState(
          isLoading: false,
          errorCode: FinanceException.permissionDenied,
        );
        return;
      }
      state = InvoiceDetailState(isLoading: false, detail: detail);
    } on FinanceException catch (e) {
      state = InvoiceDetailState(isLoading: false, errorCode: e.code);
    } catch (_) {
      state = const InvoiceDetailState(
        isLoading: false,
        errorCode: FinanceException.unknown,
      );
    }
  }

  Future<String?> cancel(String reason) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    final detail = state.detail;
    if (session == null || detail == null) {
      return FinanceException.unknown;
    }
    if (!canCancelInvoice(session)) {
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
      final repo = ref.read(invoiceRepositoryProvider);
      if (detail.type.isReturn) {
        await repo.cancelReturnInvoice(
          session,
          detail.id,
          reason,
          _idempotency!.key,
        );
      } else {
        await repo.cancelInvoice(session, detail.id, reason, _idempotency!.key);
      }
      _idempotency!.clear();
      await load();
      state = state.copyWith(isSubmitting: false);
      return null;
    } on FinanceException catch (e) {
      if (_idempotency != null && !_idempotency!.shouldPreserveKeyOn(e)) {
        _idempotency!.clear();
      }
      state = state.copyWith(isSubmitting: false, errorCode: e.code);
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

  bool _canViewLoadedType(AppSession session, InvoiceType invoiceType) {
    return switch (invoiceType) {
      InvoiceType.sales => canViewSalesInvoices(session),
      InvoiceType.purchase => canViewPurchaseInvoices(session),
      InvoiceType.salesReturn ||
      InvoiceType.purchaseReturn => canViewReturnInvoices(session),
    };
  }
}
