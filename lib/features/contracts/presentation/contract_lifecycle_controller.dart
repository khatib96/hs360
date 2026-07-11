import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/finance_exception.dart';
import '../../../domain/validators/contract_lifecycle_validator.dart';
import '../../../domain/validators/validation_result.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/domain/finance_idempotency.dart';
import '../data/contract_repository.dart';
import '../domain/closure_draft.dart';
import '../domain/consumable_change_draft.dart';
import '../domain/contract_detail.dart';
import '../domain/contract_line.dart';
import '../domain/contract_permissions.dart';
import '../domain/trial_extension_draft.dart';
import '../domain/trial_return_draft.dart';

part 'contract_lifecycle_controller.g.dart';

class ContractLifecycleUiState {
  const ContractLifecycleUiState({
    this.isSubmitting = false,
    this.errorCode,
    this.validationCodes = const [],
    this.lastMutationContractId,
  });

  final bool isSubmitting;
  final String? errorCode;
  final List<String> validationCodes;
  final String? lastMutationContractId;

  ContractLifecycleUiState copyWith({
    bool? isSubmitting,
    String? errorCode,
    bool clearError = true,
    List<String>? validationCodes,
    bool clearValidation = false,
    String? lastMutationContractId,
    bool clearLastMutationContractId = false,
  }) {
    return ContractLifecycleUiState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      validationCodes: clearValidation
          ? const []
          : (validationCodes ?? this.validationCodes),
      lastMutationContractId: clearLastMutationContractId
          ? null
          : (lastMutationContractId ?? this.lastMutationContractId),
    );
  }
}

@riverpod
class ContractLifecycleController extends _$ContractLifecycleController {
  FinanceIdempotencySession? _idempotency;

  @override
  ContractLifecycleUiState build() => const ContractLifecycleUiState();

  Future<String?> extendTrial({
    required TrialExtensionDraft draft,
    required ContractDetail detail,
  }) async {
    return _submit(
      permission: canExtendTrial,
      validate: () => const ContractLifecycleValidator().validateExtension(
        draft,
        currentTrialEndDate: detail.trialEndDate,
      ),
      mutate: (session, key) => ref
          .read(contractRepositoryProvider)
          .extendTrialContract(session, draft, key),
      successContractId: draft.trialContractId,
    );
  }

  Future<String?> returnTrial({required TrialReturnDraft draft}) async {
    return _submit(
      permission: canReturnTrial,
      validate: () => const ContractLifecycleValidator().validateReturn(draft),
      mutate: (session, key) => ref
          .read(contractRepositoryProvider)
          .returnTrialContract(session, draft, key),
      successContractId: draft.trialContractId,
    );
  }

  Future<String?> closeContract({
    required ClosureDraft draft,
    required ContractDetail detail,
  }) async {
    return _submit(
      permission: canCloseContract,
      validate: () => const ContractLifecycleValidator().validateClosure(
        draft,
        contractStartDate: detail.startDate,
      ),
      mutate: (session, key) => ref
          .read(contractRepositoryProvider)
          .closeContract(session, draft, key),
      successContractId: draft.contractId,
    );
  }

  Future<String?> scheduleConsumableChange({
    required ConsumableChangeDraft draft,
    required ContractDetail detail,
    required ContractConsumableLine line,
  }) async {
    return _submit(
      permission: canScheduleConsumableChange,
      validate: () =>
          const ContractLifecycleValidator().validateConsumableChange(
            draft,
            contractStartDate: detail.startDate,
            lineScheduledEffectiveFrom: line.scheduledEffectiveFrom,
          ),
      mutate: (session, key) => ref
          .read(contractRepositoryProvider)
          .scheduleConsumableChange(session, draft, key),
      successContractId: draft.contractId,
    );
  }

  Future<String?> _submit({
    required bool Function(AppSession session) permission,
    required ValidationResult Function() validate,
    required Future<String> Function(AppSession session, String key) mutate,
    required String successContractId,
  }) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null || !permission(session)) {
      return FinanceException.permissionDenied;
    }

    final validation = validate();
    if (!validation.isValid) {
      state = state.copyWith(
        validationCodes: validation.codes,
        clearError: true,
      );
      return validation.codes.first;
    }

    _idempotency ??= FinanceIdempotencySession();
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearValidation: true,
    );

    try {
      final id = await mutate(session, _idempotency!.key);
      state = state.copyWith(isSubmitting: false, lastMutationContractId: id);
      return null;
    } on FinanceException catch (e) {
      state = state.copyWith(isSubmitting: false, errorCode: e.code);
      return e.code;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorCode: FinanceException.unknown,
      );
      return FinanceException.unknown;
    }
  }

  void clearTransientState() {
    state = const ContractLifecycleUiState();
    _idempotency = null;
  }
}
