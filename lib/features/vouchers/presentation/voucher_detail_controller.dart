import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/finance_exception.dart';
import '../../../domain/validators/cancellation_reason_validator.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/domain/finance_idempotency.dart';
import '../data/voucher_repository.dart';
import '../domain/voucher_permissions.dart';
import 'voucher_detail_state.dart';

part 'voucher_detail_controller.g.dart';

@riverpod
class VoucherDetailController extends _$VoucherDetailController {
  FinanceIdempotencySession? _idempotency;

  @override
  VoucherDetailState build(String voucherId) {
    Future.microtask(() => load(voucherId));
    return const VoucherDetailState(isLoading: true);
  }

  Future<void> load(String voucherId) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null || !canViewVouchers(session)) {
      state = const VoucherDetailState(
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
          .read(voucherRepositoryProvider)
          .getVoucherDetail(session, voucherId);
      state = VoucherDetailState(isLoading: false, detail: detail);
    } on FinanceException catch (e) {
      state = VoucherDetailState(isLoading: false, errorCode: e.code);
    } catch (_) {
      state = const VoucherDetailState(
        isLoading: false,
        errorCode: FinanceException.unknown,
      );
    }
  }

  Future<String?> cancel(String reason) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    final detail = state.detail;
    if (session == null || detail == null) return FinanceException.unknown;
    if (!canCancelVoucher(session)) return FinanceException.permissionDenied;

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
          .read(voucherRepositoryProvider)
          .cancelVoucher(session, detail.id, reason, _idempotency!.key);
      _idempotency!.clear();
      await load(detail.id);
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
}
