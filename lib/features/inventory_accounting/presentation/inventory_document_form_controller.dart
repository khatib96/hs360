import 'package:decimal/decimal.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/finance_exception.dart';
import '../../../domain/validators/inventory_adjustment_document_validator.dart';
import '../../../domain/validators/opening_stock_validator.dart';
import '../../../domain/validators/validation_result.dart';
import '../../../domain/validators/stock_count_validator.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/domain/finance_idempotency.dart';
import '../../inventory/data/inventory_repository.dart';
import '../../inventory/data/warehouse_repository.dart';
import '../../products/data/product_repository.dart';
import '../../products/data/product_unit_repository.dart';
import '../../products/domain/product.dart';
import '../../products/domain/product_filters.dart';
import '../../products/domain/product_permissions.dart';
import '../../products/domain/unit_status.dart';
import '../data/inventory_document_repository.dart';
import '../domain/inventory_adjustment_reason.dart';
import '../domain/stock_count_draft.dart';
import 'inventory_document_form_mode.dart';
import 'inventory_document_form_state.dart';

part 'inventory_document_form_controller.g.dart';

@riverpod
class InventoryDocumentFormController extends _$InventoryDocumentFormController {
  FinanceIdempotencySession? _idempotency;

  @override
  InventoryDocumentFormState build(InventoryDocumentFormMode mode) {
    Future.microtask(loadMeta);
    return InventoryDocumentFormState(
      mode: mode,
      date: defaultInventoryFormDate(),
      lines: [InventoryDocumentFormLineState()],
    );
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

      List<InventoryAdjustmentReason> reasons = const [];
      List<InventoryAdjustmentReason> gainReasons = const [];
      List<InventoryAdjustmentReason> lossReasons = const [];

      final repo = ref.read(inventoryDocumentRepositoryProvider);
      if (state.mode == InventoryDocumentFormMode.stockIn) {
        reasons = await repo.listReasons(
          session,
          direction: 'stock_in',
          documentType: 'stock_in',
        );
      } else if (state.mode == InventoryDocumentFormMode.stockOut) {
        reasons = await repo.listReasons(
          session,
          direction: 'stock_out',
          documentType: 'stock_out',
        );
      } else if (state.mode == InventoryDocumentFormMode.stockCount) {
        gainReasons = await repo.listReasons(
          session,
          direction: 'stock_in',
          documentType: 'stock_count',
        );
        lossReasons = await repo.listReasons(
          session,
          direction: 'stock_out',
          documentType: 'stock_count',
        );
      }

      state = state.copyWith(
        warehouses: warehouses,
        reasons: reasons,
        gainReasons: gainReasons,
        lossReasons: lossReasons,
        isLoadingMeta: false,
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

  void setWarehouseId(String? warehouseId) {
    state = state.copyWith(
      warehouseId: warehouseId,
      clearWarehouse: warehouseId == null,
      lines: state.lines
          .map((line) => line.copyWith(clearSystemQty: true))
          .toList(),
      clearAvailableUnits: true,
    );
  }

  void setDate(DateTime date) {
    state = state.copyWith(date: date);
  }

  void setNotes(String notes) {
    state = state.copyWith(notes: notes, clearValidation: true);
  }

  void setReason(InventoryAdjustmentReason? reason) {
    state = state.copyWith(
      reason: reason,
      clearReason: reason == null,
      clearValidation: true,
    );
  }

  void setGainReason(InventoryAdjustmentReason? reason) {
    state = state.copyWith(
      gainReason: reason,
      clearGainReason: reason == null,
      clearValidation: true,
    );
  }

  void setLossReason(InventoryAdjustmentReason? reason) {
    state = state.copyWith(
      lossReason: reason,
      clearLossReason: reason == null,
      clearValidation: true,
    );
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

  Future<void> selectProduct(int lineIndex, Product product) async {
    if (lineIndex < 0 || lineIndex >= state.lines.length) return;

    final lines = [...state.lines];
    var line = lines[lineIndex].copyWith(product: product, clearUnitCost: true);

    if (state.mode == InventoryDocumentFormMode.stockCount &&
        state.warehouseId != null) {
      final balances = await ref
          .read(inventoryRepositoryProvider)
          .fetchInventoryBalances(
            productId: product.id,
            warehouseId: state.warehouseId,
          );
      final systemQty = balances.isNotEmpty
          ? balances.first.qtyAvailable
          : Decimal.zero;
      line = line.copyWith(systemQty: systemQty);
    }

    if (state.mode == InventoryDocumentFormMode.stockOut &&
        product.isSerialized &&
        state.warehouseId != null) {
      await _loadAvailableUnits(product.id);
    }

    lines[lineIndex] = line;
    state = state.copyWith(
      lines: lines,
      productSearchResults: const [],
      clearValidation: true,
    );
  }

  Future<void> _loadAvailableUnits(String productId) async {
    final session = _session;
    final warehouseId = state.warehouseId;
    if (session == null || warehouseId == null) return;

    try {
      final units = await ref
          .read(productUnitRepositoryProvider)
          .fetchUnitsByProductId(productId, session);
      final filtered = units
          .where(
            (u) =>
                u.currentWarehouseId == warehouseId &&
                (u.status == UnitStatus.availableNew ||
                    u.status == UnitStatus.availableUsed),
          )
          .toList();
      state = state.copyWith(availableUnits: filtered);
    } catch (_) {
      state = state.copyWith(availableUnits: const []);
    }
  }

  void clearProduct(int lineIndex) {
    if (lineIndex < 0 || lineIndex >= state.lines.length) return;
    final lines = [...state.lines];
    lines[lineIndex] = lines[lineIndex].copyWith(
      clearProduct: true,
      clearUnitCost: true,
      clearSystemQty: true,
      unitIds: const [],
      serialUnits: const [],
    );
    state = state.copyWith(
      lines: lines,
      clearAvailableUnits: true,
      clearValidation: true,
    );
  }

  void setLineQty(int lineIndex, Decimal qty) {
    _updateLine(lineIndex, (line) => line.copyWith(qty: qty));
  }

  void setLineUnitCost(int lineIndex, Decimal? unitCost) {
    _updateLine(
      lineIndex,
      (line) => line.copyWith(unitCost: unitCost, clearUnitCost: unitCost == null),
    );
  }

  void setLineCountedQty(int lineIndex, Decimal countedQty) {
    _updateLine(lineIndex, (line) => line.copyWith(countedQty: countedQty));
  }

  void setLineUnitIds(int lineIndex, List<String> unitIds) {
    _updateLine(lineIndex, (line) => line.copyWith(unitIds: unitIds));
  }

  void setLineSerialUnits(int lineIndex, List<SerializedUnitInput> serialUnits) {
    _updateLine(lineIndex, (line) => line.copyWith(serialUnits: serialUnits));
  }

  void addLine() {
    state = state.copyWith(lines: [...state.lines, InventoryDocumentFormLineState()]);
  }

  void removeLine(int lineIndex) {
    if (state.lines.length <= 1) return;
    final lines = [...state.lines]..removeAt(lineIndex);
    state = state.copyWith(lines: lines);
  }

  void _updateLine(
    int lineIndex,
    InventoryDocumentFormLineState Function(InventoryDocumentFormLineState) update,
  ) {
    if (lineIndex < 0 || lineIndex >= state.lines.length) return;
    final lines = [...state.lines];
    lines[lineIndex] = update(lines[lineIndex]);
    state = state.copyWith(lines: lines, clearValidation: true);
  }

  Future<String?> submit() async {
    final session = _session;
    if (session == null) return FinanceException.unknown;

    final validation = _validate();
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
      final repo = ref.read(inventoryDocumentRepositoryProvider);
      final String documentId;
      switch (state.mode) {
        case InventoryDocumentFormMode.openingStock:
          documentId = await repo.recordOpeningStock(
            session,
            _buildOpeningInput(),
            _idempotency!.key,
          );
        case InventoryDocumentFormMode.stockIn:
        case InventoryDocumentFormMode.stockOut:
          documentId = await repo.recordAdjustment(
            session,
            _buildAdjustmentInput(),
            _idempotency!.key,
          );
        case InventoryDocumentFormMode.stockCount:
          documentId = await repo.recordStockCount(
            session,
            _buildStockCountDraft(),
            _idempotency!.key,
          );
      }
      _idempotency!.clear();
      state = state.copyWith(isSubmitting: false);
      return documentId;
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

  ValidationResult _validate() {
    switch (state.mode) {
      case InventoryDocumentFormMode.openingStock:
        return const OpeningStockValidator().validate(_buildOpeningInput());
      case InventoryDocumentFormMode.stockIn:
      case InventoryDocumentFormMode.stockOut:
        return const InventoryAdjustmentDocumentValidator().validate(
          _buildAdjustmentInput(),
        );
      case InventoryDocumentFormMode.stockCount:
        return const StockCountValidator().validate(_buildStockCountDraft());
    }
  }

  OpeningStockInput _buildOpeningInput() {
    return OpeningStockInput(
      warehouseId: state.warehouseId ?? '',
      date: state.date,
      notes: state.notes,
      lines: [
        for (final line in state.lines)
          OpeningStockLineInput(
            productId: line.product?.id ?? '',
            qty: line.qty,
            unitCost: line.unitCost,
            isSerialized: line.product?.isSerialized ?? false,
          ),
      ],
    );
  }

  InventoryAdjustmentDocumentInput _buildAdjustmentInput() {
    final direction = state.mode == InventoryDocumentFormMode.stockIn
        ? InventoryAdjustmentDirection.stockIn
        : InventoryAdjustmentDirection.stockOut;

    return InventoryAdjustmentDocumentInput(
      warehouseId: state.warehouseId ?? '',
      date: state.date,
      notes: state.notes,
      direction: direction,
      reason: state.reason,
      lines: [
        for (final line in state.lines)
          InventoryAdjustmentDocumentLineInput(
            productId: line.product?.id ?? '',
            qty: line.qty,
            unitCost: line.unitCost,
            avgCost: line.product?.avgCost,
            isSerialized: line.product?.isSerialized ?? false,
            unitIds: line.unitIds,
            serialUnits: line.serialUnits,
          ),
      ],
    );
  }

  StockCountDraft _buildStockCountDraft() {
    return StockCountDraft(
      warehouseId: state.warehouseId ?? '',
      date: state.date,
      notes: state.notes,
      gainReasonCode: state.gainReason?.code ?? '',
      lossReasonCode: state.lossReason?.code ?? '',
      lines: [
        for (final line in state.lines)
          StockCountDraftLine(
            productId: line.product?.id ?? '',
            countedQty: line.countedQty,
            systemQty: line.systemQty,
            isSerialized: line.product?.isSerialized ?? false,
          ),
      ],
    );
  }
}
