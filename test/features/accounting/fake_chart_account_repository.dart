import 'package:hs360/core/errors/accounting_exception.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/accounting/data/chart_account_repository.dart';
import 'package:hs360/features/accounting/domain/account_type.dart';
import 'package:hs360/features/accounting/domain/chart_account.dart';
import 'package:hs360/features/accounting/domain/chart_account_form_state.dart';

class FakeChartAccountRepository extends ChartAccountRepository {
  FakeChartAccountRepository({
    List<ChartAccount> accounts = const [],
    this.fetchError,
    this.mutationError,
  }) : accounts = List<ChartAccount>.from(accounts),
       super(null);

  List<ChartAccount> accounts;
  final Object? fetchError;
  final Object? mutationError;

  int fetchCount = 0;
  ChartAccountFormState? lastCreateInput;
  ChartAccountFormState? lastUpdateInput;
  String? lastUpdatedId;
  String? lastDeactivatedId;

  @override
  Future<List<ChartAccount>> fetchChartAccounts(
    AppSession session, {
    AccountType? type,
    bool? isActive,
  }) async {
    fetchCount++;
    if (fetchError != null) {
      if (fetchError is AccountingException) throw fetchError!;
      throw const AccountingException(code: AccountingException.unknown);
    }
    return accounts.where((a) {
      if (type != null && a.type != type) return false;
      if (isActive != null && a.isActive != isActive) return false;
      return true;
    }).toList();
  }

  @override
  Future<ChartAccount> createChartAccount(
    AppSession session,
    ChartAccountFormState input,
  ) async {
    if (mutationError != null) {
      if (mutationError is AccountingException) throw mutationError!;
      throw const AccountingException(code: AccountingException.unknown);
    }
    lastCreateInput = input;
    final created = ChartAccount(
      id: 'new-${accounts.length}',
      tenantId: session.tenantId,
      code: input.code!,
      nameAr: input.nameAr,
      nameEn: input.nameEn,
      type: input.type,
      parentId: input.parentId,
      isSubaccount: input.parentId != null,
      isActive: true,
      isSystem: false,
    );
    accounts.add(created);
    return created;
  }

  @override
  Future<ChartAccount> updateChartAccount(
    AppSession session,
    String id,
    ChartAccountFormState input,
  ) async {
    if (mutationError != null) {
      if (mutationError is AccountingException) throw mutationError!;
      throw const AccountingException(code: AccountingException.unknown);
    }
    lastUpdatedId = id;
    lastUpdateInput = input;
    final index = accounts.indexWhere((a) => a.id == id);
    if (index < 0) {
      throw const AccountingException(
        code: AccountingException.validationFailed,
      );
    }
    final current = accounts[index];
    final updated = ChartAccount(
      id: current.id,
      tenantId: current.tenantId,
      code: current.code,
      nameAr: input.nameAr,
      nameEn: input.nameEn,
      type: input.type,
      parentId: current.parentId,
      isSubaccount: current.isSubaccount,
      relatedEntityTable: current.relatedEntityTable,
      relatedEntityId: current.relatedEntityId,
      isActive: current.isActive,
      isSystem: current.isSystem,
    );
    accounts[index] = updated;
    return updated;
  }

  @override
  Future<ChartAccount> deactivateChartAccount(
    AppSession session,
    String id,
  ) async {
    if (mutationError != null) {
      if (mutationError is AccountingException) throw mutationError!;
      throw const AccountingException(code: AccountingException.unknown);
    }
    lastDeactivatedId = id;
    final index = accounts.indexWhere((a) => a.id == id);
    if (index < 0) {
      throw const AccountingException(
        code: AccountingException.validationFailed,
      );
    }
    final current = accounts[index];
    final updated = ChartAccount(
      id: current.id,
      tenantId: current.tenantId,
      code: current.code,
      nameAr: current.nameAr,
      nameEn: current.nameEn,
      type: current.type,
      parentId: current.parentId,
      isSubaccount: current.isSubaccount,
      relatedEntityTable: current.relatedEntityTable,
      relatedEntityId: current.relatedEntityId,
      isActive: false,
      isSystem: current.isSystem,
    );
    accounts[index] = updated;
    return updated;
  }
}

ChartAccount sampleChartAccount({
  String id = 'acct-1',
  String code = '3100',
  String? parentId,
  AccountType type = AccountType.expense,
  String nameEn = 'Sample',
  String nameAr = 'عينة',
  bool isSystem = false,
  bool isActive = true,
  String? relatedEntityId,
  String? relatedEntityTable,
}) {
  return ChartAccount(
    id: id,
    tenantId: 'tenant-1',
    code: code,
    nameAr: nameAr,
    nameEn: nameEn,
    type: type,
    parentId: parentId,
    isSubaccount: parentId != null,
    relatedEntityTable: relatedEntityTable,
    relatedEntityId: relatedEntityId,
    isActive: isActive,
    isSystem: isSystem,
  );
}
