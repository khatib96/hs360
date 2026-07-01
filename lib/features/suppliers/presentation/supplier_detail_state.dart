import '../domain/supplier.dart';

class SupplierDetailState {
  const SupplierDetailState({
    this.isLoading = false,
    this.supplier,
    this.errorCode,
  });

  final bool isLoading;
  final Supplier? supplier;
  final String? errorCode;

  bool get notFound => !isLoading && supplier == null && errorCode == null;

  SupplierDetailState copyWith({
    bool? isLoading,
    Supplier? supplier,
    String? errorCode,
    bool clearError = false,
  }) {
    return SupplierDetailState(
      isLoading: isLoading ?? this.isLoading,
      supplier: supplier ?? this.supplier,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
    );
  }
}
