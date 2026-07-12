import 'package:decimal/decimal.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/finance_exception.dart';
import '../../../domain/validators/contract_lifecycle_validator.dart';
import '../../accounting/data/chart_account_repository.dart';
import '../../accounting/domain/chart_account.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/domain/cash_bank_posting_accounts.dart';
import '../../finance_shared/domain/finance_idempotency.dart';
import '../../finance_shared/domain/payment_method.dart';
import '../data/contract_repository.dart';
import '../domain/contract_detail.dart';
import '../domain/contract_permissions.dart';
import '../domain/contract_rental_collection_months.dart';
import '../domain/rental_collection_draft.dart';
import 'contract_rental_collection_state.dart';

part 'contract_rental_collection_controller.g.dart';

@riverpod
class ContractRentalCollectionController
    extends _$ContractRentalCollectionController {
  FinanceIdempotencySession? _idempotency;
  String? _lastPayloadSignature;

  @override
  ContractRentalCollectionUiState build(String contractId) {
    return ContractRentalCollectionUiState(
      collectionDate: DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ),
    );
  }

  AppSession? get _session => ref.read(authControllerProvider).valueOrNull;

  Future<void> initialize(ContractDetail detail) async {
    final session = _session;
    if (session == null) return;

    state = state.copyWith(
      isLoadingMonths: true,
      isLoadingMeta: true,
      clearError: true,
      clearValidation: true,
      clearPreview: true,
      clearLastResult: true,
      showSuccessActions: false,
    );

    try {
      final covered = await ref
          .read(contractRepositoryProvider)
          .listCoveredRentalMonths(session, detail.id);
      final eligible = ContractRentalCollectionMonths.buildEligibleMonthKeys(
        detail: detail,
        coveredMonthKeys: covered.toSet(),
      );

      var cashAccounts = const <ChartAccount>[];
      final canLoad = canLoadCashBankPostingAccounts(session);
      if (canLoad) {
        final all = await ref
            .read(chartAccountRepositoryProvider)
            .fetchChartAccounts(session, isActive: true);
        cashAccounts = filterCashBankPostingAccounts(all);
      }

      final defaultCash = cashAccounts
          .where((a) => a.code == '1101')
          .map((a) => a.id)
          .firstOrNull;

      state = state.copyWith(
        isLoadingMonths: false,
        isLoadingMeta: false,
        coveredMonthKeys: covered,
        eligibleMonthKeys: eligible,
        selectedMonthKeys: eligible.isNotEmpty ? [eligible.first] : const [],
        cashBankAccounts: cashAccounts,
        canLoadCashAccounts: canLoad,
        cashAccountId: defaultCash ?? state.cashAccountId,
      );
      await refreshPreview(detail);
    } on FinanceException catch (e) {
      state = state.copyWith(
        isLoadingMonths: false,
        isLoadingMeta: false,
        errorCode: e.code,
        clearError: false,
      );
    } catch (_) {
      state = state.copyWith(
        isLoadingMonths: false,
        isLoadingMeta: false,
        errorCode: FinanceException.unknown,
        clearError: false,
      );
    }
  }

  void toggleMonth(String monthKey, ContractDetail detail) {
    final selected = List<String>.from(state.selectedMonthKeys);
    if (selected.contains(monthKey)) {
      selected.remove(monthKey);
    } else {
      if (!ContractRentalCollectionMonths.isMonthAllowed(
        detail: detail,
        monthKey: monthKey,
        coveredMonthKeys: state.coveredMonthKeys.toSet(),
      )) {
        return;
      }
      selected.add(monthKey);
      selected.sort();
    }
    _rotateIdempotencyIfPayloadChanged();
    state = state.copyWith(
      selectedMonthKeys: selected,
      clearPreview: true,
      clearValidation: true,
      clearError: true,
    );
  }

  void setCollectionDate(DateTime date) {
    _rotateIdempotencyIfPayloadChanged();
    state = state.copyWith(
      collectionDate: DateTime(date.year, date.month, date.day),
      clearPreview: true,
      clearValidation: true,
      clearError: true,
    );
  }

  void setPaymentMethod(PaymentMethod method) {
    _rotateIdempotencyIfPayloadChanged();
    state = state.copyWith(
      paymentMethod: method,
      clearPreview: true,
      clearValidation: true,
      clearError: true,
    );
  }

  void setCashAccountId(String accountId) {
    _rotateIdempotencyIfPayloadChanged();
    state = state.copyWith(
      cashAccountId: accountId,
      clearPreview: true,
      clearValidation: true,
      clearError: true,
    );
  }

  void setReferenceNo(String value) {
    _rotateIdempotencyIfPayloadChanged();
    state = state.copyWith(
      referenceNo: value,
      clearPreview: true,
      clearValidation: true,
      clearError: true,
    );
  }

  void setNotes(String value) {
    _rotateIdempotencyIfPayloadChanged();
    state = state.copyWith(
      notes: value,
      clearPreview: true,
      clearValidation: true,
      clearError: true,
    );
  }

  Future<void> refreshPreview(ContractDetail detail) async {
    final session = _session;
    if (session == null || !canPreviewRentalCollection(session)) return;

    if (state.selectedMonthKeys.isEmpty || state.cashAccountId.trim().isEmpty) {
      state = state.copyWith(clearPreview: true);
      return;
    }

    final placeholderAmount =
        (detail.monthlyRentalValue ?? Decimal.one) *
        Decimal.fromInt(state.selectedMonthKeys.length);
    final draft = _buildDraft(detail, amount: placeholderAmount);
    final validation = const ContractLifecycleValidator()
        .validateRentalCollection(draft);
    if (!validation.isValid) {
      state = state.copyWith(clearPreview: true);
      return;
    }

    state = state.copyWith(
      isPreviewLoading: true,
      clearError: true,
      clearValidation: true,
    );
    try {
      final preview = await ref
          .read(contractRepositoryProvider)
          .previewRentalCollection(session, draft);
      state = state.copyWith(isPreviewLoading: false, preview: preview);
      _ensureIdempotencyForCurrentPayload();
    } on FinanceException catch (e) {
      state = state.copyWith(
        isPreviewLoading: false,
        errorCode: e.code,
        clearError: false,
      );
    } catch (_) {
      state = state.copyWith(
        isPreviewLoading: false,
        errorCode: FinanceException.unknown,
        clearError: false,
      );
    }
  }

  Future<RentalCollectionResult?> submit(ContractDetail detail) async {
    final session = _session;
    if (session == null || !canCollectRentalPayment(session)) {
      state = state.copyWith(
        errorCode: FinanceException.permissionDenied,
        clearError: false,
      );
      return null;
    }

    final amount = state.preview?.expectedCollectedAmount;
    if (amount == null) {
      await refreshPreview(detail);
      return null;
    }

    final draft = _buildDraft(detail, amount: amount);
    final validation = const ContractLifecycleValidator()
        .validateRentalCollection(draft);
    if (!validation.isValid) {
      state = state.copyWith(
        validationCodes: validation.codes,
        clearError: true,
      );
      return null;
    }

    _ensureIdempotencyForCurrentPayload();
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearValidation: true,
      showSuccessActions: false,
    );

    try {
      final result = await ref
          .read(contractRepositoryProvider)
          .collectRentalPayment(session, draft, _idempotency!.key);
      _idempotency!.regenerate();
      _lastPayloadSignature = null;
      state = state.copyWith(
        isSubmitting: false,
        lastResult: result,
        showSuccessActions: true,
      );
      return result;
    } on FinanceException catch (e) {
      if (_idempotency != null && !_idempotency!.shouldPreserveKeyOn(e)) {
        _idempotency!.regenerate();
        _lastPayloadSignature = null;
      }
      state = state.copyWith(
        isSubmitting: false,
        errorCode: e.code,
        clearError: false,
      );
      return null;
    } catch (_) {
      state = state.copyWith(
        isSubmitting: false,
        errorCode: FinanceException.unknown,
        clearError: false,
      );
      return null;
    }
  }

  RentalCollectionDraft _buildDraft(
    ContractDetail detail, {
    required Decimal amount,
  }) {
    return RentalCollectionDraft(
      contractId: detail.id,
      date: state.collectionDate ?? DateTime.now(),
      amount: amount,
      paymentMethod: state.paymentMethod,
      cashAccountId: state.cashAccountId.trim(),
      coverageMonths: List<String>.from(state.selectedMonthKeys),
      notes: state.notes.trim().isEmpty ? null : state.notes.trim(),
      referenceNo: state.referenceNo.trim().isEmpty
          ? null
          : state.referenceNo.trim(),
    );
  }

  void _ensureIdempotencyForCurrentPayload() {
    final signature = _payloadSignature();
    if (_idempotency == null || _lastPayloadSignature != signature) {
      _idempotency ??= FinanceIdempotencySession();
      if (_lastPayloadSignature != null && _lastPayloadSignature != signature) {
        _idempotency!.regenerate();
      }
      _lastPayloadSignature = signature;
    }
  }

  void _rotateIdempotencyIfPayloadChanged() {
    final signature = _payloadSignature();
    if (_lastPayloadSignature != null && _lastPayloadSignature != signature) {
      _idempotency?.regenerate();
      _lastPayloadSignature = signature;
    }
  }

  String _payloadSignature() {
    return [
      state.selectedMonthKeys.join(','),
      state.collectionDate?.toIso8601String(),
      state.paymentMethod.toDb(),
      state.cashAccountId,
      state.referenceNo,
      state.notes,
    ].join('|');
  }

  void clearTransientState() {
    _idempotency = null;
    _lastPayloadSignature = null;
    state = ContractRentalCollectionUiState(
      collectionDate: DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
      ),
    );
  }
}
