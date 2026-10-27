import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/users/data/users_repository.dart';
import 'package:hs360/features/users/domain/permission_catalog.dart';
import 'package:hs360/features/users/domain/tenant_user_account.dart';
import 'package:hs360/l10n/app_localizations.dart';

class TestAuth extends AuthController {
  TestAuth(this.session);
  final AppSession session;

  @override
  FutureOr<AppSession?> build() => session;
}

AppSession testSession({
  bool isManager = true,
  Set<String> permissions = const {},
  bool mustChangePassword = false,
}) {
  return AppSession(
    userId: 'user-self',
    email: 'self@company.local',
    tenantId: 'tenant-1',
    tenantUserId: 'tu-self',
    accountType: isManager ? 'manager' : 'user',
    displayName: 'Self',
    preferredLocale: 'en',
    permissions: AppPermissions(isManager: isManager, permissions: permissions),
    mustChangePassword: mustChangePassword,
  );
}

TenantUserAccount testAccount({
  String id = 'tu-1',
  String name = 'Ahmad',
  String accountType = 'user',
  bool isActive = true,
  bool isSelf = false,
  bool mustChangePassword = false,
  Set<String> permissionIds = const {},
}) {
  return TenantUserAccount(
    tenantUserId: id,
    userId: 'user-$id',
    displayName: name,
    login: '${name.toLowerCase()}@company.local',
    accountType: accountType,
    isActive: isActive,
    mustChangePassword: mustChangePassword,
    isSelf: isSelf,
    permissionIds: permissionIds,
  );
}

const testCatalog = [
  PermissionCatalogEntry(
    id: 'customers.view',
    category: 'sales',
    labelAr: 'عرض العملاء',
    labelEn: 'View customers',
    isSensitive: false,
    sortOrder: 1,
  ),
  PermissionCatalogEntry(
    id: 'invoices.cancel',
    category: 'finance',
    labelAr: 'إلغاء الفواتير',
    labelEn: 'Cancel invoices',
    isSensitive: true,
    sortOrder: 2,
  ),
  PermissionCatalogEntry(
    id: 'hr.salaries.view',
    category: 'hr',
    labelAr: 'عرض الرواتب',
    labelEn: 'View salaries',
    isSensitive: true,
    sortOrder: 3,
  ),
];

class FakeUsersRepository extends UsersRepository {
  FakeUsersRepository({this.accounts = const [], this.failWith}) : super(null);

  List<TenantUserAccount> accounts;
  final UsersException? failWith;
  final savedPermissions = <String, Set<String>>{};
  final activeChanges = <String, bool>{};
  final created = <Map<String, Object>>[];
  final resets = <String, String>{};
  final ownPasswords = <String>[];

  void _maybeFail() {
    final error = failWith;
    if (error != null) throw error;
  }

  @override
  Future<List<TenantUserAccount>> listUsers() async => accounts;

  @override
  Future<List<PermissionCatalogEntry>> loadPermissionCatalog() async =>
      testCatalog;

  @override
  Future<void> setPermissions(
    String tenantUserId,
    Set<String> permissionIds,
  ) async {
    _maybeFail();
    savedPermissions[tenantUserId] = {...permissionIds};
  }

  @override
  Future<void> setActive(String tenantUserId, bool isActive) async {
    _maybeFail();
    activeChanges[tenantUserId] = isActive;
  }

  @override
  Future<void> createUser({
    required String login,
    required String password,
    required String displayName,
    required bool asManager,
  }) async {
    _maybeFail();
    created.add({
      'login': login,
      'password': password,
      'displayName': displayName,
      'asManager': asManager,
    });
  }

  @override
  Future<void> resetPassword({
    required String tenantUserId,
    required String password,
  }) async {
    _maybeFail();
    resets[tenantUserId] = password;
  }

  @override
  Future<void> changeOwnPassword(String password) async {
    _maybeFail();
    ownPasswords.add(password);
  }
}

Widget usersTestApp({
  required Widget home,
  required AppSession session,
  required UsersRepository repository,
}) {
  return ProviderScope(
    overrides: [
      authControllerProvider.overrideWith(() => TestAuth(session)),
      usersRepositoryProvider.overrideWithValue(repository),
    ],
    child: MaterialApp(
      locale: const Locale('en'),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: home,
    ),
  );
}
