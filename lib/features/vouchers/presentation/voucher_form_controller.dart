import 'package:decimal/decimal.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/finance_exception.dart';
import '../../../core/utils/decimal_parser.dart';
import '../../../domain/validators/voucher_allocation_validator.dart';
import '../../../domain/validators/voucher_validator.dart';
import '../../../domain/validators/validation_result.dart';
import '../../accounting/data/chart_account_repository.dart';
import '../../accounting/domain/chart_account.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../customers/data/customer_repository.dart';
import '../../customers/domain/customer.dart';
import '../../finance_shared/domain/cash_bank_posting_accounts.dart';
import '../../finance_shared/domain/finance_idempotency.dart';
import '../../finance_shared/domain/payment_method.dart';
import '../../suppliers/data/supplier_repository.dart';
import '../../suppliers/domain/supplier.dart';
import '../data/voucher_repository.dart';
import '../domain/voucher_form_state.dart';
import '../domain/voucher_permissions.dart';
import '../domain/voucher_type.dart';
import 'voucher_form_draft_builder.dart';
import 'voucher_form_party_handlers.dart';
import 'voucher_form_state.dart' as ui;

part 'voucher_form_controller.g.dart';

@riverpod
class VoucherFormController extends _$VoucherFormController {
  FinanceIdempotencySession? _idempotency;

  @override
  ui.VoucherFormUiState build(VoucherType voucherType) {
    Future.microtask(loadMeta);
    final session = ref.read(authControllerProvider).valueOrNull;
    return ui.VoucherFormUiState(
      voucherType: voucherType,
      form: _emptyForm(voucherType),
      canLoadCashAccounts:
          session != null && canLoadCashBankPostingAccounts(session),
    );
  }

  AppSession? get _session => ref.read(authControllerProvider).valueOrNull;

  Future<void> loadMeta() async {
    final session = _session;
    if (session == null) return;

    final canLoad = canLoadCashBankPostingAccounts(session);
    state = state.copyWith(
      isLoadingMeta: true,
      canLoadCashAccounts: canLoad,
      clearError: true,
    );

    try {
      var cashBankAccounts = const <ChartAccount>[];
      var postingAccounts = const <ChartAccount>[];
      if (canLoad) {
        final all = await ref
            .read(chartAccountRepositoryProvider)
            .fetchChartAccounts(session, isActive: true);
        postingAccounts = filterPostingLeafAccounts(all);
        cashBankAccounts = _sortVoucherSourceAccounts(postingAccounts);
      }

      final currentSourceId = state.form.cashAccountId.trim();
      final defaultSourceId = currentSourceId.isNotEmpty
          ? currentSourceId
          : _defaultVoucherSourceAccountId(cashBankAccounts);
      state = state.copyWith(
        isLoadingMeta: false,
        cashBankAccounts: cashBankAccounts,
        postingAccounts: postingAccounts,
        form: defaultSourceId == null
            ? state.form
            : state.form.copyWith(cashAccountId: defaultSourceId),
      );
    } on FinanceException catch (e) {
      state = state.copyWith(isLoadingMeta: false, errorCode: e.code);
    } catch (_) {
      state = state.copyWith(
        isLoadingMeta: false,
        errorCode: FinanceException.unknown,
      );
    }
  }

  Future<void> searchParty(String query) async {
    final session = _session;
    if (session == null) return;
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(partySearchResults: const []);
      return;
    }

