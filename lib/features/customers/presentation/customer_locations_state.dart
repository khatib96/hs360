import '../domain/customer_service_location.dart';

class CustomerLocationsState {
  const CustomerLocationsState({
    this.locations = const [],
    this.isLoading = false,
    this.errorCode,
    this.isMutating = false,
  });

  final List<CustomerServiceLocation> locations;
  final bool isLoading;
  final String? errorCode;
  final bool isMutating;

  List<CustomerServiceLocation> get activeLocations =>
      locations.where((l) => l.isActive).toList();

  CustomerLocationsState copyWith({
    List<CustomerServiceLocation>? locations,
    bool? isLoading,
    String? errorCode,
    bool clearError = false,
    bool? isMutating,
  }) {
    return CustomerLocationsState(
      locations: locations ?? this.locations,
      isLoading: isLoading ?? this.isLoading,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      isMutating: isMutating ?? this.isMutating,
    );
  }
}
