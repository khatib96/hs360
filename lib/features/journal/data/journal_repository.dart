import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors/finance_exception.dart';
import '../../../core/network/supabase_providers.dart';
import '../../auth/domain/app_session.dart';
import '../../finance_shared/domain/date_range.dart';
import '../../finance_shared/domain/pagination_cursor.dart';
import '../domain/journal_entry_detail.dart';
import '../domain/journal_entry_summary.dart';
import '../domain/journal_filters.dart';
import '../domain/journal_line.dart';
import '../domain/journal_permissions.dart';
import 'journal_rpc_mapper.dart';

part 'journal_repository.g.dart';

@Riverpod(keepAlive: true)
JournalRepository journalRepository(Ref ref) {
  final client = ref.watch(supabaseClientProvider);
  return JournalRepository(client);
}

class JournalRepository {
  JournalRepository(this._client);

  static const maxListEntries = 100;

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) throw FinanceException.notConfigured();
    return client;
  }

  void _assertCanView(AppSession session) {
    if (!canViewJournal(session)) {
      throw const FinanceException(code: FinanceException.permissionDenied);
    }
  }

  Future<List<JournalEntrySummary>> listJournalEntries(
    AppSession session, {
    JournalFilters filters = const JournalFilters(),
    PaginationCursor page = const PaginationCursor(),
  }) async {
    _assertCanView(session);
    try {
      var query = _requireClient
          .from('journal_entries')
          .select(JournalEntryListColumns.list);

      if (filters.source != null) {
        query = query.eq('source', filters.source!.toDb());
      }
      if (filters.dateRange.from != null) {
        query = query.gte('date', dateRangeToIsoDate(filters.dateRange.from)!);
      }
      if (filters.dateRange.to != null) {
        query = query.lte('date', dateRangeToIsoDate(filters.dateRange.to)!);
      }
      final search = filters.search?.trim();
      if (search != null && search.isNotEmpty) {
        query = query.or(
          'entry_number.ilike.%$search%,description_ar.ilike.%$search%,description_en.ilike.%$search%',
        );
      }

      final rows = await query
          .order('date', ascending: false)
          .order('entry_number', ascending: false)
          .range(page.offset, page.offset + page.limit - 1);

      return (rows as List)
          .map((r) => mapJournalEntryListRow(Map<String, dynamic>.from(r)))
          .toList();
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }

  Future<JournalEntryDetail?> fetchJournalEntryDetail(
    AppSession session,
    String entryId,
  ) async {
    _assertCanView(session);
    try {
      final entryRow = await _requireClient
          .from('journal_entries')
          .select(JournalEntryColumns.detail)
          .eq('id', entryId)
          .maybeSingle();

      if (entryRow == null) return null;

      final lineRows = await _requireClient
          .from('journal_lines')
          .select(JournalLineColumns.list)
          .eq('journal_entry_id', entryId)
          .order('line_order');

      final lines = (lineRows as List)
          .map((r) => JournalLine.fromRow(Map<String, dynamic>.from(r)))
          .toList();

      return JournalEntryDetail.fromRow(
        Map<String, dynamic>.from(entryRow),
        lines,
      );
    } catch (e, st) {
      throw FinanceException.fromSupabase(e, st);
    }
  }
}
