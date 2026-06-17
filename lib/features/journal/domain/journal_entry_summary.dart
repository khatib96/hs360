import 'package:decimal/decimal.dart';

import '../../../core/utils/decimal_parser.dart';
import '../../accounting/domain/journal_source.dart';

class JournalEntrySummary {
  const JournalEntrySummary({
    required this.id,
    required this.entryNumber,
    required this.date,
    required this.source,
    this.sourceId,
    this.descriptionAr,
    this.descriptionEn,
    required this.isPosted,
    required this.totalDebit,
    required this.totalCredit,
    this.reversalOfEntryId,
    this.reversedByEntryId,
  });

  final String id;
  final String entryNumber;
  final DateTime date;
  final JournalSource source;
  final String? sourceId;
  final String? descriptionAr;
  final String? descriptionEn;
  final bool isPosted;
  final Decimal totalDebit;
  final Decimal totalCredit;
  final String? reversalOfEntryId;
  final String? reversedByEntryId;

  factory JournalEntrySummary.fromRow(Map<String, dynamic> row) {
    return JournalEntrySummary(
      id: row['id'] as String,
      entryNumber: row['entry_number'] as String,
      date: DateTime.parse(row['date'] as String),
      source: JournalSource.fromDb(row['source'] as String?),
      sourceId: row['source_id'] as String?,
      descriptionAr: row['description_ar'] as String?,
      descriptionEn: row['description_en'] as String?,
      isPosted: row['is_posted'] as bool? ?? false,
      totalDebit: parseDecimal(row['total_debit'] ?? 0),
      totalCredit: parseDecimal(row['total_credit'] ?? 0),
      reversalOfEntryId: row['reversal_of_entry_id'] as String?,
      reversedByEntryId: row['reversed_by_entry_id'] as String?,
    );
  }
}

abstract final class JournalEntryColumns {
  static const list = '''
id, entry_number, date, source, source_id,
description_ar, description_en, is_posted,
reversal_of_entry_id, reversed_by_entry_id
''';

  static const detail = '''
id, entry_number, date, source, source_id,
description_ar, description_en, is_posted,
posted_at, posted_by, created_at, created_by,
reversal_of_entry_id, reversed_by_entry_id
''';
}
