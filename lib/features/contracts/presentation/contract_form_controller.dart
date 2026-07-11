import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/finance_exception.dart';
import '../../../core/errors/scan_exception.dart';
import '../../../core/scanning/data/scan_repository.dart';
import '../../../core/scanning/domain/scan_result.dart';
import '../../../core/utils/decimal_parser.dart';
import '../../../domain/validators/contract_validator.dart';
import '../../../domain/validators/validation_result.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../customers/data/customer_repository.dart';
import '../../customers/data/customer_service_location_repository.dart';
import '../../customers/domain/customer.dart';
import '../../customers/domain/customer_filters.dart';
import '../../finance_shared/domain/finance_idempotency.dart';
import '../../products/data/product_repository.dart';
import '../../products/data/product_unit_repository.dart';
import '../../products/domain/product.dart';
import '../../products/domain/product_filters.dart';
import '../../products/domain/product_type.dart';
import '../../products/domain/product_unit.dart';
import '../data/contract_repository.dart';
import '../domain/contract_permissions.dart';
import '../domain/contract_type.dart';
import 'contract_form_draft_builder.dart';
import 'contract_form_state.dart';
import 'contract_form_unit_filter.dart';

part 'contract_form_controller.g.dart';

@riverpod
class ContractFormController extends _$ContractFormController {
  FinanceIdempotencySession? _idempotency;
  Timer? _previewDebounce;

  static const _customerSearchLimit = 20;
  static const _productSearchLimit = 20;

  @override
  ContractFormUiState build() {
    ref.onDispose(() => _previewDebounce?.cancel());
    return ContractFormUiState.initial();
  }

  AppSession? get _session => ref.read(authControllerProvider).valueOrNull;

  void setType(ContractType type) {
    final cycleDay = _defaultCycleDay(state.startDate);
    state = state.copyWith(
      type: type,
      clearValidation: true,
      clearError: true,
      clearPricingPreview: true,
      clearMonthlyRentalValue: type == ContractType.trial,
      billingDay: type == ContractType.rental
          ? (state.billingDay ?? cycleDay)
          : null,
      refillDay: type == ContractType.rental
          ? (state.refillDay ?? cycleDay)
          : null,
      clearBillingDay: type == ContractType.trial,
      clearRefillDay: type == ContractType.trial,
      requestOverride: false,
      overrideReason: '',
    );
    _schedulePreview();
  }

  void setStartDate(DateTime date) {
    final previousDefault = _defaultCycleDay(state.startDate);
    final nextDate = DateTime(date.year, date.month, date.day);
    final nextDefault = _defaultCycleDay(nextDate);
    final shouldMoveBilling =
        state.type == ContractType.rental &&
        (state.billingDay == null || state.billingDay == previousDefault);
    final shouldMoveRefill =
        state.type == ContractType.rental &&
        (state.refillDay == null || state.refillDay == previousDefault);
    state = state.copyWith(
      startDate: nextDate,
      billingDay: shouldMoveBilling ? nextDefault : state.billingDay,
      refillDay: shouldMoveRefill ? nextDefault : state.refillDay,
      clearValidation: true,
      clearError: true,
    );
    _schedulePreview();
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
    final start = state.startDate;
    if (start == null) return;
    setEndDate(_addMonths(start, contractDefaultRentalTermMonths));
  }

  void setTrialDays(int days) {
    state = state.copyWith(
      trialDays: days,
      clearValidation: true,
      clearError: true,
    );
    _schedulePreview();
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
    setBillingDay(date == null ? null : _defaultCycleDay(date));
  }

  void setRefillDate(DateTime? date) {
    setRefillDay(date == null ? null : _defaultCycleDay(date));
  }

  void setNotes(String notes) {
    state = state.copyWith(notes: notes, clearValidation: true);
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
    setMonthlyRentalValue(tryParseDecimal(text));
  }

  void setRequestOverride(bool value) {
    state = state.copyWith(
      requestOverride: value,
      overrideReason: value ? state.overrideReason : '',
      clearValidation: true,
      clearError: true,
    );
    _schedulePreview();
  }

  void setOverrideReason(String reason) {
    state = state.copyWith(
      overrideReason: reason,
      clearValidation: true,
      clearError: true,
    );
    _schedulePreview();
  }

  Future<void> searchCustomers(String query) async {
    final session = _session;
    if (session == null) return;

    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(clearCustomerSearchResults: true);
      return;
    }

