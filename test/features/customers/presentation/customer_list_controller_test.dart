import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/customer_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/customers/data/customer_repository.dart';
import 'package:hs360/features/customers/domain/customer_form_state.dart';
import 'package:hs360/features/customers/domain/customer_type.dart';
import 'package:hs360/features/customers/presentation/customer_list_controller.dart';

import '../fake_customer_repository.dart';

AppSession _session({Set<String> permissions = const {'customers.view'}}) {
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
  FakeCustomerRepository repo, {
  Set<String> permissions = const {'customers.view'},
}) {
  final container = ProviderContainer(
    overrides: [
      authControllerProvider
          .overrideWith(() => TestAuthController(_session(permissions: permissions))),
      customerRepositoryProvider.overrideWith((ref) => repo),
    ],
  );
  return container;
}

CustomerFormState _formState({
  String nameAr = 'عميل',
  bool isVip = false,
  bool createAccount = false,
}) {
  return CustomerFormState(
    customerType: CustomerType.individual,
    nameAr: nameAr,
    phonePrimary: '99000000',
    isVip: isVip,
    createAccount: createAccount,
  );
}

void main() {
  group('CustomerListController', () {
    test('default filter is active-only', () async {
      final repo = FakeCustomerRepository(customers: [sampleCustomer()]);
      final container = _container(repo);
      addTearDown(container.dispose);

      await container.read(customerListControllerProvider.notifier).refresh();

      expect(repo.lastFilters?.isActive, isTrue);
      final state = container.read(customerListControllerProvider);
      expect(state.customers, hasLength(1));
      expect(state.isLoading, isFalse);
      expect(state.errorCode, isNull);
    });

    test('empty result yields empty non-loading state', () async {
      final repo = FakeCustomerRepository();
      final container = _container(repo);
      addTearDown(container.dispose);

      await container.read(customerListControllerProvider.notifier).refresh();

      final state = container.read(customerListControllerProvider);
      expect(state.customers, isEmpty);
      expect(state.isLoading, isFalse);
    });

    test('fetch error sets error code', () async {
      final repo = FakeCustomerRepository(
        fetchError: const CustomerException(code: CustomerException.unknown),
      );
      final container = _container(repo);
      addTearDown(container.dispose);

      await container.read(customerListControllerProvider.notifier).refresh();

      final state = container.read(customerListControllerProvider);
      expect(state.errorCode, CustomerException.unknown);
      expect(state.isLoading, isFalse);
    });

    test('setIsActive(null) clears active filter', () async {
      final repo = FakeCustomerRepository();
      final container = _container(repo);
      addTearDown(container.dispose);

      final controller =
          container.read(customerListControllerProvider.notifier);
      await controller.refresh();
      controller.setIsActive(null);
      await Future<void>.value();

      expect(repo.lastFilters?.isActive, isNull);
    });

    test('deactivate removes customer from default active-only list', () async {
      final repo = FakeCustomerRepository(
        customers: [sampleCustomer(id: 'cust-1')],
      );
      final container = _container(
        repo,
        permissions: {'customers.view', 'customers.delete'},
      );
      addTearDown(container.dispose);

      final controller =
          container.read(customerListControllerProvider.notifier);
      await controller.refresh();
      expect(container.read(customerListControllerProvider).customers,
          hasLength(1));

      final code = await controller.deactivateCustomer('cust-1');
      expect(code, isNull);
      expect(repo.lastDeactivatedId, 'cust-1');
      expect(
        container.read(customerListControllerProvider).customers,
        isEmpty,
      );
    });

    test('create refreshes list and forwards input', () async {
      final repo = FakeCustomerRepository();
      final container = _container(
        repo,
        permissions: {'customers.view', 'customers.create'},
      );
      addTearDown(container.dispose);

      final controller =
          container.read(customerListControllerProvider.notifier);
      final code = await controller.createCustomer(_formState(nameAr: 'جديد'));

      expect(code, isNull);
      expect(repo.lastCreateInput?.nameAr, 'جديد');
      expect(container.read(customerListControllerProvider).customers,
          hasLength(1));
    });

    test('updateCustomer succeeds even when list never loaded', () async {
      final repo = FakeCustomerRepository();
      final container = _container(
        repo,
        permissions: {'customers.view', 'customers.edit'},
      );
      addTearDown(container.dispose);

      final code = await container
          .read(customerListControllerProvider.notifier)
          .updateCustomer('cust-9', _formState(nameAr: 'محدث'));

      expect(code, isNull);
      expect(repo.lastUpdatedId, 'cust-9');
      expect(repo.lastUpdateInput?.nameAr, 'محدث');
    });

    test('create denied without create permission', () async {
      final repo = FakeCustomerRepository();
      final container = _container(repo, permissions: {'customers.view'});
      addTearDown(container.dispose);

      final code = await container
          .read(customerListControllerProvider.notifier)
          .createCustomer(_formState());

      expect(code, CustomerException.permissionDenied);
      expect(repo.lastCreateInput, isNull);
    });

    test('edit denied without view permission', () async {
      final repo = FakeCustomerRepository();
      final container = _container(repo, permissions: {'customers.edit'});
      addTearDown(container.dispose);

      final code = await container
          .read(customerListControllerProvider.notifier)
          .updateCustomer('cust-1', _formState());

      expect(code, CustomerException.permissionDenied);
      expect(repo.lastUpdateInput, isNull);
    });

    test('M6 statement/balance calls never happen', () async {
      final repo = FakeCustomerRepository(customers: [sampleCustomer()]);
      final container = _container(
        repo,
        permissions: {'customers.view', 'customers.create', 'customers.delete'},
      );
      addTearDown(container.dispose);

      final controller =
          container.read(customerListControllerProvider.notifier);
      await controller.refresh();
      await controller.createCustomer(_formState());
      await controller.deactivateCustomer('cust-1');

      expect(repo.statementCallCount, 0);
      expect(repo.balanceCallCount, 0);
    });
  });
}
