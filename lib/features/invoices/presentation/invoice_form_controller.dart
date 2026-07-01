import 'package:decimal/decimal.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/finance_exception.dart';
import '../../../domain/validators/purchase_invoice_validator.dart';
import '../../../domain/validators/return_invoice_validator.dart';
import '../../../domain/validators/sales_invoice_validator.dart';
import '../../../domain/validators/validation_result.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../accounting/data/chart_account_repository.dart';
import '../../customers/domain/customer.dart';
import '../../customers/data/customer_repository.dart';
import '../../customers/domain/customer_filters.dart';
import '../../finance_shared/domain/cash_bank_posting_accounts.dart';
import '../../finance_shared/domain/finance_idempotency.dart';
import '../../finance_shared/domain/finance_permissions.dart';
import '../../inventory/data/warehouse_repository.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product.dart';
import '../../products/domain/product_type.dart';
import '../../products/domain/unit_of_measure.dart';
import '../../suppliers/domain/supplier.dart';
import '../../products/domain/product_permissions.dart';
import '../../settings/data/tax_settings_repository.dart';
import '../../suppliers/data/supplier_repository.dart';
import '../../suppliers/domain/supplier_filters.dart';
import '../data/invoice_repository.dart';
import '../domain/invoice_detail.dart';
import '../domain/invoice_draft.dart';
import '../domain/invoice_form_state.dart' as domain;
import '../domain/invoice_payment_terms.dart';
import '../domain/invoice_type.dart';
import '../../products/domain/product_filters.dart';
import '../domain/return_invoice_draft.dart';
import '../domain/returnable_invoice_line.dart';
import 'invoice_form_draft_builder.dart';
import 'invoice_form_mapper.dart';

import 'invoice_form_state.dart';

part 'invoice_form_controller.g.dart';

@riverpod
class InvoiceFormController extends _$InvoiceFormController {
  FinanceIdempotencySession? _idempotency;

  @override
  InvoiceFormUiState build(InvoiceType invoiceType) {
    Future.microtask(loadMeta);
    return InvoiceFormUiState.initial(invoiceType);
  }

  AppSession? get _session => ref.read(authControllerProvider).valueOrNull;

