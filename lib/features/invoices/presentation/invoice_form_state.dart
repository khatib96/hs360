import 'package:decimal/decimal.dart';

import '../../customers/domain/customer.dart';
import '../../accounting/domain/chart_account.dart';
import '../../inventory/domain/warehouse.dart';
import '../../products/domain/product.dart';
import '../../suppliers/domain/supplier.dart';
import '../domain/invoice_draft.dart';
import '../domain/invoice_detail.dart';
import '../domain/invoice_form_state.dart' as domain;
import '../domain/invoice_payment_terms.dart';
import '../domain/invoice_type.dart';
import '../domain/return_invoice_draft.dart';
import '../domain/returnable_invoice_line.dart';
import 'invoice_form_draft_builder.dart';

class InvoiceFormLineUiState {
  InvoiceFormLineUiState({
    this.product,
    Decimal? qty,
    Decimal? unitPrice,
    Decimal? discountPct,
    this.productUnitId,
    this.units = const [],
  }) : qty = qty ?? Decimal.one,
       unitPrice = unitPrice ?? Decimal.zero,
       discountPct = discountPct ?? Decimal.zero;

  final Product? product;
  final Decimal qty;
  final Decimal unitPrice;
  final Decimal discountPct;
  final String? productUnitId;
  final List<InvoiceDraftUnitInput> units;

  InvoiceFormLineUiState copyWith({
    Product? product,
    bool clearProduct = false,
    Decimal? qty,
    Decimal? unitPrice,
    Decimal? discountPct,
    String? productUnitId,
    bool clearProductUnitId = false,
    List<InvoiceDraftUnitInput>? units,
  }) {
    return InvoiceFormLineUiState(
      product: clearProduct ? null : (product ?? this.product),
      qty: qty ?? this.qty,
      unitPrice: unitPrice ?? this.unitPrice,
      discountPct: discountPct ?? this.discountPct,
      productUnitId: clearProductUnitId
          ? null
          : (productUnitId ?? this.productUnitId),
      units: units ?? this.units,
    );
  }
}

class InvoiceFormUiState {
  const InvoiceFormUiState({
    required this.invoiceType,
    this.invoiceId,
    this.form,
    this.returnDraft,
    this.isSubmitting = false,
    this.isSavingDraft = false,
    this.isLoadingMeta = false,
    this.isLoadingDraft = false,
    this.errorCode,
    this.errorDetail,
    this.validationCodes = const [],
    this.paymentTerms = InvoicePaymentTerms.cash,
    this.productFocusRequestIndex,
    this.lastSavedInvoiceId,
    this.serializedByProductId = const {},
    this.returnableQtyByLineId = const {},
    this.serializedReturnLineIds = const {},
    this.warehouses = const [],
    this.cashBankAccounts = const [],
    this.lines = const [],
    this.customerId,
    this.supplierId,
    this.cashAccountId,
    this.selectedCustomer,
    this.selectedSupplier,
    this.warehouseId,
    this.date,
    this.dueDate,
    this.notes = '',
    this.productSearchResults = const [],
    this.isSearchingProducts = false,
    this.partySearchResults = const [],
    this.isSearchingParty = false,
    this.originalDetail,
    this.returnableLines = const [],
    this.estimateTaxRate,
    this.estimateTaxRateId,
    this.taxEstimateAvailable = false,
    this.decimalPlaces = 3,
  });

  final InvoiceType invoiceType;
  final String? invoiceId;
  final domain.InvoiceFormState? form;
  final ReturnInvoiceDraft? returnDraft;
  final bool isSubmitting;
  final bool isSavingDraft;
  final bool isLoadingMeta;
  final bool isLoadingDraft;
  final String? errorCode;
  final String? errorDetail;
  final List<String> validationCodes;
  final InvoicePaymentTerms paymentTerms;
  final int? productFocusRequestIndex;
  final String? lastSavedInvoiceId;
  final Map<String, bool> serializedByProductId;
  final Map<String, Decimal> returnableQtyByLineId;
  final Set<String> serializedReturnLineIds;
  final List<Warehouse> warehouses;
  final List<ChartAccount> cashBankAccounts;
  final List<InvoiceFormLineUiState> lines;
  final String? customerId;
  final String? supplierId;
  final String? cashAccountId;
  final Customer? selectedCustomer;
  final Supplier? selectedSupplier;
  final String? warehouseId;
  final DateTime? date;
  final DateTime? dueDate;
  final String notes;
  final List<Product> productSearchResults;
  final bool isSearchingProducts;
  final List<Object> partySearchResults;
  final bool isSearchingParty;
  final InvoiceDetail? originalDetail;
  final List<ReturnableInvoiceLine> returnableLines;
  final Decimal? estimateTaxRate;
  final String? estimateTaxRateId;
  final bool taxEstimateAvailable;
  final int decimalPlaces;

  bool get hasValidationErrors => validationCodes.isNotEmpty;

  InvoiceEstimateTotals? get computedEstimateTotals {
    return computeEstimateTotals(
      lines: lines,
      decimalPlaces: decimalPlaces,
      taxEnabled: taxEstimateAvailable,
      effectiveTaxRate: estimateTaxRate,
      effectiveTaxRateId: estimateTaxRateId,
    );
  }

