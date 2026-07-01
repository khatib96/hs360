import 'package:decimal/decimal.dart';
import 'package:hs360/features/accounting/domain/journal_source.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/finance_shared/domain/date_range.dart';
import 'package:hs360/features/finance_shared/domain/pagination_cursor.dart';
import 'package:hs360/features/journal/data/cash_bank_repository.dart';
import 'package:hs360/features/journal/domain/cash_bank_activity_row.dart';

class FakeCashBankRepository extends CashBankRepository {
  FakeCashBankRepository({this.pages = const []}) : super(null);

  final List<CashBankActivityPage> pages;
  PaginationCursor? lastPage;

  @override
  Future<CashBankActivityPage> getCashBankActivity(
    AppSession session, {
    required String accountId,
    DateRange dateRange = const DateRange(),
    PaginationCursor page = const PaginationCursor(),
  }) async {
    lastPage = page;
    final index = page.offset == 0 ? 0 : 1;
    if (index >= pages.length) {
      return CashBankActivityPage(
        accountId: accountId,
        accountCode: '1000',
        accountNameAr: 'نقد',
        accountNameEn: 'Cash',
        openingBalance: Decimal.zero,
        limit: page.limit,
        offset: page.offset,
        rows: const [],
      );
    }
    return pages[index];
  }
}

CashBankActivityPage sampleCashBankPage({
  required int rowCount,
  int limit = 51,
  int offset = 0,
}) {
  final rows = List.generate(
    rowCount,
    (index) => CashBankActivityRow(
      entryDate: DateTime(2026, 1, index + 1),
      entryNumber: 'JE-${index + 1}',
      source: JournalSource.receiptVoucher,
      sourceId: 'v-$index',
      description: 'Row $index',
      debit: Decimal.fromInt(10),
      credit: Decimal.zero,
      runningBalance: Decimal.fromInt(10 * (index + 1)),
    ),
  );

  return CashBankActivityPage(
    accountId: 'acct-1',
    accountCode: '1000',
    accountNameAr: 'نقد',
    accountNameEn: 'Cash',
    openingBalance: Decimal.zero,
    limit: limit,
    offset: offset,
    rows: rows,
  );
}
