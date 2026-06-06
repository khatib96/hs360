import 'package:hs360/core/errors/supplier_exception.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/suppliers/data/supplier_repository.dart';
import 'package:hs360/features/suppliers/domain/supplier.dart';
import 'package:hs360/features/suppliers/domain/supplier_filters.dart';
import 'package:hs360/features/suppliers/domain/supplier_form_state.dart';

/// Local test double — never touches Supabase ([super(null)]).
class FakeSupplierRepository extends SupplierRepository {
  FakeSupplierRepository({
    List<Supplier> suppliers = const [],
    this.fetchError,
    this.mutationError,
  }) : suppliers = List<Supplier>.from(suppliers),
       super(null);

  List<Supplier> suppliers;
  Object? fetchError;
  final Object? mutationError;

  SupplierFilters? lastFilters;
  int? lastOffset;
  int? lastLimit;
  SupplierFormState? lastCreateInput;
  SupplierFormState? lastUpdateInput;
  String? lastUpdatedId;
  String? lastDeactivatedId;
  String? lastEnsureAccountId;
  int fetchCount = 0;

  @override
  Future<List<Supplier>> fetchSuppliers(
    AppSession session,
    SupplierFilters filters, {
    int offset = 0,
    int limit = 100,
  }) async {
    fetchCount++;
    lastFilters = filters;
    lastOffset = offset;
    lastLimit = limit;
    final error = fetchError;
    if (error != null) {
      if (error is SupplierException) throw error;
      throw const SupplierException(code: SupplierException.unknown);
    }
    final filtered = suppliers.where((s) {
      if (filters.isActive != null && s.isActive != filters.isActive) {
        return false;
      }
      return true;
    }).toList();
    return filtered.skip(offset).take(limit).toList();
  }

  @override
  Future<Supplier?> fetchSupplierById(AppSession session, String id) async {
    for (final s in suppliers) {
      if (s.id == id) return s;
    }
    return null;
  }

  @override
  Future<Supplier> createSupplier(
    AppSession session,
    SupplierFormState input,
  ) async {
    final error = mutationError;
    if (error != null) {
      if (error is SupplierException) throw error;
      throw const SupplierException(code: SupplierException.unknown);
    }
    lastCreateInput = input;
    final created = sampleSupplier(
      id: 'new-supplier',
      nameAr: input.nameAr,
      accountId: input.createAccount ? 'acc-new' : null,
    );
    suppliers = [...suppliers, created];
    return created;
  }

  @override
  Future<Supplier> updateSupplier(
    AppSession session,
    String id,
    SupplierFormState input,
  ) async {
    final error = mutationError;
    if (error != null) {
      if (error is SupplierException) throw error;
      throw const SupplierException(code: SupplierException.unknown);
    }
    lastUpdateInput = input;
    lastUpdatedId = id;
    return sampleSupplier(id: id, nameAr: input.nameAr);
  }

  @override
  Future<Supplier> deactivateSupplier(AppSession session, String id) async {
    final error = mutationError;
    if (error != null) {
      if (error is SupplierException) throw error;
      throw const SupplierException(code: SupplierException.unknown);
    }
    lastDeactivatedId = id;
    suppliers = [
      for (final s in suppliers)
        if (s.id == id) sampleSupplier(id: s.id, isActive: false) else s,
    ];
    return sampleSupplier(id: id, isActive: false);
  }

  @override
  Future<Supplier> ensureSupplierAccount(AppSession session, String id) async {
    final error = mutationError;
    if (error != null) {
      if (error is SupplierException) throw error;
      throw const SupplierException(code: SupplierException.unknown);
    }
    lastEnsureAccountId = id;
    final linked = sampleSupplier(id: id, accountId: 'acc-$id');
    suppliers = [
      for (final s in suppliers)
        if (s.id == id) linked else s,
    ];
    return linked;
  }
}

Supplier sampleSupplier({
  String id = 'sup-1',
  String code = 'SUP-0001',
  String nameAr = 'مورّد',
  bool isActive = true,
  String? accountId,
  String? governorate,
  String? area,
}) {
  return Supplier(
    id: id,
    tenantId: 'tenant',
    code: code,
    nameAr: nameAr,
    accountId: accountId,
    governorate: governorate,
    area: area,
    isActive: isActive,
  );
}
