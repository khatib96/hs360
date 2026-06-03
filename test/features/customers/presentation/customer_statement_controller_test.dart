import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/customer_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/customers/data/customer_repository.dart';
import 'package:hs360/features/customers/presentation/customer_statement_controller.dart';

import '../fake_customer_repository.dart';

void main() {
  AppSession session({Set<String> permissions = const {}}) {
    return AppSession(
      userId: 'user-1',
      email: 'test@example.com',
      tenantId: 'tenant-1',
      tenantUserId: 'tu-1',
      accountType: 'user',
      displayName: 'Test User',
      preferredLocale: 'en',
      permissions: AppPermissions(
        isManager: false,
        permissions: permissions,
      ),
    );
  }

  ProviderContainer container({
    required FakeCustomerRepository repo,
    required AppSession appSession,
  }) {
    return ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(
          () => _TestAuthController(appSession),
        ),
        customerRepositoryProvider.overrideWith((ref) => repo),
      ],
    );
  }

  Future<void> ready(ProviderContainer c) async {
    await c.read(authControllerProvider.future);
  }

  test('load respects hasLoaded guard', () async {
    final repo = FakeCustomerRepository();
    final c = container(
      repo: repo,
      appSession: session(permissions: {
        'customers.view_ledger',
      }),
    );
    addTearDown(c.dispose);
    await ready(c);

    final notifier =
        c.read(customerStatementControllerProvider('cust-1').notifier);
    await notifier.load();
    expect(repo.statementCallCount, 1);
    expect(repo.balanceCallCount, 1);

    await notifier.load();
    expect(repo.statementCallCount, 1);
    expect(repo.balanceCallCount, 1);
  });

  test('permission denied sets hasLoaded without repository calls', () async {
    final repo = FakeCustomerRepository();
    final c = container(repo: repo, appSession: session());
    addTearDown(c.dispose);
    await ready(c);

    final notifier =
        c.read(customerStatementControllerProvider('cust-1').notifier);
    await notifier.load();

    expect(repo.statementCallCount, 0);
    expect(repo.balanceCallCount, 0);
    final state = c.read(customerStatementControllerProvider('cust-1'));
    expect(state.permissionDenied, isTrue);
    expect(state.hasLoaded, isTrue);
  });

  test('fetch error leaves hasLoaded false and force retry works', () async {
    final repo = FakeCustomerRepository(
      balanceError: const CustomerException(code: CustomerException.unknown),
    );
    final c = container(
      repo: repo,
      appSession: session(permissions: {'customers.view_ledger'}),
    );
    addTearDown(c.dispose);
    await ready(c);

    final notifier =
        c.read(customerStatementControllerProvider('cust-1').notifier);
    await notifier.load();

    var state = c.read(customerStatementControllerProvider('cust-1'));
    expect(state.hasLoaded, isFalse);
    expect(state.errorCode, CustomerException.unknown);
    expect(repo.balanceCallCount, 1);
    expect(repo.statementCallCount, 0);

    repo.balanceError = null;
    await notifier.load(force: true);

    state = c.read(customerStatementControllerProvider('cust-1'));
    expect(state.hasLoaded, isTrue);
    expect(state.errorCode, isNull);
    expect(repo.statementCallCount, 1);
  });
}

class _TestAuthController extends AuthController {
  _TestAuthController(this.session);

  final AppSession session;

  @override
  FutureOr<AppSession?> build() => session;
}
