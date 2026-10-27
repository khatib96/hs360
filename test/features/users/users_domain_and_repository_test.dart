import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/users/data/users_repository.dart';
import 'package:hs360/features/users/domain/permission_catalog.dart';
import 'package:hs360/features/users/domain/users_permissions.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'users_test_support.dart';

void main() {
  group('permission catalog grouping', () {
    test('hides modules that are not built and orders categories', () {
      final groups = groupPermissionsForEditor(testCatalog);

      expect(groups.map((g) => g.category), ['sales', 'finance']);
      expect(
        groups.expand((g) => g.entries).map((e) => e.id),
        isNot(contains('hr.salaries.view')),
      );
    });

    test('labels fall back to English, then the id', () {
      const entry = PermissionCatalogEntry(
        id: 'x.view',
        category: 'core',
        labelAr: '',
        labelEn: '',
        isSensitive: false,
        sortOrder: 0,
      );
      expect(entry.label('ar'), 'x.view');
      expect(testCatalog.first.label('ar'), 'عرض العملاء');
    });
  });

  group('users permissions', () {
    test('non-managers can only change permissions they hold', () {
      final editor = testSession(
        isManager: false,
        permissions: {'settings.users.edit', 'customers.view'},
      );
      expect(canEditUserPermissions(editor), isTrue);
      expect(canChangePermission(editor, 'customers.view'), isTrue);
      expect(canChangePermission(editor, 'invoices.cancel'), isFalse);
      expect(canChangePermission(testSession(), 'invoices.cancel'), isTrue);
    });
  });

  group('UsersRepository', () {
    test('maps list_tenant_users rows', () async {
      final repository = UsersRepository(
        null,
        rpcInvoker: (name, params) async {
          expect(name, 'list_tenant_users');
          return [
            {
              'tenant_user_id': 'tu-1',
              'user_id': 'u-1',
              'display_name': 'Ahmad',
              'login': 'ahmad@company.local',
              'account_type': 'user',
              'is_active': true,
              'must_change_password': true,
              'is_self': false,
              'last_sign_in_at': null,
              'permission_ids': ['customers.view'],
            },
          ];
        },
      );

      final users = await repository.listUsers();
      expect(users.single.mustChangePassword, isTrue);
      expect(users.single.permissionIds, {'customers.view'});
      expect(users.single.lastSignInAt, isNull);
    });

    test('sends a sorted permission set', () async {
      Map<String, dynamic>? sent;
      final repository = UsersRepository(
        null,
        rpcInvoker: (name, params) async {
          sent = {'name': name, ...params};
          return {'added': [], 'removed': []};
        },
      );

      await repository.setPermissions('tu-1', {'b.view', 'a.view'});
      expect(sent?['name'], 'set_tenant_user_permissions');
      expect(sent?['p_permission_ids'], ['a.view', 'b.view']);
    });

    test('creates logins through the admin-users function', () async {
      Map<String, dynamic>? body;
      final repository = UsersRepository(
        null,
        functionInvoker: (value) async => body = value,
      );

      await repository.createUser(
        login: ' ahmad@company.local ',
        password: 'Initial-Pass-1',
        displayName: ' Ahmad ',
        asManager: false,
      );
      expect(body, {
        'action': 'create_user',
        'login': 'ahmad@company.local',
        'password': 'Initial-Pass-1',
        'display_name': 'Ahmad',
        'account_type': 'user',
      });
    });

    test('maps function and database errors to stable codes', () async {
      final taken = UsersRepository(
        null,
        functionInvoker: (_) async => throw const FunctionException(
          status: 409,
          details: {'error': 'login_taken'},
        ),
      );
      await expectLater(
        taken.changeOwnPassword('x' * 12),
        throwsA(
          isA<UsersException>().having(
            (e) => e.code,
            'code',
            UsersException.loginTaken,
          ),
        ),
      );

      final missing = UsersRepository(
        null,
        functionInvoker: (_) async =>
            throw const FunctionException(status: 404),
      );
      await expectLater(
        missing.changeOwnPassword('x' * 12),
        throwsA(
          isA<UsersException>().having(
            (e) => e.code,
            'code',
            UsersException.unavailable,
          ),
        ),
      );

      final notHeld = UsersRepository(
        null,
        rpcInvoker: (_, _) async =>
            throw const PostgrestException(message: 'permission_not_held'),
      );
      await expectLater(
        notHeld.setPermissions('tu-1', {'a.view'}),
        throwsA(
          isA<UsersException>().having(
            (e) => e.code,
            'code',
            UsersException.permissionNotHeld,
          ),
        ),
      );

      final denied = UsersRepository(
        null,
        rpcInvoker: (_, _) async => throw const PostgrestException(
          message: 'permission denied for function list_tenant_users',
          code: '42501',
        ),
      );
      await expectLater(
        denied.listUsers(),
        throwsA(
          isA<UsersException>().having(
            (e) => e.code,
            'code',
            UsersException.permissionDenied,
          ),
        ),
      );
    });
  });
}
