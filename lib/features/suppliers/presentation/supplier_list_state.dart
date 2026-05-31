import '../domain/supplier.dart';
import '../domain/supplier_filters.dart';

/// Immutable UI state for the supplier list.
class SupplierListState {
  const SupplierListState({
    this.suppliers = const [],
    this.filters = const SupplierFilters(isActive: true),
    this.isLoading = false,
    this.errorCode,
  });

  final List<Supplier> suppliers;
  final SupplierFilters filters;
  final bool isLoading;
  final String? errorCode;

  bool get hasError => errorCode != null;

  SupplierListState copyWith({
    List<Supplier>? suppliers,
    SupplierFilters? filters,
    bool? isLoading,
    String? errorCode,
    bool clearError = false,
  }) {
    return SupplierListState(
      suppliers: suppliers ?? this.suppliers,
      filters: filters ?? this.filters,
      isLoading: isLoading ?? this.isLoading,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
    );
  }
}
