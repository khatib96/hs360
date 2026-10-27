import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/presentation/change_password_screen.dart';
import 'package:hs360/features/users/presentation/user_detail_screen.dart';
import 'package:hs360/features/users/presentation/users_screen.dart';

import 'users_test_support.dart';

Future<void> _pump(WidgetTester tester, Widget app) async {
  await tester.binding.setSurfaceSize(const Size(1280, 1000));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(app);
  await tester.pumpAndSettle();
}

void main() {
  group('UsersScreen', () {
    testWidgets('lists accounts with type, status and password badges', (
      tester,
    ) async {
      final repository = FakeUsersRepository(
        accounts: [
          testAccount(
            id: 'tu-self',
            name: 'Owner',
            accountType: 'manager',
            isSelf: true,
          ),
          testAccount(
            id: 'tu-2',
            name: 'Ahmad',
            mustChangePassword: true,
            permissionIds: {'customers.view', 'hr.salaries.view'},
          ),
          testAccount(id: 'tu-3', name: 'Sara', isActive: false),
        ],
      );

      await _pump(
        tester,
        usersTestApp(
          home: const UsersScreen(),
          session: testSession(),
          repository: repository,
        ),
      );

      expect(find.byKey(const Key('user-row-tu-2')), findsOneWidget);
      expect(find.text('Must change password'), findsOneWidget);
      expect(find.text('Inactive'), findsOneWidget);
      expect(find.text('You'), findsOneWidget);
      // Only offered permissions are counted (hr.* is hidden).
      expect(find.textContaining('1 permissions'), findsOneWidget);
      expect(find.byKey(const Key('users-add-command')), findsOneWidget);
      // Sara can sign in but has no permissions at all.
      expect(find.text('No permissions'), findsOneWidget);
    });

    testWidgets('hides Add user without the invite permission', (tester) async {
      await _pump(
        tester,
        usersTestApp(
          home: const UsersScreen(),
          session: testSession(
            isManager: false,
            permissions: {'settings.users.view'},
          ),
          repository: FakeUsersRepository(accounts: [testAccount()]),
        ),
      );

      expect(find.byKey(const Key('users-add-command')), findsNothing);
    });

    testWidgets('create dialog validates, then creates the login', (
      tester,
    ) async {
      final repository = FakeUsersRepository(accounts: [testAccount()]);
      await _pump(
        tester,
        usersTestApp(
          home: const UsersScreen(),
          session: testSession(),
          repository: repository,
        ),
      );

      await tester.tap(find.byKey(const Key('users-add-command')));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('create-user-name')),
          matching: find.byType(TextFormField),
        ),
        'Khaled',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('create-user-login')),
          matching: find.byType(TextFormField),
        ),
        'not-a-login',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('create-user-password')),
          matching: find.byType(TextFormField),
        ),
        'short',
      );
      await tester.tap(find.byKey(const Key('create-user-submit')));
      await tester.pumpAndSettle();

      expect(repository.created, isEmpty);
      expect(find.text('Use at least 10 characters'), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('create-user-login')),
          matching: find.byType(TextFormField),
        ),
        'khaled@company.local',
      );
      await tester.tap(find.byKey(const Key('generate-password')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('create-user-submit')));
      await tester.pumpAndSettle();

      expect(repository.created, hasLength(1));
      expect(repository.created.single['login'], 'khaled@company.local');
      expect(
        (repository.created.single['password'] as String).length,
        greaterThanOrEqualTo(10),
      );
      expect(repository.created.single['asManager'], isFalse);
    });
  });

  group('UserDetailScreen', () {
    testWidgets('saves the edited permission set', (tester) async {
      final repository = FakeUsersRepository(
        accounts: [
          testAccount(id: 'tu-2', permissionIds: {'hr.salaries.view'}),
        ],
      );
      await _pump(
        tester,
        usersTestApp(
          home: const UserDetailScreen(tenantUserId: 'tu-2'),
          session: testSession(),
          repository: repository,
        ),
      );

      await tester.tap(find.byKey(const Key('permission-customers.view')));
      await tester.pump();
      expect(find.text('1 unsaved changes'), findsOneWidget);

      await tester.tap(find.byKey(const Key('permissions-save')));
      await tester.pumpAndSettle();

      // Hidden permissions the editor does not show are kept as they were.
      expect(repository.savedPermissions['tu-2'], {
        'customers.view',
        'hr.salaries.view',
      });
    });

    testWidgets('search and sensitive-only filter the editor', (tester) async {
      await _pump(
        tester,
        usersTestApp(
          home: const UserDetailScreen(tenantUserId: 'tu-2'),
          session: testSession(),
          repository: FakeUsersRepository(
            accounts: [
              testAccount(id: 'tu-2', permissionIds: {'customers.view'}),
            ],
          ),
        ),
      );

      expect(find.text('1 of 2 granted'), findsOneWidget);

      await tester.tap(find.byKey(const Key('permissions-sensitive-only')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('permission-customers.view')), findsNothing);
      expect(
        find.byKey(const Key('permission-invoices.cancel')),
        findsOneWidget,
      );

      await tester.tap(find.byKey(const Key('permissions-sensitive-only')));
      await tester.enterText(
        find.byKey(const Key('permissions-search')),
        'custom',
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('permission-customers.view')),
        findsOneWidget,
      );
      expect(find.byKey(const Key('permission-invoices.cancel')), findsNothing);

      await tester.enterText(
        find.byKey(const Key('permissions-search')),
        'zzz',
      );
      await tester.pumpAndSettle();
      expect(find.text('No permissions match the search'), findsOneWidget);
    });

    testWidgets('a non-manager editor cannot grant permissions they lack', (
      tester,
    ) async {
      await _pump(
        tester,
        usersTestApp(
          home: const UserDetailScreen(tenantUserId: 'tu-2'),
          session: testSession(
            isManager: false,
            permissions: {
              'settings.users.view',
              'settings.users.edit',
              'customers.view',
            },
          ),
          repository: FakeUsersRepository(accounts: [testAccount(id: 'tu-2')]),
        ),
      );

      final held = tester.widget<CheckboxListTile>(
        find.byKey(const Key('permission-customers.view')),
      );
      final notHeld = tester.widget<CheckboxListTile>(
        find.byKey(const Key('permission-invoices.cancel')),
      );
      expect(held.onChanged, isNotNull);
      expect(notHeld.onChanged, isNull);
    });

    testWidgets('managers and the signed-in user have no editor', (
      tester,
    ) async {
      await _pump(
        tester,
        usersTestApp(
          home: const UserDetailScreen(tenantUserId: 'tu-m'),
          session: testSession(),
          repository: FakeUsersRepository(
            accounts: [testAccount(id: 'tu-m', accountType: 'manager')],
          ),
        ),
      );
      expect(
        find.text('Managers have every permission automatically.'),
        findsOneWidget,
      );
      expect(find.byKey(const Key('permissions-save')), findsNothing);
    });

    testWidgets('reset password and deactivate call the repository', (
      tester,
    ) async {
      final repository = FakeUsersRepository(
        accounts: [testAccount(id: 'tu-2')],
      );
      await _pump(
        tester,
        usersTestApp(
          home: const UserDetailScreen(tenantUserId: 'tu-2'),
          session: testSession(),
          repository: repository,
        ),
      );

      await tester.tap(find.byKey(const Key('user-reset-password')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('generate-password')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('reset-password-submit')));
      await tester.pumpAndSettle();
      expect(repository.resets.keys, ['tu-2']);

      await tester.tap(find.byKey(const Key('user-deactivate')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Deactivate user').last);
      await tester.pumpAndSettle();
      expect(repository.activeChanges, {'tu-2': false});
    });
  });

  group('ChangePasswordScreen', () {
    testWidgets('requires matching passwords of at least 10 characters', (
      tester,
    ) async {
      final repository = FakeUsersRepository();
      await _pump(
        tester,
        usersTestApp(
          home: const ChangePasswordScreen(),
          session: testSession(mustChangePassword: true),
          repository: repository,
        ),
      );

      expect(
        find.text(
          "For your account's security, choose a new password before you continue.",
        ),
        findsOneWidget,
      );
      expect(find.byKey(const Key('change-password-sign-out')), findsOneWidget);

      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('change-password-new')),
          matching: find.byType(TextFormField),
        ),
        'Employee-Own-22',
      );
      await tester.enterText(
        find.descendant(
          of: find.byKey(const Key('change-password-confirm')),
          matching: find.byType(TextFormField),
        ),
        'Employee-Own-23',
      );
      await tester.tap(find.byKey(const Key('change-password-submit')));
      await tester.pumpAndSettle();

      expect(find.text('Passwords do not match'), findsOneWidget);
      expect(repository.ownPasswords, isEmpty);
    });
  });
}
