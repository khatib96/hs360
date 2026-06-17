import '../../finance_shared/domain/date_range.dart';
import '../../accounting/domain/journal_source.dart';

class JournalFilters {
  const JournalFilters({
    this.dateRange = const DateRange(),
    this.source,
    this.search,
  });

  final DateRange dateRange;
  final JournalSource? source;
  final String? search;

  bool get hasActiveFilters =>
      !dateRange.isEmpty || source != null || search?.trim().isNotEmpty == true;
}
