import '../domain/customer.dart';
import '../domain/customer_filters.dart';

/// Immutable UI state for the customer list.
class CustomerListState {
  const CustomerListState({
    this.customers = const [],
    this.filters = const CustomerFilters(isActive: true),
    this.isLoading = false,
    this.errorCode,
  });

  final List<Customer> customers;
  final CustomerFilters filters;
  final bool isLoading;
  final String? errorCode;

  bool get hasError => errorCode != null;

  CustomerListState copyWith({
    List<Customer>? customers,
    CustomerFilters? filters,
    bool? isLoading,
    String? errorCode,
    bool clearError = false,
  }) {
    return CustomerListState(
      customers: customers ?? this.customers,
      filters: filters ?? this.filters,
      isLoading: isLoading ?? this.isLoading,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
    );
  }
}
