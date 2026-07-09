import '../../contracts/domain/contract_filters.dart';
import '../../contracts/domain/contract_summary.dart';

class CustomerContractsState {
  CustomerContractsState({
    this.contracts = const [],
    this.filters = const ContractFilters(),
    this.isLoading = false,
    this.hasLoaded = false,
    this.permissionDenied = false,
    this.listUnavailable = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.errorCode,
    this.loadMoreErrorCode,
  });

  final List<ContractSummary> contracts;
  final ContractFilters filters;
  final bool isLoading;
  final bool hasLoaded;
  final bool permissionDenied;
  final bool listUnavailable;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorCode;
  final String? loadMoreErrorCode;

  CustomerContractsState copyWith({
    List<ContractSummary>? contracts,
    ContractFilters? filters,
    bool? isLoading,
    bool? hasLoaded,
    bool? permissionDenied,
    bool? listUnavailable,
    bool? isLoadingMore,
    bool? hasMore,
    String? errorCode,
    bool clearError = false,
    String? loadMoreErrorCode,
    bool clearLoadMoreError = false,
  }) {
    return CustomerContractsState(
      contracts: contracts ?? this.contracts,
      filters: filters ?? this.filters,
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      listUnavailable: listUnavailable ?? this.listUnavailable,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      loadMoreErrorCode: clearLoadMoreError
          ? null
          : (loadMoreErrorCode ?? this.loadMoreErrorCode),
    );
  }
}
