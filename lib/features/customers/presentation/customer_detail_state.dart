import '../domain/customer.dart';

class CustomerDetailState {
  const CustomerDetailState({
    this.isLoading = true,
    this.customer,
    this.errorCode,
  });

  final bool isLoading;
  final Customer? customer;
  final String? errorCode;

  bool get notFound => !isLoading && customer == null && errorCode == null;

  CustomerDetailState copyWith({
    bool? isLoading,
    Customer? customer,
    String? errorCode,
    bool clearError = false,
  }) {
    return CustomerDetailState(
      isLoading: isLoading ?? this.isLoading,
      customer: customer ?? this.customer,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
    );
  }
}
