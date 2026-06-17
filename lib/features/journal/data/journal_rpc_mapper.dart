import 'package:decimal/decimal.dart';

import '../../../core/utils/decimal_parser.dart';
import '../../accounting/domain/journal_source.dart';
import '../domain/journal_entry_summary.dart';

JournalEntrySummary mapJournalEntryListRow(Map<String, dynamic> row) {
  final linesRaw = row['journal_lines'];
  var totalDebit = Decimal.zero;
  var totalCredit = Decimal.zero;
  if (linesRaw is List) {
    for (final line in linesRaw) {
      if (line is Map) {
        totalDebit += parseDecimal(line['debit'] ?? 0);
        totalCredit += parseDecimal(line['credit'] ?? 0);
      }
    }
  }

  return JournalEntrySummary(
    id: row['id'] as String,
    entryNumber: row['entry_number'] as String,
    date: DateTime.parse(row['date'] as String),
    source: JournalSource.fromDb(row['source'] as String?),
    sourceId: row['source_id'] as String?,
    descriptionAr: row['description_ar'] as String?,
    descriptionEn: row['description_en'] as String?,
    isPosted: row['is_posted'] as bool? ?? false,
    totalDebit: totalDebit,
    totalCredit: totalCredit,
    reversalOfEntryId: row['reversal_of_entry_id'] as String?,
    reversedByEntryId: row['reversed_by_entry_id'] as String?,
  );
}

abstract final class JournalEntryListColumns {
  static const list = '''
id, entry_number, date, source, source_id,
description_ar, description_en, is_posted,
reversal_of_entry_id, reversed_by_entry_id,
journal_lines (debit, credit)
''';
}
