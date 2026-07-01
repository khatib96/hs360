import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/journal/data/journal_repository.dart';
import 'package:hs360/features/journal/presentation/journal_detail_controller.dart';

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

Future<void> _waitForDetail(ProviderContainer container, String id) async {
  await container.read(authControllerProvider.future);
  await container.read(journalDetailControllerProvider(id).notifier).load(id);
  for (var i = 0; i < 50; i++) {
    final state = container.read(journalDetailControllerProvider(id));
    if (!state.isLoading) return;
    await Future<void>.delayed(Duration.zero);
  }
  fail('timed out waiting for journal detail');
}

void main() {
  group('JournalDetailController', () {
    test('loads detail for permitted user', () async {
      final repo = FakeJournalRepository(
        detailById: {'je-1': sampleJournalEntryDetail()},
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

      await _waitForDetail(container, 'je-1');

      final state = container.read(journalDetailControllerProvider('je-1'));
      expect(state.detail?.summary.id, 'je-1');
      expect(state.errorCode, isNull);
    });

    test('returns not found when detail missing', () async {
      final repo = FakeJournalRepository();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(_session()),
          ),
          journalRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      await _waitForDetail(container, 'missing');

      expect(
        container.read(journalDetailControllerProvider('missing')).errorCode,
        FinanceException.notFound,
      );
    });

    test('denies load without journal.view', () async {
      final repo = FakeJournalRepository(
        detailById: {'je-1': sampleJournalEntryDetail()},
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(_session(permissions: {})),
          ),
          journalRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      await _waitForDetail(container, 'je-1');

      expect(
        container.read(journalDetailControllerProvider('je-1')).errorCode,
        FinanceException.permissionDenied,
      );
    });
  });
}
