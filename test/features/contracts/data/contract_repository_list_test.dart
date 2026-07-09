import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/contracts/data/contract_repository.dart';
import 'package:hs360/features/contracts/domain/contract_filters.dart';
import 'package:hs360/features/contracts/domain/contract_status.dart';
import 'package:hs360/features/contracts/domain/contract_summary.dart';
import 'package:hs360/features/contracts/domain/contract_type.dart';

import '../fake_contract_repository.dart';

AppSession _session(Set<String> permissions) {
  return AppSession(
    userId: 'user-1',
    email: 'user@example.com',
    tenantId: 'tenant-1',
    tenantUserId: 'tenant-user-1',
    accountType: 'user',
    displayName: 'User',
    preferredLocale: 'en',
    permissions: AppPermissions(isManager: false, permissions: permissions),
  );
}

void main() {
  group('ContractRepository list/detail', () {
    test('listContracts denies without contracts.view', () {
      final repo = ContractRepository(null);
      expect(
        () => repo.listContracts(_session({})),
        throwsA(
          isA<FinanceException>().having(
            (e) => e.code,
            'code',
            FinanceException.permissionDenied,
          ),
        ),
      );
    });

    test('fetchContractDetail denies without contracts.view', () {
      final repo = ContractRepository(null);
      expect(
        () => repo.fetchContractDetail(_session({}), 'contract-1'),
        throwsA(
          isA<FinanceException>().having(
            (e) => e.code,
            'code',
            FinanceException.permissionDenied,
          ),
        ),
      );
    });

    test('fake listContracts filters by customer and type', () async {
      final repo = FakeContractRepository(
        summaries: [
          sampleContractSummary(id: 'c-1'),
          ContractSummary(
            id: 'c-2',
            contractNumber: 'CON-002',
            type: ContractType.trial,
            status: ContractStatus.draft,
            startDate: DateTime(2026, 7, 1),
            customerId: 'cust-2',
          ),
        ],
      );

      final rows = await repo.listContracts(
        _session({'contracts.view'}),
        filters: const ContractFilters(
          customerId: 'cust-1',
          type: ContractType.rental,
        ),
      );

      expect(rows, hasLength(1));
      expect(rows.first.id, 'c-1');
    });

    test('fake fetchContractDetail returns mapped detail', () async {
      final repo = FakeContractRepository(
        detailById: {'c-1': sampleContractDetail(id: 'c-1')},
      );

      final detail = await repo.fetchContractDetail(
        _session({'contracts.view'}),
        'c-1',
      );

      expect(detail.id, 'c-1');
      expect(detail.contractNumber, 'CON-001');
    });
  });
}
