import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/features/contracts/domain/contract_detail.dart';
import 'package:hs360/features/contracts/domain/contract_print_support.dart';
import 'package:hs360/features/contracts/domain/contract_status.dart';
import 'package:hs360/features/contracts/domain/contract_type.dart';

void main() {
  test('documentKindForContract returns contract kind', () {
    expect(documentKindForContract(), DocumentKind.contract);
  });

  test('isContractPrintable is always true', () {
    final detail = ContractDetail(
      id: 'c-1',
      type: ContractType.trial,
      status: ContractStatus.draft,
      startDate: DateTime(2026, 1, 1),
    );
    expect(isContractPrintable(detail), isTrue);
  });
}
