import 'package:decimal/decimal.dart';

import '../../accounting/domain/chart_account.dart';
import '../../customers/domain/customer.dart';
import '../../suppliers/domain/supplier.dart';
import '../data/voucher_rpc_mapper.dart';
import '../domain/voucher_form_state.dart';
import '../domain/voucher_type.dart';

class VoucherFormUiState {
  const VoucherFormUiState({
    required this.voucherType,
    required this.form,
    this.isSubmitting = false,
    this.isLoadingMeta = false,
    this.canLoadCashAccounts = false,
    this.cashBankAccounts = const [],
    this.postingAccounts = const [],
    this.isSearchingParty = false,
    this.partySearchResults = const [],
    this.selectedCustomer,
    this.selectedSupplier,
    this.openInvoices = const [],
    this.isLoadingOpenInvoices = false,
    this.manualAllocationAmounts = const {},
    this.errorCode,
    this.validationCodes = const [],
    this.lastSavedVoucherId,
  });

  final VoucherType voucherType;
  final VoucherFormState form;
  final bool isSubmitting;
  final bool isLoadingMeta;
  final bool canLoadCashAccounts;
  final List<ChartAccount> cashBankAccounts;
  final List<ChartAccount> postingAccounts;
  final bool isSearchingParty;
  final List<Object> partySearchResults;
  final Customer? selectedCustomer;
  final Supplier? selectedSupplier;
  final List<OpenInvoiceAllocationOption> openInvoices;
  final bool isLoadingOpenInvoices;
  final Map<String, Decimal?> manualAllocationAmounts;
  final String? errorCode;
  final List<String> validationCodes;
  final String? lastSavedVoucherId;

  bool get hasValidationErrors => validationCodes.isNotEmpty;

  bool get showAllocationPanel {
    return switch (voucherType) {
      VoucherType.receipt => selectedCustomer != null,
      VoucherType.payment =>
        (form.paymentDestination ?? 'supplier') == 'supplier' &&
            selectedSupplier != null,
    };
  }

  VoucherFormUiState copyWith({
    VoucherType? voucherType,
    VoucherFormState? form,
    bool? isSubmitting,
    bool? isLoadingMeta,
    bool? canLoadCashAccounts,
    List<ChartAccount>? cashBankAccounts,
    List<ChartAccount>? postingAccounts,
    bool? isSearchingParty,
    List<Object>? partySearchResults,
    Customer? selectedCustomer,
    Supplier? selectedSupplier,
    List<OpenInvoiceAllocationOption>? openInvoices,
    bool? isLoadingOpenInvoices,
    Map<String, Decimal?>? manualAllocationAmounts,
    String? errorCode,
    List<String>? validationCodes,
    String? lastSavedVoucherId,
    bool clearError = false,
    bool clearValidation = false,
    bool clearCustomer = false,
    bool clearSupplier = false,
    bool clearOpenInvoices = false,
    bool clearManualAllocations = false,
  }) {
    return VoucherFormUiState(
      voucherType: voucherType ?? this.voucherType,
      form: form ?? this.form,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isLoadingMeta: isLoadingMeta ?? this.isLoadingMeta,
      canLoadCashAccounts: canLoadCashAccounts ?? this.canLoadCashAccounts,
      cashBankAccounts: cashBankAccounts ?? this.cashBankAccounts,
      postingAccounts: postingAccounts ?? this.postingAccounts,
      isSearchingParty: isSearchingParty ?? this.isSearchingParty,
      partySearchResults: partySearchResults ?? this.partySearchResults,
      selectedCustomer: clearCustomer
          ? null
          : (selectedCustomer ?? this.selectedCustomer),
      selectedSupplier: clearSupplier
          ? null
          : (selectedSupplier ?? this.selectedSupplier),
      openInvoices: clearOpenInvoices
          ? const []
          : (openInvoices ?? this.openInvoices),
      isLoadingOpenInvoices:
          isLoadingOpenInvoices ?? this.isLoadingOpenInvoices,
      manualAllocationAmounts: clearManualAllocations
          ? const {}
          : (manualAllocationAmounts ?? this.manualAllocationAmounts),
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      validationCodes: clearValidation
          ? const []
          : (validationCodes ?? this.validationCodes),
      lastSavedVoucherId: lastSavedVoucherId ?? this.lastSavedVoucherId,
    );
  }
}
