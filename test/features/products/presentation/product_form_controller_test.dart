import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/products_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/products/data/product_group_repository.dart';
import 'package:hs360/features/products/data/product_repository.dart';
import 'package:hs360/features/products/presentation/product_form_controller.dart';

import 'package:hs360/features/products/domain/product_form_mapper.dart';
import 'package:hs360/features/products/presentation/product_form_draft.dart';

import '../fake_product_repositories.dart';

AppSession _session({Set<String> permissions = const {'products.create'}}) {
  return AppSession(
    userId: 'u',
    email: 'e@test.com',
    tenantId: 't',
    tenantUserId: 'tu',
    accountType: 'user',
    displayName: 'Test',
    preferredLocale: 'en',
    permissions: AppPermissions(
      isManager: false,
      permissions: permissions,
    ),
  );
}

class TestAuthController extends AuthController {
  TestAuthController(this.session);
  final AppSession session;
  @override
  FutureOr<AppSession?> build() => session;
}

Future<void> _waitForFormInit(
  ProviderContainer container, {
  String? productId,
}) async {
  for (var i = 0; i < 100; i++) {
    final state = container.read(
      productFormControllerProvider(productId: productId),
    );
    if (productId == null) {
      if (state.blockCreateWithoutGroups || state.canSelectGroup) return;
    } else if (!state.isLoading &&
        (state.draft.groupId.isNotEmpty || state.errorCode != null)) {
      return;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
}

void main() {
  test('create blocked without product_groups.view', () async {
    final productRepo = FakeProductRepository();
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(
          () => TestAuthController(_session(permissions: {'products.create'})),
        ),
        productRepositoryProvider.overrideWith((ref) => productRepo),
        productGroupRepositoryProvider.overrideWith(
          (ref) => FakeProductGroupRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await _waitForFormInit(container);

    final notifier = container.read(
      productFormControllerProvider(productId: null).notifier,
    );
    final state = container.read(productFormControllerProvider(productId: null));
    expect(state.blockCreateWithoutGroups, isTrue);
    expect(notifier.validateCurrentStep(), isFalse);
    expect(
      container.read(productFormControllerProvider(productId: null)).errorCode,
      ProductsException.productGroupsPermissionRequired,
    );
  });

  test('productFormStateFromProduct preserves groupId for edit flow', () {
    final product = sampleProduct(id: 'p-1', groupId: 'g-1');
    final form = productFormStateFromProduct(product);
    expect(form.groupId, 'g-1');
    expect(ProductFormDraft.fromFormState(form).groupId, 'g-1');
  });

  test('pricing step rejects invalid decimal text before submit', () async {
    final container = ProviderContainer(
      overrides: [
        authControllerProvider.overrideWith(
          () => TestAuthController(
            _session(
              permissions: {
                'products.create',
                'product_groups.view',
              },
            ),
          ),
        ),
        productRepositoryProvider.overrideWith((ref) => FakeProductRepository()),
        productGroupRepositoryProvider.overrideWith(
          (ref) => FakeProductGroupRepository(),
        ),
      ],
    );
    addTearDown(container.dispose);

    await _waitForFormInit(container);

    final notifier = container.read(
      productFormControllerProvider(productId: null).notifier,
    );
    notifier.setStep(2);
    notifier.updateDraft(
      ProductFormDraft(
        nameAr: 'منتج',
        nameEn: 'Product',
        groupId: 'g-1',
        salePrice: 'abc',
      ),
    );

    expect(notifier.validateCurrentStep(), isFalse);
    expect(
      container.read(productFormControllerProvider(productId: null)).errorCode,
      ProductsException.invalidDecimal,
    );
  });
}