  InvoiceFormUiState copyWith({
    InvoiceType? invoiceType,
    String? invoiceId,
    domain.InvoiceFormState? form,
    ReturnInvoiceDraft? returnDraft,
    bool? isSubmitting,
    bool? isSavingDraft,
    bool? isLoadingMeta,
    bool? isLoadingDraft,
    String? errorCode,
    String? errorDetail,
    List<String>? validationCodes,
    InvoicePaymentTerms? paymentTerms,
    int? productFocusRequestIndex,
    bool clearProductFocusRequest = false,
    String? lastSavedInvoiceId,
    Map<String, bool>? serializedByProductId,
    Map<String, Decimal>? returnableQtyByLineId,
    Set<String>? serializedReturnLineIds,
    List<Warehouse>? warehouses,
    List<ChartAccount>? cashBankAccounts,
    List<InvoiceFormLineUiState>? lines,
    String? customerId,
    String? supplierId,
    String? cashAccountId,
    bool clearCashAccount = false,
    Customer? selectedCustomer,
    Supplier? selectedSupplier,
    String? warehouseId,
    bool clearWarehouseId = false,
    DateTime? date,
    DateTime? dueDate,
    bool clearDueDate = false,
    String? notes,
    List<Product>? productSearchResults,
    bool? isSearchingProducts,
    List<Object>? partySearchResults,
    bool? isSearchingParty,
    InvoiceDetail? originalDetail,
    List<ReturnableInvoiceLine>? returnableLines,
    Decimal? estimateTaxRate,
    String? estimateTaxRateId,
    bool? taxEstimateAvailable,
    int? decimalPlaces,
    bool clearError = false,
    bool clearValidation = false,
    bool clearCustomer = false,
    bool clearSupplier = false,
  }) {
    return InvoiceFormUiState(
      invoiceType: invoiceType ?? this.invoiceType,
      invoiceId: invoiceId ?? this.invoiceId,
      form: form ?? this.form,
      returnDraft: returnDraft ?? this.returnDraft,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSavingDraft: isSavingDraft ?? this.isSavingDraft,
      isLoadingMeta: isLoadingMeta ?? this.isLoadingMeta,
      isLoadingDraft: isLoadingDraft ?? this.isLoadingDraft,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      errorDetail: clearError ? null : (errorDetail ?? this.errorDetail),
      validationCodes: clearValidation
          ? const []
          : (validationCodes ?? this.validationCodes),
      paymentTerms: paymentTerms ?? this.paymentTerms,
      productFocusRequestIndex: clearProductFocusRequest
          ? null
          : (productFocusRequestIndex ?? this.productFocusRequestIndex),
      lastSavedInvoiceId: lastSavedInvoiceId ?? this.lastSavedInvoiceId,
      serializedByProductId:
          serializedByProductId ?? this.serializedByProductId,
      returnableQtyByLineId:
          returnableQtyByLineId ?? this.returnableQtyByLineId,
      serializedReturnLineIds:
          serializedReturnLineIds ?? this.serializedReturnLineIds,
      warehouses: warehouses ?? this.warehouses,
      cashBankAccounts: cashBankAccounts ?? this.cashBankAccounts,
      lines: lines ?? this.lines,
      customerId: clearCustomer ? null : (customerId ?? this.customerId),
      supplierId: clearSupplier ? null : (supplierId ?? this.supplierId),
      cashAccountId: clearCashAccount
          ? null
          : (cashAccountId ?? this.cashAccountId),
      selectedCustomer: clearCustomer
          ? null
          : (selectedCustomer ?? this.selectedCustomer),
      selectedSupplier: clearSupplier
          ? null
          : (selectedSupplier ?? this.selectedSupplier),
      warehouseId: clearWarehouseId ? null : (warehouseId ?? this.warehouseId),
      date: date ?? this.date,
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
      notes: notes ?? this.notes,
      productSearchResults: productSearchResults ?? this.productSearchResults,
      isSearchingProducts: isSearchingProducts ?? this.isSearchingProducts,
      partySearchResults: partySearchResults ?? this.partySearchResults,
      isSearchingParty: isSearchingParty ?? this.isSearchingParty,
      originalDetail: originalDetail ?? this.originalDetail,
      returnableLines: returnableLines ?? this.returnableLines,
      estimateTaxRate: estimateTaxRate ?? this.estimateTaxRate,
      estimateTaxRateId: estimateTaxRateId ?? this.estimateTaxRateId,
      taxEstimateAvailable: taxEstimateAvailable ?? this.taxEstimateAvailable,
      decimalPlaces: decimalPlaces ?? this.decimalPlaces,
    );
  }

  static InvoiceFormUiState initial(InvoiceType type) {
    if (type.isReturn) {
      return InvoiceFormUiState(
        invoiceType: type,
        returnDraft: ReturnInvoiceDraft(
          originalInvoiceId: '',
          warehouseId: '',
          date: DateTime.now(),
          reason: '',
          lines: const [],
        ),
        date: DateTime.now(),
        lines: [InvoiceFormLineUiState()],
      );
    }
    return InvoiceFormUiState(
      invoiceType: type,
      form: emptyForm(type),
      date: DateTime.now(),
      lines: [InvoiceFormLineUiState()],
    );
  }

  static domain.InvoiceFormState emptyForm(InvoiceType type) {
    return domain.InvoiceFormState(
      draft: InvoiceDraft(
        type: type,
        warehouseId: '',
        date: DateTime.now(),
        lines: const [],
      ),
    );
  }
}
