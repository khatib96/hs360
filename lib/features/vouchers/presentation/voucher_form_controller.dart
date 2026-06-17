import 'package:decimal/decimal.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/finance_exception.dart';
import '../../../domain/validators/voucher_allocation_validator.dart';
import '../../../domain/validators/voucher_validator.dart';
import '../../../domain/validators/validation_result.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/domain/finance_idempotency.dart';
import '../../finance_shared/domain/payment_method.dart';
import '../data/voucher_repository.dart';
import '../domain/voucher_form_state.dart';
import '../domain/voucher_permissions.dart';
import '../domain/voucher_type.dart';
import 'voucher_form_state.dart' as ui;

part 'voucher_form_controller.g.dart';

@riverpod
class VoucherFormController extends _$VoucherFormController {
  FinanceIdempotencySession? _idempotency;

  @override
  ui.VoucherFormUiState build(VoucherType voucherType) {
    return ui.VoucherFormUiState(
      voucherType: voucherType,
      form: _emptyForm(voucherType),
    );
  }

  void updateForm(VoucherFormState form) {
    state = state.copyWith(form: form, clearError: true, clearValidation: true);
  }

  Future<String?> submit() async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return FinanceException.unknown;

    final validation = const VoucherValidator()
        .validate(state.form)
        .merge(_allocationValidation(state.form));
    if (!validation.isValid) {
      state = state.copyWith(validationCodes: validation.codes);
      return validation.codes.first;
    }

    if (!_canCreate(session, state.voucherType)) {
      return FinanceException.permissionDenied;
    }

    _idempotency ??= FinanceIdempotencySession();
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearValidation: true,
    );

    try {
      final repo = ref.read(voucherRepositoryProvider);
      final id = switch (state.voucherType) {
        VoucherType.receipt => await repo.recordReceiptVoucher(
          session,
          state.form,
          _idempotency!.key,
        ),
        VoucherType.payment => await repo.recordPaymentVoucher(
          session,
          state.form,
          _idempotency!.key,
        ),
      };
      _idempotency!.clear();
      state = state.copyWith(isSubmitting: false, lastSavedVoucherId: id);
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

  VoucherFormState _emptyForm(VoucherType type) {
    return VoucherFormState(
      type: type,
      date: DateTime.now(),
      amount: Decimal.zero,
      paymentMethod: PaymentMethod.cash,
      cashAccountId: '',
    );
  }

  bool _canCreate(AppSession session, VoucherType type) {
    return switch (type) {
      VoucherType.receipt => canCreateReceiptVoucher(session),
      VoucherType.payment => canCreatePaymentVoucher(session),
    };
  }

  ValidationResult _allocationValidation(VoucherFormState form) {
    if (form.allocationMode != 'manual') {
      return const ValidationResult.valid();
    }
    return const VoucherAllocationValidator().validateManualAllocations(
      voucherAmount: form.amount,
      allocations: form.allocations,
    );
  }
}
