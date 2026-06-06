import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/customer_exception.dart';
import '../../../core/network/supabase_providers.dart';
import '../../../domain/validators/customer_service_location_validator.dart';
import '../../auth/domain/app_session.dart';
import '../domain/customer_service_location.dart';
import '../domain/customer_service_location_form_state.dart';

part 'customer_service_location_repository.g.dart';

@Riverpod(keepAlive: true)
CustomerServiceLocationRepository customerServiceLocationRepository(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return CustomerServiceLocationRepository(client);
}

class CustomerServiceLocationRepository {
  CustomerServiceLocationRepository(this._client);

  static const maxLocationsPerCustomer = 500;

  final SupabaseClient? _client;
  final CustomerServiceLocationValidator _validator =
      const CustomerServiceLocationValidator();

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) throw CustomerException.notConfigured();
    return client;
  }

  void _assertCanView(AppSession session) {
    if (!session.isManager && !session.permissions.can('customers.view')) {
      throw const CustomerException(code: CustomerException.permissionDenied);
    }
  }

  void _assertCanEdit(AppSession session) {
    _assertCanView(session);
    if (!session.isManager && !session.permissions.can('customers.edit')) {
      throw const CustomerException(code: CustomerException.permissionDenied);
    }
  }

  Future<List<CustomerServiceLocation>> listLocations(
    AppSession session,
    String customerId,
  ) async {
    _assertCanView(session);
    try {
      final rows = await _requireClient
          .rpc(
            'list_customer_service_locations',
            params: {'p_customer_id': customerId},
          )
          .limit(maxLocationsPerCustomer);
      return (rows as List)
          .map(
            (r) => CustomerServiceLocation.fromRow(
              Map<String, dynamic>.from(r as Map),
            ),
          )
          .toList();
    } catch (e, st) {
      throw CustomerException.fromSupabase(e, st);
    }
  }

  Future<CustomerServiceLocation> createLocation(
    AppSession session,
    String customerId,
    CustomerServiceLocationFormState input,
  ) async {
    _assertCanEdit(session);
    final validation = _validator.validate(input);
    if (!validation.isValid) {
      throw CustomerException(code: validation.codes.first);
    }

    try {
      final id = await _requireClient.rpc(
        'create_customer_service_location',
        params: {'p_customer_id': customerId, 'p_data': input.toPayload()},
      );
      final locations = await listLocations(session, customerId);
      return locations.firstWhere((l) => l.id == id as String);
    } catch (e, st) {
      throw CustomerException.fromSupabase(e, st);
    }
  }

  Future<CustomerServiceLocation> updateLocation(
    AppSession session,
    String customerId,
    String locationId,
    CustomerServiceLocationFormState input,
  ) async {
    _assertCanEdit(session);
    final validation = _validator.validate(input);
    if (!validation.isValid) {
      throw CustomerException(code: validation.codes.first);
    }

    try {
      await _requireClient.rpc(
        'update_customer_service_location',
        params: {'p_id': locationId, 'p_data': input.toPayload()},
      );
      final locations = await listLocations(session, customerId);
      return locations.firstWhere((l) => l.id == locationId);
    } catch (e, st) {
      throw CustomerException.fromSupabase(e, st);
    }
  }

  Future<void> deactivateLocation(AppSession session, String locationId) async {
    _assertCanEdit(session);
    try {
      await _requireClient.rpc(
        'deactivate_customer_service_location',
        params: {'p_id': locationId},
      );
    } catch (e, st) {
      throw CustomerException.fromSupabase(e, st);
    }
  }

  Future<void> setPrimary(AppSession session, String locationId) async {
    _assertCanEdit(session);
    try {
      await _requireClient.rpc(
        'set_primary_customer_service_location',
        params: {'p_id': locationId},
      );
    } catch (e, st) {
      throw CustomerException.fromSupabase(e, st);
    }
  }
}
