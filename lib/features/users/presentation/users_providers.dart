import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/users_repository.dart';
import '../domain/permission_catalog.dart';
import '../domain/tenant_user_account.dart';

final tenantUsersProvider = FutureProvider.autoDispose<List<TenantUserAccount>>(
  (ref) => ref.watch(usersRepositoryProvider).listUsers(),
);

final permissionCatalogProvider =
    FutureProvider.autoDispose<List<PermissionCatalogEntry>>(
      (ref) => ref.watch(usersRepositoryProvider).loadPermissionCatalog(),
    );
