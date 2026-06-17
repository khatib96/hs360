import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/finance_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/journal_repository.dart';
import '../domain/journal_permissions.dart';
import 'journal_detail_state.dart';

part 'journal_detail_controller.g.dart';

@riverpod
class JournalDetailController extends _$JournalDetailController {
  @override
  JournalDetailState build(String entryId) {
    Future.microtask(() => load(entryId));
    return const JournalDetailState(isLoading: true);
  }

  Future<void> load(String entryId) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null || !canViewJournal(session)) {
      state = const JournalDetailState(
        isLoading: false,
        errorCode: FinanceException.permissionDenied,
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final detail = await ref
          .read(journalRepositoryProvider)
          .fetchJournalEntryDetail(session, entryId);
      if (detail == null) {
        state = const JournalDetailState(
          isLoading: false,
          errorCode: FinanceException.notFound,
        );
        return;
      }
      state = JournalDetailState(isLoading: false, detail: detail);
    } on FinanceException catch (e) {
      state = JournalDetailState(isLoading: false, errorCode: e.code);
    } catch (_) {
      state = const JournalDetailState(
        isLoading: false,
        errorCode: FinanceException.unknown,
      );
    }
  }
}
