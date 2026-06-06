import '../domain/customer.dart';
import '../domain/customer_filters.dart';

/// Immutable UI state for the customer list.
class CustomerListState {
  const CustomerListState({
    this.customers = const [],
    this.filters = const CustomerFilters(isActive: true),
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = false,
    this.errorCode,
    this.loadMoreErrorCode,
  });

  final List<Customer> customers;
  final CustomerFilters filters;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final String? errorCode;
  final String? loadMoreErrorCode;

  bool get hasError => errorCode != null;

  CustomerListState copyWith({
    List<Customer>? customers,
    CustomerFilters? filters,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    String? errorCode,
    String? loadMoreErrorCode,
    bool clearError = false,
    bool clearLoadMoreError = false,
  }) {
    return CustomerListState(
      customers: customers ?? this.customers,
      filters: filters ?? this.filters,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      loadMoreErrorCode: clearLoadMoreError
          ? null
          : (loadMoreErrorCode ?? this.loadMoreErrorCode),
    );
  }
}
