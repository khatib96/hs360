import 'package:hs360/core/errors/customer_exception.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/customers/data/customer_repository.dart';
import 'package:hs360/features/customers/domain/customer.dart';
import 'package:hs360/features/customers/domain/customer_balance_summary.dart';
import 'package:hs360/features/customers/domain/customer_filters.dart';
import 'package:hs360/features/customers/domain/customer_form_state.dart';
import 'package:hs360/features/customers/domain/customer_statement_row.dart';
import 'package:hs360/features/customers/domain/customer_type.dart';

/// Local test double — never touches Supabase ([super(null)]).
class FakeCustomerRepository extends CustomerRepository {
  FakeCustomerRepository({
    List<Customer> customers = const [],
    this.fetchError,
    this.mutationError,
  })  : customers = List<Customer>.from(customers),
        super(null);

  List<Customer> customers;
  final Object? fetchError;
  final Object? mutationError;

  CustomerFilters? lastFilters;
  CustomerFormState? lastCreateInput;
  CustomerFormState? lastUpdateInput;
  String? lastUpdatedId;
  String? lastDeactivatedId;
  String? lastEnsureAccountId;
  int fetchCount = 0;
  int statementCallCount = 0;
  int balanceCallCount = 0;

  @override
  Future<List<Customer>> fetchCustomers(
    AppSession session,
    CustomerFilters filters,
  ) async {
    fetchCount++;
    lastFilters = filters;
    final error = fetchError;
    if (error != null) {
      if (error is CustomerException) throw error;
      throw const CustomerException(code: CustomerException.unknown);
    }
    return customers.where((c) {
      if (filters.isActive != null && c.isActive != filters.isActive) {
        return false;
      }
      if (filters.isVip != null && c.isVip != filters.isVip) return false;
      if (filters.customerType != null &&
          c.customerType != filters.customerType) {
        return false;
      }
      if (filters.governorate != null &&
          filters.governorate!.isNotEmpty &&
          c.governorate != filters.governorate) {
        return false;
      }
      if (filters.area != null &&
          filters.area!.isNotEmpty &&
          c.area != filters.area) {
        return false;
      }
      return true;
    }).toList();
  }

  @override
  Future<Customer?> fetchCustomerById(AppSession session, String id) async {
    final error = fetchError;
    if (error != null) {
      if (error is CustomerException) throw error;
      throw const CustomerException(code: CustomerException.unknown);
    }
    for (final c in customers) {
      if (c.id == id) return c;
    }
    return null;
  }

  @override
  Future<Customer> createCustomer(
    AppSession session,
    CustomerFormState input,
  ) async {
    final error = mutationError;
    if (error != null) {
      if (error is CustomerException) throw error;
      throw const CustomerException(code: CustomerException.unknown);
    }
    lastCreateInput = input;
    final created = sampleCustomer(
      id: 'new-customer',
      nameAr: input.nameAr,
      isVip: input.isVip,
      accountId: input.createAccount ? 'acc-new' : null,
    );
    customers = [...customers, created];
    return created;
  }

  @override
  Future<Customer> updateCustomer(
    AppSession session,
    String id,
    CustomerFormState input,
  ) async {
    final error = mutationError;
    if (error != null) {
      if (error is CustomerException) throw error;
      throw const CustomerException(code: CustomerException.unknown);
    }
    lastUpdateInput = input;
    lastUpdatedId = id;
    return sampleCustomer(id: id, nameAr: input.nameAr, isVip: input.isVip);
  }

  @override
  Future<Customer> deactivateCustomer(AppSession session, String id) async {
    final error = mutationError;
    if (error != null) {
      if (error is CustomerException) throw error;
      throw const CustomerException(code: CustomerException.unknown);
    }
    lastDeactivatedId = id;
    customers = [
      for (final c in customers)
        if (c.id == id) sampleCustomer(id: c.id, isActive: false) else c,
    ];
    return sampleCustomer(id: id, isActive: false);
  }

  @override
  Future<Customer> ensureCustomerAccount(AppSession session, String id) async {
    final error = mutationError;
    if (error != null) {
      if (error is CustomerException) throw error;
      throw const CustomerException(code: CustomerException.unknown);
    }
    lastEnsureAccountId = id;
    final linked = sampleCustomer(id: id, accountId: 'acc-$id');
    customers = [
      for (final c in customers) if (c.id == id) linked else c,
    ];
    return linked;
  }

  @override
  Future<List<CustomerStatementRow>> fetchCustomerStatement(
    AppSession session,
    String customerId, {
    DateTime? from,
    DateTime? to,
  }) async {
    statementCallCount++;
    throw StateError('M5 must not call fetchCustomerStatement');
  }

  @override
  Future<CustomerBalanceSummary> fetchCustomerBalanceSummary(
    AppSession session,
    String customerId,
  ) async {
    balanceCallCount++;
    throw StateError('M5 must not call fetchCustomerBalanceSummary');
  }
}

Customer sampleCustomer({
  String id = 'cust-1',
  String code = 'CUST-0001',
  String nameAr = 'عميل',
  bool isActive = true,
  bool isVip = false,
  CustomerType customerType = CustomerType.individual,
  String? accountId,
  String? governorate,
  String? area,
}) {
  return Customer(
    id: id,
    tenantId: 'tenant',
    code: code,
    customerType: customerType,
    nameAr: nameAr,
    phonePrimary: '99000000',
    accountId: accountId,
    governorate: governorate,
    area: area,
    isActive: isActive,
    isVip: isVip,
  );
}
