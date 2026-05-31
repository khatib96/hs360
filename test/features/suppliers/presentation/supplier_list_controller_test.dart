import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/supplier_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/suppliers/data/supplier_repository.dart';
import 'package:hs360/features/suppliers/domain/supplier_form_state.dart';
import 'package:hs360/features/suppliers/presentation/supplier_list_controller.dart';

import '../fake_supplier_repository.dart';

AppSession _session({Set<String> permissions = const {'suppliers.view'}}) {
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

class TestAuthController extends AuthController {
  TestAuthController(this.session);

  final AppSession? session;

  @override
  FutureOr<AppSession?> build() => session;
}

ProviderContainer _container(
  FakeSupplierRepository repo, {
  Set<String> permissions = const {'suppliers.view'},
}) {
  return ProviderContainer(
    overrides: [
      authControllerProvider
          .overrideWith(() => TestAuthController(_session(permissions: permissions))),
      supplierRepositoryProvider.overrideWith((ref) => repo),
    ],
  );
}

void main() {
  group('SupplierListController', () {
    test('default filter is active-only', () async {
      final repo = FakeSupplierRepository(suppliers: [sampleSupplier()]);
      final container = _container(repo);
      addTearDown(container.dispose);

      await container.read(supplierListControllerProvider.notifier).refresh();

      expect(repo.lastFilters?.isActive, isTrue);
      expect(container.read(supplierListControllerProvider).suppliers,
          hasLength(1));
    });

    test('create denied without create permission', () async {
      final repo = FakeSupplierRepository();
      final container = _container(repo, permissions: {'suppliers.view'});
      addTearDown(container.dispose);

      final code = await container
          .read(supplierListControllerProvider.notifier)
          .createSupplier(const SupplierFormState(nameAr: 'مورّد'));

      expect(code, SupplierException.permissionDenied);
      expect(repo.lastCreateInput, isNull);
    });

    test('create succeeds and refreshes', () async {
      final repo = FakeSupplierRepository();
      final container = _container(
        repo,
        permissions: {'suppliers.view', 'suppliers.create'},
      );
      addTearDown(container.dispose);

      final code = await container
          .read(supplierListControllerProvider.notifier)
          .createSupplier(const SupplierFormState(nameAr: 'مورّد جديد'));

      expect(code, isNull);
      expect(repo.lastCreateInput?.nameAr, 'مورّد جديد');
      expect(container.read(supplierListControllerProvider).suppliers,
          hasLength(1));
    });

    test('deactivate removes supplier from active-only list', () async {
      final repo = FakeSupplierRepository(
        suppliers: [sampleSupplier(id: 'sup-1')],
      );
      final container = _container(
        repo,
        permissions: {'suppliers.view', 'suppliers.delete'},
      );
      addTearDown(container.dispose);

      final controller =
          container.read(supplierListControllerProvider.notifier);
      await controller.refresh();
      final code = await controller.deactivateSupplier('sup-1');

      expect(code, isNull);
      expect(container.read(supplierListControllerProvider).suppliers, isEmpty);
    });
  });
}
