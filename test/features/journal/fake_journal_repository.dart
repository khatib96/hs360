import 'package:decimal/decimal.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/finance_shared/domain/date_range.dart';
import 'package:hs360/features/finance_shared/domain/pagination_cursor.dart';
import 'package:hs360/features/journal/data/journal_repository.dart';
import 'package:hs360/features/journal/domain/cash_bank_activity_row.dart';
import 'package:hs360/features/journal/domain/journal_entry_detail.dart';
import 'package:hs360/features/journal/domain/journal_entry_summary.dart';
import 'package:hs360/features/journal/domain/journal_filters.dart';
import 'package:hs360/features/accounting/domain/journal_source.dart';

class FakeJournalRepository extends JournalRepository {
  FakeJournalRepository({
    List<JournalEntrySummary> entries = const [],
    this.fetchError,
    this.detailById = const {},
  }) : entries = List<JournalEntrySummary>.from(entries),
       super(null);

  List<JournalEntrySummary> entries;
  Object? fetchError;
  Map<String, JournalEntryDetail> detailById;

  JournalFilters? lastFilters;
  PaginationCursor? lastPage;

  @override
  Future<List<JournalEntrySummary>> listJournalEntries(
    AppSession session, {
    JournalFilters filters = const JournalFilters(),
    PaginationCursor page = const PaginationCursor(),
  }) async {
    _throwIfFetchError();
    lastFilters = filters;
    lastPage = page;
    if (page.offset >= entries.length) return const [];
    final end = page.offset + page.limit;
    return entries.sublist(
      page.offset,
      end > entries.length ? entries.length : end,
    );
  }

  @override
  Future<JournalEntryDetail?> fetchJournalEntryDetail(
    AppSession session,
    String entryId,
  ) async {
    _throwIfFetchError();
    return detailById[entryId];
  }

  void _throwIfFetchError() {
    final error = fetchError;
    if (error == null) return;
    if (error is FinanceException) throw error;
    throw const FinanceException(code: FinanceException.unknown);
  }
}

JournalEntrySummary sampleJournalEntrySummary({String id = 'je-1'}) {
  return JournalEntrySummary(
    id: id,
    entryNumber: 'JE-001',
    date: DateTime(2026, 6, 1),
    source: JournalSource.salesInvoice,
    isPosted: true,
    totalDebit: Decimal.parse('100.000'),
    totalCredit: Decimal.parse('100.000'),
  );
}

JournalEntryDetail sampleJournalEntryDetail({String id = 'je-1'}) {
  return JournalEntryDetail(
    summary: sampleJournalEntrySummary(id: id),
    lines: const [],
  );
}

class FakeCashBankRepository {
  FakeCashBankRepository({this.page});

  CashBankActivityPage? page;
  Object? fetchError;
  String? lastAccountId;
  DateRange? lastDateRange;

  Future<CashBankActivityPage> getCashBankActivity(
    AppSession session, {
    required String accountId,
    DateRange dateRange = const DateRange(),
    PaginationCursor page = const PaginationCursor(),
  }) async {
    lastAccountId = accountId;
    lastDateRange = dateRange;
    final error = fetchError;
    if (error != null) {
      if (error is FinanceException) throw error;
      throw const FinanceException(code: FinanceException.unknown);
    }
    return this.page ??
        CashBankActivityPage(
          accountId: accountId,
          accountCode: '1000',
          accountNameAr: 'صندوق',
          accountNameEn: 'Cash',
          openingBalance: Decimal.zero,
          limit: page.limit,
          offset: page.offset,
          rows: const [],
        );
  }
}
