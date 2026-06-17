import 'journal_entry_summary.dart';
import 'journal_line.dart';

class JournalEntryDetail {
  const JournalEntryDetail({
    required this.summary,
    required this.lines,
    this.postedAt,
    this.postedBy,
    this.createdAt,
    this.createdBy,
  });

  final JournalEntrySummary summary;
  final List<JournalLine> lines;
  final DateTime? postedAt;
  final String? postedBy;
  final DateTime? createdAt;
  final String? createdBy;

  factory JournalEntryDetail.fromRow(
    Map<String, dynamic> entryRow,
    List<JournalLine> lines,
  ) {
    return JournalEntryDetail(
      summary: JournalEntrySummary.fromRow(entryRow),
      lines: lines,
      postedAt: entryRow['posted_at'] != null
          ? DateTime.parse(entryRow['posted_at'] as String)
          : null,
      postedBy: entryRow['posted_by'] as String?,
      createdAt: entryRow['created_at'] != null
          ? DateTime.parse(entryRow['created_at'] as String)
          : null,
      createdBy: entryRow['created_by'] as String?,
    );
  }
}
