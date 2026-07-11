import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/finance_exception.dart';
import '../../../core/utils/decimal_parser.dart';
import '../../../domain/validators/contract_lifecycle_validator.dart';
import '../../../domain/validators/validation_result.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/domain/finance_idempotency.dart';
import '../data/contract_repository.dart';
import '../domain/contract_permissions.dart';
import '../domain/contract_type.dart';
import 'contract_convert_draft_builder.dart';
import 'contract_convert_state.dart';

part 'contract_convert_controller.g.dart';

@riverpod
class ContractConvertController extends _$ContractConvertController {
  FinanceIdempotencySession? _idempotency;
  Timer? _previewDebounce;

  @override
  ContractConvertUiState build(String trialContractId) {
    ref.onDispose(() => _previewDebounce?.cancel());
    Future.microtask(() => load(trialContractId));
    return const ContractConvertUiState(isLoading: true);
  }

  Future<void> load(String trialContractId) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null || !canConvertTrial(session)) {
      state = const ContractConvertUiState(
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
          .read(contractRepositoryProvider)
          .fetchContractDetail(session, trialContractId);
      if (detail.type != ContractType.trial) {
        state = const ContractConvertUiState(
          isLoading: false,
          errorCode: FinanceException.validationFailed,
        );
        return;
      }
      final conversionStartDate = normalizeConversionStartDate();
      final cycleDay = defaultCycleDay(conversionStartDate);
      final endDate = defaultConversionEndDate(conversionStartDate);
      state = ContractConvertUiState(
        trialDetail: detail,
        conversionStartDate: conversionStartDate,
        endDate: endDate,
        billingDay: cycleDay,
        refillDay: cycleDay,
      );
      _schedulePreview();
    } on FinanceException catch (e) {
      state = ContractConvertUiState(isLoading: false, errorCode: e.code);
    } catch (_) {
      state = const ContractConvertUiState(
        isLoading: false,
        errorCode: FinanceException.unknown,
      );
    }
  }

  void setMonthlyRentalValue(Decimal? value) {
    state = state.copyWith(
      monthlyRentalValue: value,
      clearMonthlyRentalValue: value == null,
      clearValidation: true,
      clearError: true,
    );
    _schedulePreview();
  }

  void setMonthlyRentalValueFromText(String text) {
    setMonthlyRentalValue(tryParseDecimal(text.trim()));
  }

  void setEndDate(DateTime? date) {
    state = state.copyWith(
      endDate: date == null ? null : DateTime(date.year, date.month, date.day),
      clearEndDate: date == null,
      clearValidation: true,
      clearError: true,
    );
    _schedulePreview();
  }

  void applyTwelveMonthTerm() {
    final start = state.conversionStartDate;
    if (start == null) return;
    setEndDate(defaultConversionEndDate(start));
  }

  void setBillingDay(int? day) {
    state = state.copyWith(
      billingDay: day,
      clearBillingDay: day == null,
      clearValidation: true,
      clearError: true,
    );
  }

  void setRefillDay(int? day) {
    state = state.copyWith(
      refillDay: day,
      clearRefillDay: day == null,
      clearValidation: true,
      clearError: true,
    );
  }

  void setBillingDate(DateTime? date) {
    setBillingDay(date == null ? null : defaultCycleDay(date));
  }

  void setRefillDate(DateTime? date) {
    setRefillDay(date == null ? null : defaultCycleDay(date));
  }

  void setRequestOverride(bool value) {
    state = state.copyWith(
      requestOverride: value,
      clearValidation: true,
      clearError: true,
      overrideReason: value ? state.overrideReason : '',
    );
    _schedulePreview();
  }

  void setOverrideReason(String value) {
    state = state.copyWith(
      overrideReason: value,
      clearValidation: true,
      clearError: true,
    );
  }

  void _schedulePreview() {
    _previewDebounce?.cancel();
    _previewDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(refreshPreview());
    });
  }

  Future<void> refreshPreview() async {
    final session = ref.read(authControllerProvider).valueOrNull;
    final trial = state.trialDetail;
    final conversionStartDate = state.conversionStartDate;
    final monthly = state.monthlyRentalValue;
    if (session == null ||
        !canPreviewContractProfit(session) ||
        trial == null ||
        conversionStartDate == null ||
        monthly == null ||
        monthly <= Decimal.zero) {
      state = state.copyWith(
        clearPricingPreview: true,
        isLoadingPreview: false,
      );
      return;
    }

    state = state.copyWith(isLoadingPreview: true, clearError: true);
    try {
      final draft = buildConversionPreviewDraft(
        trialDetail: trial,
        conversionStartDate: conversionStartDate,
        monthlyRentalValue: monthly,
        endDate: state.endDate,
        billingDay: state.billingDay,
        refillDay: state.refillDay,
        requestOverride: state.requestOverride,
        overrideReason: state.overrideReason,
      );
      final preview = await ref
          .read(contractRepositoryProvider)
          .previewContractProfit(session, draft);
      state = state.copyWith(pricingPreview: preview, isLoadingPreview: false);
    } on FinanceException catch (e) {
      state = state.copyWith(isLoadingPreview: false, errorCode: e.code);
    } catch (_) {
      state = state.copyWith(
        isLoadingPreview: false,
        errorCode: FinanceException.unknown,
      );
    }
  }

  ValidationResult validate() {
    final trial = state.trialDetail;
    if (trial == null) {
      return const ValidationResult(codes: [FinanceException.validationFailed]);
    }
    final draft = buildTrialConversionDraft(
      trialContractId: trial.id,
      monthlyRentalValue: state.monthlyRentalValue ?? Decimal.zero,
      endDate: state.endDate,
      billingDay: state.billingDay,
      refillDay: state.refillDay,
      requestOverride: state.requestOverride,
      overrideReason: state.overrideReason,
    );
    return const ContractLifecycleValidator().validateConversion(draft);
  }

  Future<String?> submit() async {
    final session = ref.read(authControllerProvider).valueOrNull;
    final trial = state.trialDetail;
    if (session == null || !canConvertTrial(session) || trial == null) {
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

    final draft = buildTrialConversionDraft(
      trialContractId: trial.id,
      monthlyRentalValue: state.monthlyRentalValue!,
      endDate: state.endDate,
      billingDay: state.billingDay,
      refillDay: state.refillDay,
      requestOverride: state.requestOverride,
      overrideReason: state.overrideReason,
    );

    try {
      final rentalId = await ref
          .read(contractRepositoryProvider)
          .convertTrialToRental(session, draft, _idempotency!.key);
      state = state.copyWith(
        isSubmitting: false,
        lastRentalContractId: rentalId,
      );
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
}