    state = state.copyWith(isSearchingParty: true);
    try {
      final results = await searchVoucherParties(
        session: session,
        voucherType: state.voucherType,
        query: trimmed,
        customerRepository: ref.read(customerRepositoryProvider),
        supplierRepository: ref.read(supplierRepositoryProvider),
      );
      state = state.copyWith(
        partySearchResults: results,
        isSearchingParty: false,
      );
    } catch (_) {
      state = state.copyWith(
        partySearchResults: const [],
        isSearchingParty: false,
      );
    }
  }

  void selectCustomer(Customer customer) {
    state = applyCustomerSelection(state, customer);
    loadOpenInvoices();
  }

  void selectSupplier(Supplier supplier) {
    state = applySupplierSelection(state, supplier);
    loadOpenInvoices();
  }

  Future<void> loadOpenInvoices() async {
    final session = _session;
    if (session == null) return;

    final customerId = state.selectedCustomer?.id;
    final supplierId = state.selectedSupplier?.id;
    final isReceipt = state.voucherType == VoucherType.receipt;
    final isSupplierPayment =
        state.voucherType == VoucherType.payment &&
        (state.form.paymentDestination ?? 'supplier') == 'supplier';

    if (isReceipt && customerId == null) return;
    if (isSupplierPayment && supplierId == null) return;
    if (!isReceipt && !isSupplierPayment) return;

    state = state.copyWith(
      isLoadingOpenInvoices: true,
      clearOpenInvoices: true,
      clearManualAllocations: true,
      clearError: true,
    );

    try {
      final invoices = await loadVoucherOpenInvoices(
        session: session,
        state: state,
        repository: ref.read(voucherRepositoryProvider),
      );
      state = state.copyWith(
        openInvoices: invoices,
        isLoadingOpenInvoices: false,
      );
    } catch (e) {
      state = state.copyWith(
        isLoadingOpenInvoices: false,
        errorCode: openInvoiceLoadErrorCode(e),
      );
    }
  }

  void setDate(DateTime date) {
    _patchForm((form) => form.copyWith(date: date));
  }

  void setAmount(Decimal amount) {
    _patchForm((form) => form.copyWith(amount: amount));
  }

  void setPaymentMethod(PaymentMethod method) {
    _patchForm((form) => form.copyWith(paymentMethod: method));
  }

  void setCashAccountId(String? accountId) {
    _patchForm(
      (form) => form.copyWith(
        cashAccountId: accountId ?? '',
        accountId: form.accountId == accountId ? null : form.accountId,
      ),
    );
  }

  void setReference(String? reference) {
    _patchForm((form) => form.copyWith(referenceNo: reference));
  }

  void setNotes(String? notes) {
    _patchForm((form) => form.copyWith(notes: notes));
  }

  void setAllocationMode(String mode) {
    _patchForm(
      (form) => form.copyWith(allocationMode: mode, allocations: const []),
    );
    state = state.copyWith(clearManualAllocations: true);
  }

  void setPaymentDestination(String destination) {
    final normalized = destination == 'account' ? 'account' : 'supplier';
    _patchForm(
      (form) => form.copyWith(
        paymentDestination: normalized,
        supplierId: normalized == 'account' ? null : form.supplierId,
        accountId: normalized == 'supplier' ? null : form.accountId,
        allocationMode: normalized == 'account'
            ? null
            : (form.allocationMode ?? 'fifo'),
        allocations: const [],
      ),
    );
    state = state.copyWith(
      clearOpenInvoices: true,
      clearManualAllocations: true,
      clearSupplier: normalized == 'account',
      partySearchResults: const [],
    );
    if (normalized == 'supplier' && state.selectedSupplier != null) {
      loadOpenInvoices();
    }
  }

  void setAccountId(String? accountId) {
    _patchForm((form) => form.copyWith(accountId: accountId));
  }

  void updateManualAllocation(String invoiceId, Decimal? amount) {
    final updated = Map<String, Decimal?>.from(state.manualAllocationAmounts);
    if (amount == null || amount <= Decimal.zero) {
      updated.remove(invoiceId);
    } else {
      updated[invoiceId] = amount;
    }
    state = state.copyWith(
      manualAllocationAmounts: updated,
      clearValidation: true,
    );
  }

  VoucherFormState buildSafeForm() => buildSafeVoucherFormState(state);

  Future<String?> submit() async {
    final session = _session;
    if (session == null) return FinanceException.unknown;

    final form = buildSafeForm();
    final validation = const VoucherValidator()
        .validate(form)
        .merge(_allocationValidation(form));
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
          form,
          _idempotency!.key,
        ),
        VoucherType.payment => await repo.recordPaymentVoucher(
          session,
          form,
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

  void _patchForm(VoucherFormState Function(VoucherFormState) patch) {
    state = state.copyWith(
      form: patch(state.form),
      clearError: true,
      clearValidation: true,
    );
  }

  VoucherFormState _emptyForm(VoucherType type) {
    return VoucherFormState(
      type: type,
      date: DateTime.now(),
      amount: Decimal.zero,
      paymentMethod: PaymentMethod.cash,
      cashAccountId: '',
      allocationMode: null,
      paymentDestination: type == VoucherType.payment ? 'account' : null,
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

/// Parses user-entered amount text for voucher forms.
Decimal? parseVoucherAmountInput(String value) => tryParseDecimal(value);

List<ChartAccount> _sortVoucherSourceAccounts(List<ChartAccount> accounts) {
  return List<ChartAccount>.from(accounts)..sort((a, b) {
    final aRank = a.code == '1101'
        ? 0
        : a.code == '1102'
        ? 1
        : 2;
    final bRank = b.code == '1101'
        ? 0
        : b.code == '1102'
        ? 1
        : 2;
    if (aRank != bRank) return aRank.compareTo(bRank);
    return a.code.compareTo(b.code);
  });
}

String? _defaultVoucherSourceAccountId(List<ChartAccount> accounts) {
  for (final account in accounts) {
    if (account.code == '1101') return account.id;
  }
  return accounts.isEmpty ? null : accounts.first.id;
}