  Future<void> loadMeta() async {
    final session = _session;
    if (session == null) return;

    state = state.copyWith(isLoadingMeta: true, clearError: true);
    try {
      final warehouses = await ref
          .read(warehouseRepositoryProvider)
          .fetchWarehouses(activeOnly: true);
      var cashBankAccounts = state.cashBankAccounts;
      if (canLoadCashBankPostingAccounts(session)) {
        try {
          final accounts = await ref
              .read(chartAccountRepositoryProvider)
              .fetchChartAccounts(session, isActive: true);
          cashBankAccounts = filterInvoiceCashBankAccounts(accounts);
        } catch (_) {}
      }

      Decimal? estimateTaxRate;
      String? estimateTaxRateId;
      var taxEstimateAvailable = false;
      if (!state.invoiceType.isReturn && canViewTaxSettings(session)) {
        try {
          final rates = await ref
              .read(taxSettingsRepositoryProvider)
              .listTaxRates(session, activeOnly: true);
          final active = rates.where((r) => r.isActive).toList();
          if (active.isNotEmpty) {
            estimateTaxRate = active.first.rate;
            estimateTaxRateId = active.first.id;
            taxEstimateAvailable = estimateTaxRate > Decimal.zero;
          }
        } catch (_) {}
      }

      state = state.copyWith(
        warehouses: warehouses,
        cashBankAccounts: cashBankAccounts,
        isLoadingMeta: false,
        cashAccountId: state.cashAccountId ?? cashBankAccounts.firstOrNull?.id,
        estimateTaxRate: estimateTaxRate,
        estimateTaxRateId: estimateTaxRateId,
        taxEstimateAvailable: taxEstimateAvailable,
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

  Future<void> loadPurchaseDraft(String invoiceId) async {
    final session = _session;
    if (session == null || state.invoiceType != InvoiceType.purchase) return;
    if (!canEditInvoiceDraft(session)) {
      state = state.copyWith(errorCode: FinanceException.permissionDenied);
      return;
    }

    state = state.copyWith(isLoadingDraft: true, clearError: true);
    try {
      final detail = await ref
          .read(invoiceRepositoryProvider)
          .fetchInvoiceDetail(invoiceId, session, type: InvoiceType.purchase);
      if (!detail.status.isDraft) {
        state = state.copyWith(
          isLoadingDraft: false,
          errorCode: FinanceException.notAvailable,
        );
        return;
      }

      final form = purchaseDetailToInvoiceFormState(detail);
      final productsById = <String, Product>{};
      for (final line in detail.lines) {
        productsById[line.productId] = Product(
          id: line.productId,
          tenantId: session.tenantId,
          sku: line.description ?? line.productId,
          nameAr: line.description ?? '',
          nameEn: line.description ?? '',
          groupId: '',
          productType: ProductType.saleOnly,
          canBeSold: true,
          canBeRented: false,
          unitPrimary: UnitOfMeasure.piece,
          conversionFactor: Decimal.one,
          salePrice: line.unitPrice,
          isSerialized:
              line.productUnitId != null || line.productUnitIds.isNotEmpty,
          trackableForMaintenance: false,
          isActive: true,
        );
      }

      state = state.copyWith(
        isLoadingDraft: false,
        invoiceId: detail.id,
        form: form,
        supplierId: detail.supplier?.supplierId,
        warehouseId: detail.warehouse?.id,
        date: detail.date,
        dueDate: detail.dueDate,
        notes: detail.notes ?? '',
        lines: linesFromProducts(form.draft.lines, productsById),
        serializedByProductId: serializedByProductIdFromLines(
          linesFromProducts(form.draft.lines, productsById),
        ),
      );
    } on FinanceException catch (e) {
      state = state.copyWith(isLoadingDraft: false, errorCode: e.code);
    } catch (_) {
      state = state.copyWith(
        isLoadingDraft: false,
        errorCode: FinanceException.unknown,
      );
    }
  }

  Future<void> initializeReturn({
    required String originalInvoiceId,
    required InvoiceDetail originalDetail,
    required List<ReturnableInvoiceLine> returnableLines,
  }) async {
    final returnType = originalDetail.type == InvoiceType.sales
        ? InvoiceType.salesReturn
        : InvoiceType.purchaseReturn;

    final effectiveReturnableLines = returnableLines.isNotEmpty
        ? returnableLines
        : _returnableLinesFromDetail(originalDetail);
    state = state.copyWith(
      invoiceType: returnType,
      originalDetail: originalDetail,
      returnableLines: effectiveReturnableLines,
      returnableQtyByLineId: _returnableQtyByLineId(effectiveReturnableLines),
      serializedReturnLineIds: _serializedReturnLineIds(
        effectiveReturnableLines,
      ),
      warehouseId: originalDetail.warehouse?.id,
      date: DateTime.now(),
      returnDraft: ReturnInvoiceDraft(
        originalInvoiceId: originalInvoiceId,
        warehouseId: originalDetail.warehouse?.id ?? '',
        date: DateTime.now(),
        reason: '',
        lines: _defaultReturnDraftLines(effectiveReturnableLines),
      ),
    );
  }

  List<ReturnableInvoiceLine> _returnableLinesFromDetail(InvoiceDetail detail) {
    return [
      for (final line in detail.lines)
        if (line.qty > Decimal.zero)
          ReturnableInvoiceLine(
            originalLineId: line.id,
            lineOrder: line.lineOrder,
            productId: line.productId,
            productUnitId:
                line.productUnitId ??
                (line.productUnitIds.length == 1
                    ? line.productUnitIds.first
                    : null),
            originalQty: line.qty,
            returnedQty: Decimal.zero,
            returnableQty: line.qty,
            unitPrice: line.unitPrice,
            discountPct: line.discountPct,
            costPrice: line.costPrice ?? Decimal.zero,
            isSerialized:
                line.productUnitId != null || line.productUnitIds.isNotEmpty,
          ),
    ];
  }

  Map<String, Decimal> _returnableQtyByLineId(
    List<ReturnableInvoiceLine> lines,
  ) {
    return {for (final line in lines) line.originalLineId: line.returnableQty};
  }

  Set<String> _serializedReturnLineIds(List<ReturnableInvoiceLine> lines) {
    return lines
        .where((line) => line.isSerialized)
        .map((line) => line.originalLineId)
        .toSet();
  }

  List<ReturnInvoiceDraftLine> _defaultReturnDraftLines(
    List<ReturnableInvoiceLine> lines,
  ) {
    return [
      for (final line in lines)
        if (line.returnableQty > Decimal.zero)
          ReturnInvoiceDraftLine(
            lineOrder: line.lineOrder,
            originalInvoiceLineId: line.originalLineId,
            qty: line.returnableQty,
            productUnitId: line.isSerialized ? line.productUnitId : null,
          ),
    ];
  }

  /// Repairs a linked return form if it was opened with no selected lines.
  ///
  /// This is intentionally conservative: it only applies to returns tied to an
  /// original invoice and only auto-selects still-returnable positive
  /// quantities. It protects the old linked-return screen from submitting an
  /// empty draft when the returnable-lines RPC returns late/empty.
  void ensureLinkedReturnLinesSelected() {
    final draft = state.returnDraft;
    if (draft == null || draft.originalInvoiceId.trim().isEmpty) return;
    if (draft.lines.isNotEmpty && state.returnableLines.isNotEmpty) return;

    final effectiveReturnableLines = state.returnableLines.isNotEmpty
        ? state.returnableLines
        : state.originalDetail == null
        ? const <ReturnableInvoiceLine>[]
        : _returnableLinesFromDetail(state.originalDetail!);
    if (effectiveReturnableLines.isEmpty) return;

    state = state.copyWith(
      returnableLines: effectiveReturnableLines,
      returnableQtyByLineId: _returnableQtyByLineId(effectiveReturnableLines),
      serializedReturnLineIds: _serializedReturnLineIds(
        effectiveReturnableLines,
      ),
      returnDraft: ReturnInvoiceDraft(
        originalInvoiceId: draft.originalInvoiceId,
        warehouseId: draft.warehouseId,
        date: draft.date,
        reason: draft.reason,
        notes: draft.notes,
        lines: draft.lines.isNotEmpty
            ? draft.lines
            : _defaultReturnDraftLines(effectiveReturnableLines),
      ),
    );
  }

  void setWarehouseId(String? warehouseId) {
    state = state.copyWith(
      warehouseId: warehouseId,
      clearWarehouseId: warehouseId == null,
      clearValidation: true,
    );
    _syncReturnDraftWarehouse(warehouseId);
  }

  void setDate(DateTime date) {
    state = state.copyWith(date: date, clearValidation: true);
    _syncReturnDraftDate(date);
  }

  void setDueDate(DateTime? dueDate) {
    state = state.copyWith(
      dueDate: dueDate,
      clearDueDate: dueDate == null,
      clearValidation: true,
    );
  }

  /// UI-only payment-terms selection. Switching to cash clears the due date so
  /// the (optional) due date is never silently posted for an immediate sale.
  /// No payment is posted here: the backend record RPCs do not accept a
  /// payment method, so cash simply records the sale and collection happens
  /// later from vouchers.
  void setPaymentTerms(InvoicePaymentTerms terms) {
    state = state.copyWith(
      paymentTerms: terms,
      clearDueDate: terms == InvoicePaymentTerms.cash,
      clearCashAccount: terms == InvoicePaymentTerms.credit,
      clearValidation: true,
    );
  }

  void setCashAccountId(String? accountId) {
    state = state.copyWith(
      cashAccountId: accountId,
      clearCashAccount: accountId == null,
      clearValidation: true,
    );
  }

  void setNotes(String notes) {
    state = state.copyWith(notes: notes, clearValidation: true);
    final draft = state.returnDraft;
    if (draft != null) {
      state = state.copyWith(
        returnDraft: ReturnInvoiceDraft(
          originalInvoiceId: draft.originalInvoiceId,
          warehouseId: draft.warehouseId,
          date: draft.date,
          reason: draft.reason,
          notes: notes,
          lines: draft.lines,
        ),
      );
    }
  }

  void setReturnReason(String reason) {
    final draft = state.returnDraft;
    if (draft == null) return;
    state = state.copyWith(
      returnDraft: ReturnInvoiceDraft(
        originalInvoiceId: draft.originalInvoiceId,
        warehouseId: draft.warehouseId,
        date: draft.date,
        reason: reason,
        notes: draft.notes,
        lines: draft.lines,
      ),
      clearValidation: true,
    );
  }

  void setCustomer(Customer customer) {
    state = state.copyWith(
      customerId: customer.id,
      selectedCustomer: customer,
      partySearchResults: const [],
      clearValidation: true,
    );
  }

  void setSupplier(Supplier supplier) {
    state = state.copyWith(
      supplierId: supplier.id,
      selectedSupplier: supplier,
      partySearchResults: const [],
      clearValidation: true,
    );
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
      if (state.invoiceType.isSalesDirection) {
        final customers = await ref
            .read(customerRepositoryProvider)
            .fetchCustomers(
              session,
              CustomerFilters(search: trimmed, isActive: true),
              limit: 20,
            );
        state = state.copyWith(
          partySearchResults: customers,
          isSearchingParty: false,
        );
      } else if (state.invoiceType.isPurchaseDirection) {
        final suppliers = await ref
            .read(supplierRepositoryProvider)
            .fetchSuppliers(
              session,
              SupplierFilters(search: trimmed, isActive: true),
              limit: 20,
            );
        state = state.copyWith(
          partySearchResults: suppliers,
          isSearchingParty: false,
        );
      }
    } catch (_) {
      state = state.copyWith(
        partySearchResults: const [],
        isSearchingParty: false,
      );
    }
  }

  Future<void> searchProducts(String query) async {
    final session = _session;
    if (session == null || !canViewProductsList(session)) {
      state = state.copyWith(productSearchResults: const []);
      return;
    }
    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(productSearchResults: const []);
      return;
    }

    state = state.copyWith(isSearchingProducts: true);
    try {
      final products = await ref
          .read(productRepositoryProvider)
          .fetchProducts(
            ProductFilters(search: trimmed, isActive: true),
            session,
          );
      state = state.copyWith(
        productSearchResults: products,
        isSearchingProducts: false,
      );
    } catch (_) {
      state = state.copyWith(
        productSearchResults: const [],
        isSearchingProducts: false,
      );
    }
  }

  void addLine() {
    state = state.copyWith(
      lines: [...state.lines, InvoiceFormLineUiState()],
      clearValidation: true,
    );
  }

  /// Adds a blank line and requests keyboard focus on its product cell.
  void addLineAndFocusProduct() {
    final nextIndex = state.lines.length;
    state = state.copyWith(
      lines: [...state.lines, InvoiceFormLineUiState()],
      productFocusRequestIndex: nextIndex,
      clearValidation: true,
    );
  }

  void clearProductFocusRequest() {
    if (state.productFocusRequestIndex == null) return;
    state = state.copyWith(clearProductFocusRequest: true);
  }

  void removeLine(int index) {
    if (index < 0 || index >= state.lines.length) return;
    final lines = [...state.lines]..removeAt(index);
    state = state.copyWith(lines: lines, clearValidation: true);
  }

  void selectProduct(int index, Product product, {bool advanceLine = false}) {
    if (index < 0 || index >= state.lines.length) return;
    final lines = [...state.lines];
    lines[index] = lines[index].copyWith(
      product: product,
      unitPrice: state.invoiceType.isSalesDirection
          ? product.salePrice
          : (product.lastPurchaseCost ?? product.avgCost ?? Decimal.zero),
      units: product.isSerialized && state.invoiceType == InvoiceType.purchase
          ? [const InvoiceDraftUnitInput()]
          : const [],
    );
    final serialized = Map<String, bool>.from(state.serializedByProductId);
    serialized[product.id] = product.isSerialized;

    final isLastLine = index == lines.length - 1;
    if (advanceLine && isLastLine) {
      lines.add(InvoiceFormLineUiState());
      state = state.copyWith(
        lines: lines,
        productSearchResults: const [],
        serializedByProductId: serialized,
        productFocusRequestIndex: lines.length - 1,
        clearValidation: true,
      );
      return;
    }

    state = state.copyWith(
      lines: lines,
      productSearchResults: const [],
      serializedByProductId: serialized,
      clearValidation: true,
    );
  }

  void setLineQty(int index, Decimal qty) {
    if (index < 0 || index >= state.lines.length) return;
    final lines = [...state.lines];
    final line = lines[index];
    var units = line.units;
    if (line.product?.isSerialized == true &&
        state.invoiceType == InvoiceType.purchase) {
      final count = qty.toBigInt().toInt();
      units = List.generate(
        count > 0 ? count : 0,
        (_) => const InvoiceDraftUnitInput(),
      );
    }
    lines[index] = line.copyWith(qty: qty, units: units);
    state = state.copyWith(lines: lines, clearValidation: true);
  }

  void setLineUnitPrice(int index, Decimal unitPrice) {
    if (index < 0 || index >= state.lines.length) return;
    final lines = [...state.lines];
    lines[index] = lines[index].copyWith(unitPrice: unitPrice);
    state = state.copyWith(lines: lines, clearValidation: true);
  }

  void setLineDiscountPct(int index, Decimal discountPct) {
    if (index < 0 || index >= state.lines.length) return;
    final lines = [...state.lines];
    lines[index] = lines[index].copyWith(discountPct: discountPct);
    state = state.copyWith(lines: lines, clearValidation: true);
  }

  void setLineProductUnitId(int index, String? productUnitId) {
    if (index < 0 || index >= state.lines.length) return;
    final lines = [...state.lines];
    lines[index] = lines[index].copyWith(
      productUnitId: productUnitId,
      clearProductUnitId: productUnitId == null,
    );
    state = state.copyWith(lines: lines, clearValidation: true);
  }

  void setPurchaseUnitSerial(int lineIndex, int unitIndex, String? serial) {
    if (lineIndex < 0 || lineIndex >= state.lines.length) return;
    final line = state.lines[lineIndex];
    if (unitIndex < 0 || unitIndex >= line.units.length) return;
    final units = [...line.units];
    units[unitIndex] = InvoiceDraftUnitInput(serialNumber: serial);
    final lines = [...state.lines];
    lines[lineIndex] = line.copyWith(units: units);
    state = state.copyWith(lines: lines, clearValidation: true);
  }

  void setReturnLineQty(String originalLineId, Decimal qty) {
    final draft = state.returnDraft;
    if (draft == null) return;
    final existing = [...draft.lines];
    final index = existing.indexWhere(
      (line) => line.originalInvoiceLineId == originalLineId,
    );
    final returnable = state.returnableQtyByLineId[originalLineId];
    if (returnable == null || qty > returnable || qty <= Decimal.zero) {
      if (index >= 0) existing.removeAt(index);
    } else {
      final returnableLine = state.returnableLines.firstWhere(
        (line) => line.originalLineId == originalLineId,
      );
      final entry = ReturnInvoiceDraftLine(
        lineOrder: index >= 0 ? existing[index].lineOrder : existing.length + 1,
        originalInvoiceLineId: originalLineId,
        qty: qty,
        productUnitId: returnableLine.isSerialized
            ? returnableLine.productUnitId
            : null,
      );
      if (index >= 0) {
        existing[index] = entry;
      } else {
        existing.add(entry);
      }
    }
    state = state.copyWith(
      returnDraft: ReturnInvoiceDraft(
        originalInvoiceId: draft.originalInvoiceId,
        warehouseId: draft.warehouseId,
        date: draft.date,
        reason: draft.reason,
        notes: draft.notes,
        lines: existing,
      ),
      clearValidation: true,
    );
  }

  domain.InvoiceFormState buildSafeForm() {
    return buildSafeInvoiceFormState(
      type: state.invoiceType,
      invoiceId: state.invoiceId,
      customerId: state.customerId,
      supplierId: state.supplierId,
      cashAccountId: state.cashAccountId,
      warehouseId: state.warehouseId ?? '',
      date: state.date ?? DateTime.now(),
      dueDate: state.dueDate,
      notes: state.notes,
      lines: state.lines,
    );
  }

  Future<String?> saveDraft() async {
    final session = _session;
    if (session == null) return FinanceException.unknown;
    if (!canEditInvoiceDraft(session)) {
      return FinanceException.permissionDenied;
    }
    if (state.invoiceType != InvoiceType.purchase) {
      return FinanceException.notAvailable;
    }

    final form = buildSafeForm();
    final validation = const PurchaseInvoiceValidator().validate(
      form,
      serializedByProductId: serializedByProductIdFromLines(state.lines),
    );
    if (!validation.isValid) {
      state = state.copyWith(validationCodes: validation.codes);
      return validation.codes.first;
    }

    state = state.copyWith(
      isSavingDraft: true,
      clearError: true,
      clearValidation: true,
    );
    try {
      final id = await ref
          .read(invoiceRepositoryProvider)
          .saveInvoiceDraft(session, form);
      state = state.copyWith(
        isSavingDraft: false,
        invoiceId: id,
        lastSavedInvoiceId: id,
        form: domain.InvoiceFormState(draft: form.draft.copyWithInvoiceId(id)),
      );
      return null;
    } on FinanceException catch (e) {
      state = state.copyWith(isSavingDraft: false, errorCode: e.code);
      return e.code;
    } catch (_) {
      state = state.copyWith(
        isSavingDraft: false,
        errorCode: FinanceException.unknown,
      );
      return FinanceException.unknown;
    }
  }

  Future<String?> discardDraft() async {
    final session = _session;
    final invoiceId = state.invoiceId;
    if (session == null || invoiceId == null) return FinanceException.unknown;
    if (!canEditInvoiceDraft(session)) {
      return FinanceException.permissionDenied;
    }

    state = state.copyWith(isSavingDraft: true, clearError: true);
    try {
      await ref
          .read(invoiceRepositoryProvider)
          .discardInvoiceDraft(session, invoiceId);
      state = state.copyWith(isSavingDraft: false);
      return null;
    } on FinanceException catch (e) {
      state = state.copyWith(isSavingDraft: false, errorCode: e.code);
      return e.code;
    } catch (_) {
      state = state.copyWith(
        isSavingDraft: false,
        errorCode: FinanceException.unknown,
      );
      return FinanceException.unknown;
    }
  }

  Future<String?> submit() async {
    final session = _session;
    if (session == null) return FinanceException.unknown;

    if (state.invoiceType.isReturn) {
      return _submitReturn(session);
    }
    return _submitInvoice(session);
  }

  Future<String?> _submitInvoice(AppSession session) async {
    final form = buildSafeForm();
    final serialized = serializedByProductIdFromLines(state.lines);

    final ValidationResult validation = switch (form.draft.type) {
      InvoiceType.sales => const SalesInvoiceValidator().validate(
        form,
        serializedByProductId: serialized,
        customerRequired: state.paymentTerms == InvoicePaymentTerms.credit,
        cashAccountRequired: state.paymentTerms == InvoicePaymentTerms.cash,
      ),
      InvoiceType.purchase => const PurchaseInvoiceValidator().validate(
        form,
        serializedByProductId: serialized,
      ),
      _ => const ValidationResult(codes: [FinanceException.notAvailable]),
    };
    if (!validation.isValid) {
      state = state.copyWith(validationCodes: validation.codes);
      return validation.codes.first;
    }

    if (!_canCreate(session, form.draft.type)) {
      return FinanceException.permissionDenied;
    }

    _idempotency ??= FinanceIdempotencySession();
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearValidation: true,
    );

    try {
      final repo = ref.read(invoiceRepositoryProvider);
      final id = switch (form.draft.type) {
        InvoiceType.sales => await repo.recordSalesInvoice(
          session,
          form,
          _idempotency!.key,
        ),
        InvoiceType.purchase => await repo.recordPurchaseInvoice(
          session,
          form,
          _idempotency!.key,
        ),
        _ => throw StateError('Unsupported invoice type'),
      };
      _idempotency!.clear();
      state = state.copyWith(
        isSubmitting: false,
        invoiceId: id,
        lastSavedInvoiceId: id,
      );
      return null;
    } on FinanceException catch (e) {
      if (_idempotency != null && !_idempotency!.shouldPreserveKeyOn(e)) {
        _idempotency!.clear();
      }
      state = state.copyWith(
        isSubmitting: false,
        errorCode: e.code,
        errorDetail: e.technicalDetail,
      );
      return e.code;
    } catch (e) {
      _idempotency?.clear();
      state = state.copyWith(
        isSubmitting: false,
        errorCode: FinanceException.unknown,
        errorDetail: e.toString(),
      );
      return FinanceException.unknown;
    }
  }

