import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/inventory/data/warehouse_repository.dart';
import 'package:hs360/features/inventory/domain/warehouse_form_state.dart';
import 'package:hs360/features/inventory/domain/warehouse_type.dart';
import 'package:hs360/core/errors/products_exception.dart';
import 'package:hs360/features/inventory/presentation/warehouses_controller.dart';

import '../fake_warehouse_repository.dart';

AppSession _session({Set<String> permissions = const {'warehouses.view'}}) {
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

  final AppSession session;

  @override
  FutureOr<AppSession?> build() => session;
}

void main() {
  group('WarehousesController', () {
    test('loads warehouses and employees with view permission', () async {
      final repo = FakeWarehouseRepository(
        warehouses: [sampleWarehouse()],
        employees: [sampleEmployee()],
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () =>
                TestAuthController(_session(permissions: {'warehouses.view'})),
          ),
          warehouseRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(warehousesControllerProvider.notifier).refresh();

      final state = container.read(warehousesControllerProvider);
      expect(state.warehouses, hasLength(1));
      expect(state.employees, hasLength(1));
      expect(state.isLoading, isFalse);
      expect(state.errorCode, isNull);
    });

    test('createWarehouse blocked without warehouses.create', () async {
      final repo = FakeWarehouseRepository();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () =>
                TestAuthController(_session(permissions: {'warehouses.view'})),
          ),
          warehouseRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      final code = await container
          .read(warehousesControllerProvider.notifier)
          .createWarehouse(
            const WarehouseFormState(
              nameAr: 'م',
              nameEn: 'W',
              type: WarehouseType.main,
            ),
          );

      expect(code, isNull);
      expect(repo.lastCreateInput, isNull);
    });

    test('createWarehouse succeeds with create permission', () async {
      final repo = FakeWarehouseRepository();
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(
              _session(permissions: {'warehouses.view', 'warehouses.create'}),
            ),
          ),
          warehouseRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      final code = await container
          .read(warehousesControllerProvider.notifier)
          .createWarehouse(
            const WarehouseFormState(
              nameAr: 'مخزن',
              nameEn: 'Store',
              type: WarehouseType.main,
            ),
          );

      expect(code, isNull);
      expect(repo.lastCreateInput?.nameEn, 'Store');
      expect(repo.warehouses, hasLength(1));
    });

    test(
      'employee lookup failure keeps warehouses and sets warning code',
      () async {
        final repo = FakeWarehouseRepository(
          warehouses: [sampleWarehouse()],
          fetchEmployeesError: const ProductsException(
            code: ProductsException.permissionDenied,
          ),
        );
        final container = ProviderContainer(
          overrides: [
            authControllerProvider.overrideWith(
              () => TestAuthController(
                _session(permissions: {'warehouses.view'}),
              ),
            ),
            warehouseRepositoryProvider.overrideWith((ref) => repo),
          ],
        );
        addTearDown(container.dispose);

        await container.read(warehousesControllerProvider.notifier).refresh();

        final state = container.read(warehousesControllerProvider);
        expect(state.warehouses, hasLength(1));
        expect(state.employees, isEmpty);
        expect(state.errorCode, isNull);
        expect(
          state.employeeLookupErrorCode,
          ProductsException.permissionDenied,
        );
        expect(state.isLoading, isFalse);
      },
    );

    test('deactivateWarehouse requires edit permission', () async {
      final repo = FakeWarehouseRepository(
        warehouses: [sampleWarehouse(id: 'wh-1')],
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () =>
                TestAuthController(_session(permissions: {'warehouses.view'})),
          ),
          warehouseRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      await container.read(warehousesControllerProvider.notifier).refresh();
      final code = await container
          .read(warehousesControllerProvider.notifier)
          .deactivateWarehouse('wh-1');

      expect(code, isNull);
      expect(repo.lastDeactivatedId, isNull);
    });
  });
}