    state = state.copyWith(isSearchingCustomers: true);
    try {
      final customers = await ref
          .read(customerRepositoryProvider)
          .fetchCustomers(
            session,
            CustomerFilters(search: trimmed),
            limit: _customerSearchLimit,
          );
      state = state.copyWith(
        customerSearchResults: customers,
        isSearchingCustomers: false,
      );
    } catch (_) {
      state = state.copyWith(
        isSearchingCustomers: false,
        customerSearchResults: const [],
      );
    }
  }

  Future<void> selectCustomer(Customer customer) async {
    state = state.copyWith(
      selectedCustomer: customer,
      customerId: customer.id,
      clearServiceLocationId: true,
      clearServiceLocations: true,
      clearCustomerSearchResults: true,
      clearValidation: true,
      clearError: true,
    );
    await _loadServiceLocations(customer.id);
  }

  void clearCustomer() {
    state = state.copyWith(
      clearSelectedCustomer: true,
      clearCustomerId: true,
      clearServiceLocationId: true,
      clearServiceLocations: true,
      clearValidation: true,
    );
  }

  void selectServiceLocation(String? locationId) {
    state = state.copyWith(
      serviceLocationId: locationId,
      clearServiceLocationId: locationId == null,
      clearValidation: true,
      clearError: true,
    );
  }

  Future<void> _loadServiceLocations(String customerId) async {
    final session = _session;
    if (session == null) return;

    state = state.copyWith(
      isLoadingLocations: true,
      clearServiceLocations: true,
    );
    try {
      final locations = await ref
          .read(customerServiceLocationRepositoryProvider)
          .listLocations(session, customerId);
      final active = locations.where((l) => l.isActive).toList();
      String? selectedId;
      if (active.length == 1) {
        selectedId = active.first.id;
      } else {
        final primary = active.where((l) => l.isPrimary).toList();
        if (primary.length == 1) {
          selectedId = primary.first.id;
        }
      }
      state = state.copyWith(
        serviceLocations: active,
        serviceLocationId: selectedId,
        clearServiceLocationId: selectedId == null,
        isLoadingLocations: false,
      );
    } catch (_) {
      state = state.copyWith(
        isLoadingLocations: false,
        serviceLocations: const [],
      );
    }
  }

  void addAssetLine() {
    state = state.copyWith(
      assetLines: [...state.assetLines, const ContractAssetLineUiState()],
      clearValidation: true,
    );
    _schedulePreview();
  }

  void removeAssetLine(int index) {
    if (index < 0 || index >= state.assetLines.length) return;
    final lines = [...state.assetLines]..removeAt(index);
    state = state.copyWith(assetLines: lines, clearValidation: true);
    _schedulePreview();
  }

  void addConsumableLine() {
    state = state.copyWith(
      consumableLines: [
        ...state.consumableLines,
        ContractConsumableLineUiState(),
      ],
      clearValidation: true,
    );
    _schedulePreview();
  }

  void removeConsumableLine(int index) {
    if (index < 0 || index >= state.consumableLines.length) return;
    final lines = [...state.consumableLines]..removeAt(index);
    state = state.copyWith(consumableLines: lines, clearValidation: true);
    _schedulePreview();
  }

  Future<void> searchProducts(
    String query, {
    required ContractProductSearchTarget target,
    required int lineIndex,
  }) async {
    final session = _session;
    if (session == null) return;

    final trimmed = query.trim();
    if (trimmed.isEmpty) {
      state = state.copyWith(clearProductSearchResults: true);
      return;
    }

    state = state.copyWith(
      isSearchingProducts: true,
      productSearchTarget: target,
      productSearchLineIndex: lineIndex,
    );
    try {
      final productType = switch (target) {
        ContractProductSearchTarget.asset => ProductType.assetRental,
        ContractProductSearchTarget.consumable => ProductType.consumableRental,
        ContractProductSearchTarget.rental => null,
      };
      var products = await ref
          .read(productRepositoryProvider)
          .fetchProducts(
            ProductFilters(
              search: trimmed,
              productType: productType,
              isActive: true,
            ),
            session,
          );
      if (target == ContractProductSearchTarget.rental) {
        products = products
            .where((product) => product.productType.isRental)
            .toList();
      }
      state = state.copyWith(
        productSearchResults: products.take(_productSearchLimit).toList(),
        isSearchingProducts: false,
      );
    } catch (_) {
      state = state.copyWith(
        isSearchingProducts: false,
        productSearchResults: const [],
      );
    }
  }

  Future<void> selectAssetProduct(int lineIndex, Product product) async {
    if (lineIndex < 0 || lineIndex >= state.assetLines.length) return;
    final lines = [...state.assetLines];
    lines[lineIndex] = lines[lineIndex].copyWith(
      product: product,
      clearProductUnitId: true,
      clearAvailableUnits: true,
    );
    state = state.copyWith(
      assetLines: lines,
      clearProductSearchResults: true,
      clearValidation: true,
    );
    await _loadAvailableUnits(lineIndex, product.id);
    _schedulePreview();
  }

  Future<void> addRentalProduct(Product product) async {
    if (product.productType == ProductType.assetRental) {
      final index = state.assetLines.length;
      state = state.copyWith(
        assetLines: [
          ...state.assetLines,
          ContractAssetLineUiState(product: product),
        ],
        clearProductSearchResults: true,
        clearValidation: true,
      );
      await _loadAvailableUnits(index, product.id, preserveSelection: true);
      _schedulePreview();
      return;
    }
    if (product.productType == ProductType.consumableRental) {
      state = state.copyWith(
        consumableLines: [
          ...state.consumableLines,
          ContractConsumableLineUiState(product: product),
        ],
        clearProductSearchResults: true,
        clearValidation: true,
      );
      _schedulePreview();
    }
  }

  void selectConsumableProduct(int lineIndex, Product product) {
    if (lineIndex < 0 || lineIndex >= state.consumableLines.length) return;
    final lines = [...state.consumableLines];
    lines[lineIndex] = lines[lineIndex].copyWith(product: product);
    state = state.copyWith(
      consumableLines: lines,
      clearProductSearchResults: true,
      clearValidation: true,
    );
    _schedulePreview();
  }

  void setAssetUnit(int lineIndex, String? unitId) {
    if (lineIndex < 0 || lineIndex >= state.assetLines.length) return;
    final current = state.assetLines[lineIndex];
    ProductUnit? selectedUnit;
    for (final unit in current.availableUnits) {
      if (unit.id == unitId) {
        selectedUnit = unit;
        break;
      }
    }
    final lines = [...state.assetLines];
    lines[lineIndex] = lines[lineIndex].copyWith(
      productUnitId: unitId,
      clearProductUnitId: unitId == null,
      unitCode: selectedUnit?.serialNumber,
      clearUnitCode: unitId == null,
      clearUnitError: true,
    );
    state = state.copyWith(assetLines: lines, clearValidation: true);
    _schedulePreview();
  }

  void setAssetUnitCode(int lineIndex, String code) {
    if (lineIndex < 0 || lineIndex >= state.assetLines.length) return;
    final lines = [...state.assetLines];
    lines[lineIndex] = lines[lineIndex].copyWith(
      unitCode: code,
      clearProductUnitId: true,
      clearUnitError: true,
    );
    state = state.copyWith(assetLines: lines, clearValidation: true);
  }

  Future<void> resolveAssetUnitCode(int lineIndex) async {
    if (lineIndex < 0 || lineIndex >= state.assetLines.length) return;
    final code = state.assetLines[lineIndex].unitCode.trim();
    if (code.isEmpty) return;

    final localMatch = _findAvailableUnitByCode(
      state.assetLines[lineIndex],
      code,
    );
    if (localMatch != null) {
      setAssetUnit(lineIndex, localMatch.id);
      return;
    }

    await _resolveRentalCode(code, replaceAssetIndex: lineIndex);
  }

  Future<void> addRentalCode(String code) async {
    await _resolveRentalCode(code.trim());
  }

  void setConsumableQty(int lineIndex, Decimal qty) {
    if (lineIndex < 0 || lineIndex >= state.consumableLines.length) return;
    final lines = [...state.consumableLines];
    lines[lineIndex] = lines[lineIndex].copyWith(qtyPerRefill: qty);
    state = state.copyWith(consumableLines: lines, clearValidation: true);
    _schedulePreview();
  }

  void setConsumableQtyFromText(int lineIndex, String text) {
    setConsumableQty(lineIndex, tryParseDecimal(text) ?? Decimal.zero);
  }

  void setConsumableFrequency(int lineIndex, int months) {
    if (lineIndex < 0 || lineIndex >= state.consumableLines.length) return;
    final lines = [...state.consumableLines];
    lines[lineIndex] = lines[lineIndex].copyWith(refillFrequencyMonths: months);
    state = state.copyWith(consumableLines: lines, clearValidation: true);
    _schedulePreview();
  }

  Future<void> _loadAvailableUnits(
    int lineIndex,
    String productId, {
    bool preserveSelection = false,
  }) async {
    final session = _session;
    if (session == null) return;
    if (lineIndex < 0 || lineIndex >= state.assetLines.length) return;

    final lines = [...state.assetLines];
    lines[lineIndex] = lines[lineIndex].copyWith(
      isLoadingUnits: true,
      clearAvailableUnits: true,
      clearProductUnitId: !preserveSelection,
    );
    state = state.copyWith(assetLines: lines);

    try {
      final units = await ref
          .read(productUnitRepositoryProvider)
          .fetchUnitsByProductId(productId, session);
      final filtered = filterAvailableContractUnits(units);
      final updated = [...state.assetLines];
      final currentSelection = updated[lineIndex].productUnitId;
      final keepSelection =
          preserveSelection &&
          filtered.any((unit) => unit.id == currentSelection);
      updated[lineIndex] = updated[lineIndex].copyWith(
        availableUnits: filtered,
        isLoadingUnits: false,
        clearProductUnitId: !keepSelection,
      );
      state = state.copyWith(assetLines: updated);
    } catch (_) {
      final updated = [...state.assetLines];
      updated[lineIndex] = updated[lineIndex].copyWith(
        availableUnits: const [],
        isLoadingUnits: false,
      );
      state = state.copyWith(assetLines: updated);
    }
  }

  Future<void> _resolveRentalCode(String code, {int? replaceAssetIndex}) async {
    final session = _session;
    if (session == null || code.isEmpty) return;
    final index = replaceAssetIndex;
    if (index != null && (index < 0 || index >= state.assetLines.length)) {
      return;
    }

    if (index != null) {
      final lines = [...state.assetLines];
      lines[index] = lines[index].copyWith(
        isResolvingUnit: true,
        clearUnitError: true,
      );
      state = state.copyWith(assetLines: lines);
    }

    try {
      final result = await ref
          .read(scanRepositoryProvider)
          .resolveScanCode(code);
      if (!result.isActiveOrAvailable) {
        _markResolveFailure(index, ScanException.scanNotFound);
        return;
      }
      final product = await ref
          .read(productRepositoryProvider)
          .fetchProductById(result.productId, session);
      if (product == null || !product.productType.isRental) {
        _markResolveFailure(index, FinanceException.validationProductRequired);
        return;
      }

      if (result.kind == ScanResultKind.product) {
        if (index == null) {
          await addRentalProduct(product);
        } else if (product.productType == ProductType.assetRental) {
          await _replaceAssetLineProduct(index, product, unitCode: code);
        } else {
          _markResolveFailure(
            index,
            FinanceException.validationSerializedUnitRequired,
          );
        }
        return;
      }

      if (product.productType != ProductType.assetRental) {
        _markResolveFailure(
          index,
          FinanceException.validationSerializedUnitRequired,
        );
        return;
      }

      final unit = await ref
          .read(productUnitRepositoryProvider)
          .fetchUnitById(result.id, session);
      if (unit == null ||
          !filterAvailableContractUnits([unit]).contains(unit)) {
        _markResolveFailure(index, ScanException.scanNotFound);
        return;
      }

      if (index == null) {
        final newIndex = state.assetLines.length;
        state = state.copyWith(
          assetLines: [
            ...state.assetLines,
            ContractAssetLineUiState(
              product: product,
              productUnitId: unit.id,
              unitCode: unit.serialNumber,
              availableUnits: [unit],
            ),
          ],
          clearValidation: true,
        );
        await _loadAvailableUnits(
          newIndex,
          product.id,
          preserveSelection: true,
        );
      } else {
        await _replaceAssetLineProduct(
          index,
          product,
          productUnitId: unit.id,
          unitCode: unit.serialNumber,
        );
      }
      _schedulePreview();
    } catch (_) {
      _markResolveFailure(index, ScanException.scanNotFound);
    }
  }

  Future<void> _replaceAssetLineProduct(
    int index,
    Product product, {
    String? productUnitId,
    String? unitCode,
  }) async {
    if (index < 0 || index >= state.assetLines.length) return;
    final lines = [...state.assetLines];
    lines[index] = lines[index].copyWith(
      product: product,
      productUnitId: productUnitId,
      clearProductUnitId: productUnitId == null,
      unitCode: unitCode,
      clearUnitCode: unitCode == null,
      clearAvailableUnits: true,
      isResolvingUnit: false,
      clearUnitError: true,
    );
    state = state.copyWith(assetLines: lines, clearValidation: true);
    await _loadAvailableUnits(
      index,
      product.id,
      preserveSelection: productUnitId != null,
    );
    _schedulePreview();
  }

  void _markResolveFailure(int? index, String code) {
    if (index == null) {
      state = state.copyWith(errorCode: code);
      return;
    }
    if (index < 0 || index >= state.assetLines.length) return;
    final lines = [...state.assetLines];
    lines[index] = lines[index].copyWith(
      isResolvingUnit: false,
      unitErrorCode: code,
    );
    state = state.copyWith(assetLines: lines);
  }

  ProductUnit? _findAvailableUnitByCode(
    ContractAssetLineUiState line,
    String code,
  ) {
    final normalized = code.trim().toLowerCase();
    for (final unit in line.availableUnits) {
      if (unit.serialNumber.toLowerCase() == normalized ||
          unit.barcode?.toLowerCase() == normalized) {
        return unit;
      }
    }
    return null;
  }

  void _schedulePreview() {
    _previewDebounce?.cancel();
    if (state.type != ContractType.rental) {
      state = state.copyWith(
        clearPricingPreview: true,
        isLoadingPreview: false,
      );
      return;
    }
    _previewDebounce = Timer(const Duration(milliseconds: 400), () {
      unawaited(refreshPreview());
    });
  }

  Future<void> refreshPreview() async {
    final session = _session;
    if (session == null || !canCreateContract(session)) return;
    if (state.type != ContractType.rental) return;

    final draft = buildContractDraft(state);
    if (draft.assetLines.isEmpty) {
      state = state.copyWith(
        clearPricingPreview: true,
        isLoadingPreview: false,
      );
      return;
    }

    state = state.copyWith(isLoadingPreview: true, clearError: true);
    try {
      final preview = await ref
          .read(contractRepositoryProvider)
          .previewContractProfit(session, draft);
      state = state.copyWith(pricingPreview: preview, isLoadingPreview: false);
    } on FinanceException catch (e) {
      state = state.copyWith(
        isLoadingPreview: false,
        errorCode: e.code,
        errorDetail: e.technicalDetail,
      );
    } catch (_) {
      state = state.copyWith(
        isLoadingPreview: false,
        errorCode: FinanceException.unknown,
      );
    }
  }

  ValidationResult validate() {
    final draft = buildContractDraft(state);
    return const ContractValidator().validate(
      draft,
      serializedByProductId: serializedByProductIdFromContractLines(state),
    );
  }

  Future<String?> submit() async {
    final session = _session;
    if (session == null) return FinanceException.permissionDenied;
    if (!canCreateContract(session)) return FinanceException.permissionDenied;

    await _resolvePendingUnitCodes();

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

    final draft = buildContractDraft(state);
    try {
      final repo = ref.read(contractRepositoryProvider);
      final id = switch (draft.type) {
        ContractType.trial => await repo.createTrialContract(
          session,
          draft,
          _idempotency!.key,
        ),
        ContractType.rental => await repo.createRentalContract(
          session,
          draft,
          _idempotency!.key,
        ),
      };
      _idempotency!.clear();
      state = state.copyWith(isSubmitting: false, lastCreatedContractId: id);
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

  Future<void> _resolvePendingUnitCodes() async {
    for (var i = 0; i < state.assetLines.length; i++) {
      final line = state.assetLines[i];
      if (line.productUnitId == null && line.unitCode.trim().isNotEmpty) {
        await resolveAssetUnitCode(i);
      }
    }
  }

  DateTime _addMonths(DateTime date, int months) {
    final monthIndex = date.month - 1 + months;
    final year = date.year + monthIndex ~/ 12;
    final month = monthIndex % 12 + 1;
    final day = date.day;
    final lastDay = DateTime(year, month + 1, 0).day;
    return DateTime(year, month, day > lastDay ? lastDay : day);
  }

  int? _defaultCycleDay(DateTime? date) {
    if (date == null) return null;
    return date.day > 28 ? 28 : date.day;
  }
}
