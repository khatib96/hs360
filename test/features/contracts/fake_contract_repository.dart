import 'package:decimal/decimal.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/contracts/data/contract_repository.dart';
import 'package:hs360/features/contracts/domain/closure_draft.dart';
import 'package:hs360/features/contracts/domain/consumable_change_draft.dart';
import 'package:hs360/features/contracts/domain/contract_detail.dart';
import 'package:hs360/features/contracts/domain/contract_draft.dart';
import 'package:hs360/features/contracts/domain/contract_line.dart';
import 'package:hs360/features/contracts/domain/contract_filters.dart';
import 'package:hs360/features/contracts/domain/contract_pricing_preview.dart';
import 'package:hs360/features/contracts/domain/contract_status.dart';
import 'package:hs360/features/contracts/domain/contract_summary.dart';
import 'package:hs360/features/contracts/domain/contract_type.dart';
import 'package:hs360/features/contracts/domain/rental_collection_draft.dart';
import 'package:hs360/features/contracts/domain/trial_conversion_draft.dart';
import 'package:hs360/features/contracts/domain/trial_extension_draft.dart';
import 'package:hs360/features/contracts/domain/trial_return_draft.dart';
import 'package:hs360/features/finance_shared/domain/pagination_cursor.dart';

class FakeContractRepository extends ContractRepository {
  FakeContractRepository({
    this.pricingPreview,
    this.collectionPreview,
    this.collectionResult,
    this.coveredMonthKeys = const [],
    this.createdContractId = 'contract-new',
    this.fetchError,
    this.detailById = const {},
    this.summaries = const [],
  }) : super(null);

  ContractPricingPreview? pricingPreview;
  RentalCollectionPreview? collectionPreview;
  RentalCollectionResult? collectionResult;
  String createdContractId;
  Object? fetchError;
  Map<String, ContractDetail> detailById;
  List<ContractSummary> summaries;

  List<String> coveredMonthKeys;

  ContractDraft? lastCreateDraft;
  TrialConversionDraft? lastConversionDraft;
  TrialExtensionDraft? lastExtensionDraft;
  TrialReturnDraft? lastReturnDraft;
  ClosureDraft? lastClosureDraft;
  ConsumableChangeDraft? lastConsumableChangeDraft;
  RentalCollectionDraft? lastCollectionDraft;
  ContractDraft? lastPreviewDraft;
  String? lastIdempotencyKey;
  var listCallCount = 0;

  @override
  Future<ContractPricingPreview> previewContractProfit(
    AppSession session,
    ContractDraft draft,
  ) async {
    _throwIfFetchError();
    lastPreviewDraft = draft;
    return pricingPreview ?? samplePricingPreview();
  }

  @override
  Future<String> createTrialContract(
    AppSession session,
    ContractDraft draft,
    String idempotencyKey,
  ) async {
    _throwIfFetchError();
    lastCreateDraft = draft;
    lastIdempotencyKey = idempotencyKey;
    return createdContractId;
  }

  @override
  Future<String> createRentalContract(
    AppSession session,
    ContractDraft draft,
    String idempotencyKey,
  ) async {
    _throwIfFetchError();
    lastCreateDraft = draft;
    lastIdempotencyKey = idempotencyKey;
    return createdContractId;
  }

  @override
  Future<String> convertTrialToRental(
    AppSession session,
    TrialConversionDraft draft,
    String idempotencyKey,
  ) async {
    _throwIfFetchError();
    lastConversionDraft = draft;
    lastIdempotencyKey = idempotencyKey;
    return createdContractId;
  }

  @override
  Future<String> extendTrialContract(
    AppSession session,
    TrialExtensionDraft draft,
    String idempotencyKey,
  ) async {
    _throwIfFetchError();
    lastExtensionDraft = draft;
    lastIdempotencyKey = idempotencyKey;
    return draft.trialContractId;
  }

  @override
  Future<String> returnTrialContract(
    AppSession session,
    TrialReturnDraft draft,
    String idempotencyKey,
  ) async {
    _throwIfFetchError();
    lastReturnDraft = draft;
    lastIdempotencyKey = idempotencyKey;
    return draft.trialContractId;
  }

  @override
  Future<String> closeContract(
    AppSession session,
    ClosureDraft draft,
    String idempotencyKey,
  ) async {
    _throwIfFetchError();
    lastClosureDraft = draft;
    lastIdempotencyKey = idempotencyKey;
    return draft.contractId;
  }

  @override
  Future<String> scheduleConsumableChange(
    AppSession session,
    ConsumableChangeDraft draft,
    String idempotencyKey,
  ) async {
    _throwIfFetchError();
    lastConsumableChangeDraft = draft;
    lastIdempotencyKey = idempotencyKey;
    return draft.contractId;
  }

  @override
  Future<List<String>> listCoveredRentalMonths(
    AppSession session,
    String contractId,
  ) async {
    _throwIfFetchError();
    return List<String>.from(coveredMonthKeys);
  }

  @override
  Future<RentalCollectionPreview> previewRentalCollection(
    AppSession session,
    RentalCollectionDraft draft,
  ) async {
    _throwIfFetchError();
    lastCollectionDraft = draft;
    return collectionPreview ??
        RentalCollectionPreview(
          contractId: draft.contractId,
          coverageMonths: draft.coverageMonths,
          invoiceTotal: draft.amount,
          expectedCollectedAmount: draft.amount,
        );
  }

  @override
  Future<RentalCollectionResult> collectRentalPayment(
    AppSession session,
    RentalCollectionDraft draft,
    String idempotencyKey,
  ) async {
    _throwIfFetchError();
    lastCollectionDraft = draft;
    lastIdempotencyKey = idempotencyKey;
    return collectionResult ??
        RentalCollectionResult(
          invoiceId: 'invoice-1',
          voucherId: 'voucher-1',
          coverageMonths: draft.coverageMonths,
          invoiceTotal: draft.amount,
          collectedAmount: draft.amount,
        );
  }

