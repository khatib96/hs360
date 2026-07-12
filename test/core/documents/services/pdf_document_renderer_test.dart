import 'package:decimal/decimal.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:hs360/core/documents/domain/document_kind.dart';
import 'package:hs360/core/documents/domain/document_payload.dart';
import 'package:hs360/core/documents/services/document_render_service.dart';
import 'package:hs360/features/contracts/domain/contract_document_fixture.dart';
import 'package:hs360/features/invoices/domain/sales_invoice_document_fixture.dart';

import 'pdf/test_render_helpers.dart';

StatementPayload _largeStatementPayload(int lineCount) {
  final lines = List<StatementLine>.generate(lineCount, (index) {
    final day = (index % 28) + 1;
    final month = (index % 12) + 1;
    final debit = index.isEven ? Decimal.parse('10.000') : Decimal.zero;
    final credit = index.isOdd ? Decimal.parse('5.000') : Decimal.zero;
    final balance =
        Decimal.parse('100.000') +
        Decimal.parse((index * 2.5).toStringAsFixed(3));
    return StatementLine(
      entryDate: DateTime(2025, month, day),
      entryNumber: 'JE-${index.toString().padLeft(5, '0')}',
      source: 'journal_entry',
      description: 'Movement $index',
      debit: debit,
      credit: credit,
      runningBalance: balance,
    );
  });

  return StatementPayload(
    customer: const {
      'id': 'c1',
      'code': 'C-001',
      'name_ar': 'عميل كبير',
      'name_en': 'Large Customer',
    },
    fromDate: DateTime(2025, 1, 1),
    toDate: DateTime(2025, 12, 31),
    generatedAt: DateTime(2026, 6, 1),
    summary: StatementSummary(
      openingBalance: Decimal.parse('100.000'),
      totalDebit: Decimal.parse('${lineCount ~/ 2 * 10}.000'),
      totalCredit: Decimal.parse('${(lineCount + 1) ~/ 2 * 5}.000'),
      closingBalance: Decimal.parse('1000.000'),
    ),
    lines: lines,
    rowCount: lineCount,
  );
}

ContractPayload _largeContractPayload(int lineCount) {
  final fixture = contractDocumentFixture();
  return ContractPayload(
    document: fixture.document,
    party: fixture.party,
    location: fixture.location,
    lines: List.generate(lineCount, (index) {
      return {
        'product_name': 'Rental product ${index + 1}',
        'serial': 'SN-${(index + 1).toString().padLeft(4, '0')}',
        'qty': Decimal.one,
        'unit': 'piece',
      };
    }),
    totals: fixture.totals,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('en');
    await initializeDateFormatting('ar');
  });

  test('invoice fixture renders non-empty PDF bytes', () async {
    final service = DocumentRenderService();
    final result = await service.render(
      context: testContext(kind: DocumentKind.salesInvoice),
      payload: salesInvoiceDocumentFixture(),
      userLocale: 'en',
    );
    expect(result.bytes, isNotEmpty);
    expect(result.pageCount, greaterThanOrEqualTo(1));
  });

  test('contract fixture renders non-empty PDF bytes', () async {
    final service = DocumentRenderService();
    final result = await service.render(
      context: testContext(kind: DocumentKind.contract),
      payload: contractDocumentFixture(),
      userLocale: 'en',
    );
    expect(result.bytes, isNotEmpty);
    expect(result.pageCount, greaterThanOrEqualTo(1));
  });

  test('draft contract PDF includes watermark overlay bytes', () async {
    final service = DocumentRenderService();
    final approved = await service.render(
      context: testContext(kind: DocumentKind.contract),
      payload: contractDocumentFixture(),
      userLocale: 'en',
    );
    final draftPayload = ContractPayload(
      document: {...contractDocumentFixture().document, 'is_draft': true},
      party: contractDocumentFixture().party,
      location: contractDocumentFixture().location,
      lines: contractDocumentFixture().lines,
      totals: contractDocumentFixture().totals,
    );
    final draft = await service.render(
      context: testContext(kind: DocumentKind.contract),
      payload: draftPayload,
      userLocale: 'en',
    );

    expect(draft.bytes, isNotEmpty);
    expect(draft.bytes, isNot(equals(approved.bytes)));
  });

  test('Arabic statement smoke renders non-empty bytes', () async {
    final service = DocumentRenderService();
    final result = await service.render(
      context: testContext(kind: DocumentKind.customerStatement),
      payload: arabicStatementPayload(),
      userLocale: 'ar',
    );
    expect(result.bytes, isNotEmpty);
  });

  test('Arabic contract smoke renders non-empty bytes', () async {
    final service = DocumentRenderService();
    final result = await service.render(
      context: testContext(kind: DocumentKind.contract),
      payload: contractDocumentFixture(),
      userLocale: 'ar',
    );
    expect(result.bytes, isNotEmpty);
  });

  test('contract PDF renders 40 product lines across multiple pages', () async {
    final service = DocumentRenderService();
    final result = await service.render(
      context: testContext(kind: DocumentKind.contract),
      payload: _largeContractPayload(40),
      userLocale: 'en',
    );

    expect(result.bytes, isNotEmpty);
    expect(result.pageCount, greaterThan(1));
  });

  test(
    'statement PDF renders 1000 lines within perf budget',
    () async {
      const lineCount = 1000;
      final service = DocumentRenderService();
      final stopwatch = Stopwatch()..start();
      final result = await service.render(
        context: testContext(kind: DocumentKind.customerStatement),
        payload: _largeStatementPayload(lineCount),
        userLocale: 'en',
      );
      stopwatch.stop();

      expect(result.bytes, isNotEmpty);
      expect(result.pageCount, greaterThan(1));
      expect(
        stopwatch.elapsed,
        lessThan(const Duration(seconds: 45)),
        reason:
            '1000-line statement exceeded perf budget (m3_statement_row_limit)',
      );
    },
    timeout: const Timeout(Duration(seconds: 120)),
  );
}
