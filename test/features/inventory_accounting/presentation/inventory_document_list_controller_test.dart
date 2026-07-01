import 'dart:async';

import 'package:decimal/decimal.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/domain/validators/opening_stock_validator.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/inventory_accounting/data/inventory_document_repository.dart';
import 'package:hs360/features/inventory_accounting/domain/inventory_document_detail.dart';
import 'package:hs360/features/inventory_accounting/domain/inventory_document_line.dart';
import 'package:hs360/features/inventory_accounting/domain/inventory_document_summary.dart';
import 'package:hs360/features/inventory_accounting/presentation/inventory_document_detail_controller.dart';
import 'package:hs360/features/inventory_accounting/presentation/inventory_document_list_controller.dart';

import '../fake_inventory_document_repository.dart';

AppSession _session({Set<String> permissions = const {'inventory_documents.view'}}) {
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

InventoryDocumentDetail _detail({bool serialized = false}) {
  return InventoryDocumentDetail(
    summary: InventoryDocumentSummary(
      id: 'doc-1',
      documentNumber: 'STI-1',
      kind: InventoryDocumentKind.stockIn,
      status: InventoryDocumentStatus.confirmed,
      date: DateTime(2026, 6, 1),
      warehouseId: 'wh-1',
    ),
    notes: 'Notes',
    lines: [
      InventoryDocumentLine(
        id: 'line-1',
        lineOrder: 1,
        productId: 'prod-1',
        qty: Decimal.one,
        productUnitIds: serialized ? const ['unit-1'] : const [],
      ),
    ],
    movements: const [],
  );
}

void main() {
  group('OpeningStockValidator', () {
    test('requires notes', () {
      final result = const OpeningStockValidator().validate(
        OpeningStockInput(
          warehouseId: 'wh-1',
          date: DateTime(2026, 6, 1),
          notes: ' ',
          lines: [
            OpeningStockLineInput(
              productId: 'p1',
              qty: Decimal.one,
              unitCost: Decimal.one,
            ),
          ],
        ),
      );
      expect(result.isValid, isFalse);
    });
  });

  group('InventoryDocumentListController', () {
    test('loads documents for permitted user', () async {
      final repo = FakeInventoryDocumentRepository(
        documents: [sampleInventoryDocumentSummary()],
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(_session()),
          ),
          inventoryDocumentRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(inventoryDocumentListControllerProvider.notifier)
          .refresh();

      final state = container.read(inventoryDocumentListControllerProvider);
      expect(state.documents, hasLength(1));
      expect(state.hasMore, isFalse);
    });

    test('hasMore when page is full', () async {
      final docs = List.generate(
        51,
        (i) => sampleInventoryDocumentSummary(id: 'doc-$i'),
      );
      final repo = FakeInventoryDocumentRepository(documents: docs);
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(_session()),
          ),
          inventoryDocumentRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(inventoryDocumentListControllerProvider.notifier)
          .refresh();

      expect(
        container.read(inventoryDocumentListControllerProvider).hasMore,
        isTrue,
      );
    });
  });

  group('InventoryDocumentDetailController', () {
    test('hides cancel for serialized documents', () async {
      final repo = FakeInventoryDocumentRepository(
        detailById: {'doc-1': _detail(serialized: true)},
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(
              _session(permissions: {
                'inventory_documents.view',
                'inventory_documents.cancel',
              }),
            ),
          ),
          inventoryDocumentRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(inventoryDocumentDetailControllerProvider('doc-1').notifier)
          .load();

      final controller = container.read(
        inventoryDocumentDetailControllerProvider('doc-1').notifier,
      );
      expect(
        controller.canShowCancelButton(_session(permissions: {
          'inventory_documents.view',
          'inventory_documents.cancel',
        })),
        isFalse,
      );
    });

    test('sets cancelBlocked on correction_document_required', () async {
      final repo = FakeInventoryDocumentRepository(
        detailById: {'doc-1': _detail()},
      );
      repo.cancelError = const FinanceException(
        code: FinanceException.correctionDocumentRequired,
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(
              _session(permissions: {
                'inventory_documents.view',
                'inventory_documents.cancel',
              }),
            ),
          ),
          inventoryDocumentRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(inventoryDocumentDetailControllerProvider('doc-1').notifier)
          .load();

      await container
          .read(inventoryDocumentDetailControllerProvider('doc-1').notifier)
          .cancel('Because test');

      final state = container.read(
        inventoryDocumentDetailControllerProvider('doc-1'),
      );
      expect(state.cancelBlocked, isTrue);
      expect(state.errorCode, FinanceException.correctionDocumentRequired);
    });
  });
}
