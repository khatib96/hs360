import 'package:hs360/core/errors/customer_exception.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/customers/data/customer_service_location_repository.dart';
import 'package:hs360/features/customers/domain/customer_service_location.dart';
import 'package:hs360/features/customers/domain/customer_service_location_form_state.dart';

class FakeCustomerServiceLocationRepository
    extends CustomerServiceLocationRepository {
  FakeCustomerServiceLocationRepository({
    List<CustomerServiceLocation> locations = const [],
    this.listError,
  })  : locations = List<CustomerServiceLocation>.from(locations),
        super(null);

  List<CustomerServiceLocation> locations;
  Object? listError;
  int listCallCount = 0;

  @override
  Future<List<CustomerServiceLocation>> listLocations(
    AppSession session,
    String customerId,
  ) async {
    listCallCount++;
    if (!session.isManager && !session.permissions.can('customers.view')) {
      throw const CustomerException(code: CustomerException.permissionDenied);
    }
    final error = listError;
    if (error != null) {
      if (error is CustomerException) throw error;
      throw const CustomerException(code: CustomerException.unknown);
    }
    return locations.where((l) => l.customerId == customerId).toList();
  }

  @override
  Future<CustomerServiceLocation> createLocation(
    AppSession session,
    String customerId,
    CustomerServiceLocationFormState input,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<CustomerServiceLocation> updateLocation(
    AppSession session,
    String customerId,
    String locationId,
    CustomerServiceLocationFormState input,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<void> deactivateLocation(
    AppSession session,
    String locationId,
  ) async {
    throw UnimplementedError();
  }

  @override
  Future<void> setPrimary(
    AppSession session,
    String locationId,
  ) async {
    throw UnimplementedError();
  }
}