  Future<String?> _submitReturn(AppSession session) async {
    ensureLinkedReturnLinesSelected();
    final draft = state.returnDraft;
    if (draft == null) return FinanceException.unknown;

    if (draft.originalInvoiceId.trim().isEmpty) {
      return _submitDirectReturn(session);
    }

    final validation = const ReturnInvoiceValidator().validate(
      draft,
      returnableQtyByLineId: state.returnableQtyByLineId,
      serializedLineIds: state.serializedReturnLineIds,
    );
    if (!validation.isValid) {
      state = state.copyWith(validationCodes: validation.codes);
      return validation.codes.first;
    }

    if (!_canCreateReturn(session, state.invoiceType)) {
      return FinanceException.permissionDenied;
    }

    _idempotency ??= FinanceIdempotencySession();
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearValidation: true,
    );

    try {
      final repo = ref.read(invoiceRepositoryProvider);
      final id = switch (state.invoiceType) {
        InvoiceType.salesReturn => await repo.recordSalesReturn(
          session,
          draft,
          _idempotency!.key,
        ),
        InvoiceType.purchaseReturn => await repo.recordPurchaseReturn(
          session,
          draft,
          _idempotency!.key,
        ),
        _ => throw StateError('Not a return invoice type'),
      };
      _idempotency!.clear();
      state = state.copyWith(
        isSubmitting: false,
        invoiceId: id,
        lastSavedInvoiceId: id,
      );
      return null;
    } on FinanceException catch (e) {
      if (_idempotency != null && !_idempotency!.shouldPreserveKeyOn(e)) {
        _idempotency!.clear();
      }
      state = state.copyWith(
        isSubmitting: false,
        errorCode: e.code,
        errorDetail: e.technicalDetail,
      );
      return e.code;
    } catch (e) {
      _idempotency?.clear();
      state = state.copyWith(
        isSubmitting: false,
        errorCode: FinanceException.unknown,
        errorDetail: e.toString(),
      );
      return FinanceException.unknown;
    }
  }

  Future<String?> _submitDirectReturn(AppSession session) async {
    final form = buildSafeForm();
    final serialized = serializedByProductIdFromLines(state.lines);

    final ValidationResult validation = switch (state.invoiceType) {
      InvoiceType.salesReturn => const SalesInvoiceValidator().validate(
        form,
        serializedByProductId: serialized,
        customerRequired: false,
        cashAccountRequired: true,
      ),
      InvoiceType.purchaseReturn => const SalesInvoiceValidator().validate(
        form,
        serializedByProductId: serialized,
        customerRequired: false,
        cashAccountRequired: true,
      ),
      _ => const ValidationResult(codes: [FinanceException.notAvailable]),
    };
    if (!validation.isValid) {
      state = state.copyWith(validationCodes: validation.codes);
      return validation.codes.first;
    }

    if (!_canCreateReturn(session, state.invoiceType)) {
      return FinanceException.permissionDenied;
    }

    _idempotency ??= FinanceIdempotencySession();
    state = state.copyWith(
      isSubmitting: true,
      clearError: true,
      clearValidation: true,
    );

    try {
      final repo = ref.read(invoiceRepositoryProvider);
      final id = switch (state.invoiceType) {
        InvoiceType.salesReturn => await repo.recordDirectSalesReturn(
          session,
          form,
          _idempotency!.key,
        ),
        InvoiceType.purchaseReturn => await repo.recordDirectPurchaseReturn(
          session,
          form,
          _idempotency!.key,
        ),
        _ => throw StateError('Not a direct return invoice type'),
      };
      _idempotency!.clear();
      state = state.copyWith(
        isSubmitting: false,
        invoiceId: id,
        lastSavedInvoiceId: id,
      );
      return null;
    } on FinanceException catch (e) {
      if (_idempotency != null && !_idempotency!.shouldPreserveKeyOn(e)) {
        _idempotency!.clear();
      }
      state = state.copyWith(
        isSubmitting: false,
        errorCode: e.code,
        errorDetail: e.technicalDetail,
      );
      return e.code;
    } catch (e) {
      _idempotency?.clear();
      state = state.copyWith(
        isSubmitting: false,
        errorCode: FinanceException.unknown,
        errorDetail: e.toString(),
      );
      return FinanceException.unknown;
    }
  }

  bool _canCreate(AppSession session, InvoiceType type) {
    return switch (type) {
      InvoiceType.sales => canCreateSalesInvoice(session),
      InvoiceType.purchase => canCreatePurchaseInvoice(session),
      _ => false,
    };
  }

  bool _canCreateReturn(AppSession session, InvoiceType type) {
    return switch (type) {
      InvoiceType.salesReturn => canCreateSalesReturn(session),
      InvoiceType.purchaseReturn => canCreatePurchaseReturn(session),
      _ => false,
    };
  }

  void _syncReturnDraftWarehouse(String? warehouseId) {
    final draft = state.returnDraft;
    if (draft == null || warehouseId == null) return;
    state = state.copyWith(
      returnDraft: ReturnInvoiceDraft(
        originalInvoiceId: draft.originalInvoiceId,
        warehouseId: warehouseId,
        date: draft.date,
        reason: draft.reason,
        notes: draft.notes,
        lines: draft.lines,
      ),
    );
  }

  void _syncReturnDraftDate(DateTime date) {
    final draft = state.returnDraft;
    if (draft == null) return;
    state = state.copyWith(
      returnDraft: ReturnInvoiceDraft(
        originalInvoiceId: draft.originalInvoiceId,
        warehouseId: draft.warehouseId,
        date: date,
        reason: draft.reason,
        notes: draft.notes,
        lines: draft.lines,
      ),
    );
  }
}

extension on InvoiceDraft {
  InvoiceDraft copyWithInvoiceId(String id) {
    return InvoiceDraft(
      type: type,
      invoiceId: id,
      customerId: customerId,
      supplierId: supplierId,
      cashAccountId: cashAccountId,
      warehouseId: warehouseId,
      date: date,
      dueDate: dueDate,
      notes: notes,
      lines: lines,
    );
  }
}
