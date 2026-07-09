import 'package:decimal/decimal.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/contracts/data/contract_repository.dart';
import 'package:hs360/features/contracts/domain/closure_draft.dart';
import 'package:hs360/features/contracts/domain/contract_detail.dart';
import 'package:hs360/features/contracts/domain/contract_draft.dart';
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

  ContractDraft? lastCreateDraft;
  TrialConversionDraft? lastConversionDraft;
  TrialExtensionDraft? lastExtensionDraft;
  TrialReturnDraft? lastReturnDraft;
  ClosureDraft? lastClosureDraft;
  RentalCollectionDraft? lastCollectionDraft;
  String? lastIdempotencyKey;
  var listCallCount = 0;

  @override
  Future<ContractPricingPreview> previewContractProfit(
    AppSession session,
    ContractDraft draft,
  ) async {
    _throwIfFetchError();
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
      throw const FinanceException(code: FinanceException.notFound);
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
    customerId: 'cust-1',
    monthlyRentalValue: Decimal.parse('120.000'),
  );
}

ContractDetail sampleContractDetail({String id = 'contract-1'}) {
  return ContractDetail(
    id: id,
    contractNumber: 'CON-001',
    type: ContractType.rental,
    status: ContractStatus.active,
    customerId: 'cust-1',
    serviceLocationId: 'loc-1',
    startDate: DateTime(2026, 7, 1),
    monthlyRentalValue: Decimal.parse('120.000'),
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
