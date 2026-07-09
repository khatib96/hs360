import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/accounting/domain/journal_source.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/journal/domain/journal_entry_summary.dart';
import 'package:hs360/features/journal/data/journal_repository.dart';
import 'package:hs360/features/journal/presentation/journal_list_controller.dart';

import '../fake_journal_repository.dart';

class TestAuthController extends AuthController {
  TestAuthController(this.session);
  final AppSession? session;
  @override
  FutureOr<AppSession?> build() => session;
}

AppSession _session({Set<String> permissions = const {'journal.view'}}) {
  return AppSession(
    userId: 'u',
    email: 'e@test.com',
    tenantId: 't',
    tenantUserId: 'tu',
    accountType: 'user',
    displayName: 'Test',
    preferredLocale: 'en',
    permissions: AppPermissions(isManager: false, permissions: permissions),
  );
}

List<JournalEntrySummary> _manyEntries(int count) {
  return List.generate(
    count,
    (index) => sampleJournalEntrySummary(id: 'je-$index'),
  );
}

void main() {
  group('JournalListController', () {
    test('setSource and setSearch update filters', () async {
      final repo = FakeJournalRepository(
        entries: [sampleJournalEntrySummary()],
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(_session()),
          ),
          journalRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(journalListControllerProvider.notifier);
      await notifier.refresh();

      notifier.setSource(JournalSource.receiptVoucher);
      await Future<void>.delayed(Duration.zero);
      notifier.setSearch('JE-001');
      await Future<void>.delayed(Duration.zero);

      expect(repo.lastFilters?.source, JournalSource.receiptVoucher);
      expect(repo.lastFilters?.search, 'JE-001');
    });

    test('setDateFrom and setDateTo update date range', () async {
      final repo = FakeJournalRepository(
        entries: [sampleJournalEntrySummary()],
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(_session()),
          ),
          journalRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(journalListControllerProvider.notifier);
      await notifier.refresh();

      final from = DateTime(2026, 1, 1);
      final to = DateTime(2026, 1, 31);
      notifier.setDateFrom(from);
      await Future<void>.delayed(Duration.zero);
      notifier.setDateTo(to);
      await Future<void>.delayed(Duration.zero);

      expect(repo.lastFilters?.dateRange.from, from);
      expect(repo.lastFilters?.dateRange.to, to);
    });

    test('loadMore requests next page when hasMore', () async {
      final repo = FakeJournalRepository(entries: _manyEntries(101));
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(_session()),
          ),
          journalRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      final notifier = container.read(journalListControllerProvider.notifier);
      await notifier.refresh();

      final afterRefresh = container.read(journalListControllerProvider);
      expect(afterRefresh.entries, hasLength(100));
      expect(afterRefresh.hasMore, isTrue);

      await notifier.loadMore();

      final afterLoadMore = container.read(journalListControllerProvider);
      expect(afterLoadMore.entries, hasLength(101));
      expect(repo.lastPage?.offset, 100);
    });
  });
}