  void _throwIfFetchError() {
    final error = fetchError;
    if (error == null) return;
    if (error is FinanceException) throw error;
    throw const FinanceException(code: FinanceException.unknown);
  }

  @override
  Future<List<ContractSummary>> listContracts(
    AppSession session, {
    ContractFilters filters = const ContractFilters(),
    PaginationCursor page = const PaginationCursor(),
  }) async {
    listCallCount++;
    _throwIfFetchError();
    final filtered = summaries.where((row) => _matchesFilters(row, filters));
    final start = page.offset;
    final end = start + page.limit + 1;
    return filtered.skip(start).take(end - start).toList();
  }

  @override
  Future<ContractDetail> fetchContractDetail(
    AppSession session,
    String contractId,
  ) async {
    _throwIfFetchError();
    final detail = detailById[contractId];
    if (detail == null) {
      throw const FinanceException(code: FinanceException.validationFailed);
    }
    return detail;
  }

  bool _matchesFilters(ContractSummary row, ContractFilters filters) {
    if (filters.type != null && row.type != filters.type) return false;
    if (filters.status != null && row.status != filters.status) return false;
    final customerId = filters.customerId?.trim();
    if (customerId != null &&
        customerId.isNotEmpty &&
        row.customerId != customerId) {
      return false;
    }
    if (filters.lowProfitOverrideOnly && row.minProfitOverridden != true) {
      return false;
    }
    final search = filters.search?.trim().toLowerCase();
    if (search != null && search.isNotEmpty) {
      final haystack = [
        row.contractNumber,
        row.customerNameEn,
        row.customerNameAr,
      ].whereType<String>().join(' ').toLowerCase();
      if (!haystack.contains(search)) return false;
    }
    if (!filters.dateRange.isEmpty) {
      final from = filters.dateRange.from;
      final to = filters.dateRange.to;
      if (from != null && row.startDate.isBefore(from)) return false;
      if (to != null && row.startDate.isAfter(to)) return false;
    }
    return true;
  }
}

ContractSummary sampleContractSummary({String id = 'contract-1'}) {
  return ContractSummary(
    id: id,
    contractNumber: 'CON-001',
    type: ContractType.rental,
    status: ContractStatus.active,
    startDate: DateTime(2026, 7, 1),
    endDate: DateTime(2027, 7, 1),
    customerId: 'cust-1',
    locationGovernorate: 'Hawalli',
    locationArea: 'Salmiya',
    monthlyRentalValue: Decimal.parse('120.000'),
  );
}

ContractDetail sampleContractDetail({
  String id = 'contract-1',
  Decimal? totalContractValue,
  DateTime? endDate,
  int? billingDay,
  int? refillDay,
}) {
  return ContractDetail(
    id: id,
    contractNumber: 'CON-001',
    type: ContractType.rental,
    status: ContractStatus.active,
    customerId: 'cust-1',
    customerNameEn: 'Acme Corp',
    serviceLocationId: 'loc-1',
    serviceLocationName: 'Main Site',
    startDate: DateTime(2026, 7, 9),
    endDate: endDate ?? DateTime(2027, 7, 9),
    billingDay: billingDay,
    refillDay: refillDay,
    monthlyRentalValue: Decimal.parse('120.000'),
    totalContractValue: totalContractValue,
    snapshotDeviceMonthlyCost: Decimal.parse('40.000'),
    snapshotOilMonthlyCost: Decimal.parse('10.000'),
    snapshotTotalMonthlyCost: Decimal.parse('50.000'),
    snapshotMonthlyProfit: Decimal.parse('70.000'),
    assetLines: [
      ContractAssetLine(
        id: 'line-asset-1',
        productId: 'prod-1',
        serialNumber: 'SN-001',
        productSku: 'DEV-001',
        productNameEn: 'Device A',
        productGroupNameEn: 'Devices',
        snapshotUnitCost: Decimal.parse('60.000'),
        snapshotMonthlyCost: Decimal.parse('40.000'),
        lineOrder: 0,
      ),
    ],
    consumableLines: [
      ContractConsumableLine(
        id: 'line-cons-1',
        productId: 'oil-1',
        productSku: 'OIL-001',
        productNameEn: 'Oil A',
        productGroupNameEn: 'Oils',
        qtyPerRefill: Decimal.parse('500'),
        refillFrequencyMonths: 1,
        snapshotUnitCost: Decimal.parse('0.020'),
        snapshotMonthlyCost: Decimal.parse('10.000'),
        lineOrder: 1,
      ),
    ],
  );
}

ContractDetail sampleTrialDetail({String id = 'trial-1', DateTime? startDate}) {
  final base = sampleContractDetail(id: id);
  return ContractDetail(
    id: id,
    contractNumber: 'TRIAL-001',
    type: ContractType.trial,
    status: ContractStatus.active,
    customerId: base.customerId,
    customerNameEn: base.customerNameEn,
    serviceLocationId: base.serviceLocationId,
    serviceLocationName: base.serviceLocationName,
    startDate: startDate ?? DateTime(2024, 1, 1),
    monthlyRentalValue: base.monthlyRentalValue,
    assetLines: base.assetLines,
    consumableLines: base.consumableLines,
  );
}

ContractPricingPreview samplePricingPreview() {
  return ContractPricingPreview(
    monthlyRentalValue: Decimal.parse('120.000'),
    passesMinProfit: true,
    belowMinProfit: false,
    requiresOverride: false,
  );
}
