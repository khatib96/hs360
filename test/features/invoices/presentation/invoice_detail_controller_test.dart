import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/errors/finance_exception.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';
import 'package:hs360/features/auth/presentation/auth_controller.dart';
import 'package:hs360/features/invoices/data/invoice_repository.dart';
import 'package:hs360/features/invoices/domain/invoice_detail.dart';
import 'package:hs360/features/invoices/domain/invoice_status.dart';
import 'package:hs360/features/invoices/domain/invoice_type.dart';
import 'package:hs360/features/invoices/presentation/invoice_detail_controller.dart';

import '../fake_invoice_repository.dart';

AppSession _session({Set<String> permissions = const {'invoices.view_sales'}}) {
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

Future<void> _ready(ProviderContainer container) async {
  await container.read(authControllerProvider.future);
}

Future<void> _waitForDetail(ProviderContainer container, String id) async {
  await _ready(container);
  await container.read(invoiceDetailControllerProvider(id).notifier).load();
}

void main() {
  group('InvoiceDetailController', () {
    test('loads detail when type permission matches', () async {
      final repo = FakeInvoiceRepository(
        detailById: {'inv-1': sampleInvoiceDetail()},
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(_session()),
          ),
          invoiceRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      await _waitForDetail(container, 'inv-1');

      final state = container.read(invoiceDetailControllerProvider('inv-1'));
      expect(state.detail?.id, 'inv-1');
      expect(state.errorCode, isNull);
    });

    test('denies purchase detail without purchase view permission', () async {
      final repo = FakeInvoiceRepository(
        detailById: {
          'inv-2': sampleInvoiceDetail(id: 'inv-2', type: InvoiceType.purchase),
        },
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(_session()),
          ),
          invoiceRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      await _waitForDetail(container, 'inv-2');

      expect(
        container.read(invoiceDetailControllerProvider('inv-2')).errorCode,
        FinanceException.permissionDenied,
      );
    });

    test('cancel requires invoices.cancel permission', () async {
      final repo = FakeInvoiceRepository(
        detailById: {'inv-1': sampleInvoiceDetail()},
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(_session()),
          ),
          invoiceRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      await _waitForDetail(container, 'inv-1');

      final code = await container
          .read(invoiceDetailControllerProvider('inv-1').notifier)
          .cancel('Customer dispute');

      expect(code, FinanceException.permissionDenied);
      expect(repo.lastCancelledId, isNull);
    });

    test('cancel succeeds with permission and non-empty reason', () async {
      final repo = FakeInvoiceRepository(
        detailById: {'inv-1': sampleInvoiceDetail()},
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(
              _session(permissions: {'invoices.view_sales', 'invoices.cancel'}),
            ),
          ),
          invoiceRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      await _waitForDetail(container, 'inv-1');

      final code = await container
          .read(invoiceDetailControllerProvider('inv-1').notifier)
          .cancel('Customer dispute');

      expect(code, isNull);
      expect(repo.lastCancelledId, 'inv-1');
      expect(repo.lastCancelReason, 'Customer dispute');
    });

    test('cancel rejects empty reason before repository call', () async {
      final repo = FakeInvoiceRepository(
        detailById: {'inv-1': sampleInvoiceDetail()},
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(
              _session(permissions: {'invoices.view_sales', 'invoices.cancel'}),
            ),
          ),
          invoiceRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      await _waitForDetail(container, 'inv-1');

      final code = await container
          .read(invoiceDetailControllerProvider('inv-1').notifier)
          .cancel('   ');

      expect(code, FinanceException.validationCancellationReasonRequired);
      expect(repo.lastCancelledId, isNull);
    });

    test('canCreateReturn for confirmed sales invoice with permission', () async {
      final repo = FakeInvoiceRepository(
        detailById: {'inv-1': sampleInvoiceDetail()},
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(
              _session(permissions: {
                'invoices.view_sales',
                'invoices.create_sales_return',
              }),
            ),
          ),
          invoiceRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      await _waitForDetail(container, 'inv-1');

      final controller =
          container.read(invoiceDetailControllerProvider('inv-1').notifier);
      final session = container.read(authControllerProvider).valueOrNull!;
      expect(controller.canCreateReturn(session), isTrue);
    });

    test('canCreateReturn false for draft purchase', () async {
      final repo = FakeInvoiceRepository(
        detailById: {
          'pi-1': sampleInvoiceDetail(
            id: 'pi-1',
            type: InvoiceType.purchase,
          ).copyWithStatus(InvoiceStatus.draft),
        },
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(
              _session(permissions: {
                'invoices.view_purchase',
                'invoices.create_purchase_return',
              }),
            ),
          ),
          invoiceRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(invoiceDetailControllerProvider('pi-1', type: InvoiceType.purchase).notifier)
          .load();

      final controller = container.read(
        invoiceDetailControllerProvider('pi-1', type: InvoiceType.purchase).notifier,
      );
      final session = container.read(authControllerProvider).valueOrNull!;
      expect(controller.canCreateReturn(session), isFalse);
    });

    test('canConfirmDraft requires create and edit permissions', () async {
      final repo = FakeInvoiceRepository(
        detailById: {
          'pi-draft': sampleInvoiceDetail(
            id: 'pi-draft',
            type: InvoiceType.purchase,
          ).copyWithStatus(InvoiceStatus.draft),
        },
      );
      final container = ProviderContainer(
        overrides: [
          authControllerProvider.overrideWith(
            () => TestAuthController(
              _session(permissions: {
                'invoices.view_purchase',
                'invoices.create_purchase',
              }),
            ),
          ),
          invoiceRepositoryProvider.overrideWith((ref) => repo),
        ],
      );
      addTearDown(container.dispose);

      await container
          .read(
            invoiceDetailControllerProvider('pi-draft', type: InvoiceType.purchase)
                .notifier,
          )
          .load();

      final controller = container.read(
        invoiceDetailControllerProvider('pi-draft', type: InvoiceType.purchase)
            .notifier,
      );
      final session = container.read(authControllerProvider).valueOrNull!;
      expect(controller.canConfirmDraft(session), isFalse);
      expect(controller.canEditDraft(session), isFalse);
    });
  });
}

extension on InvoiceDetail {
  InvoiceDetail copyWithStatus(InvoiceStatus status) {
    return InvoiceDetail(
      id: id,
      invoiceNumber: invoiceNumber,
      type: type,
      status: status,
      date: date,
      dueDate: dueDate,
      customer: customer,
      supplier: supplier,
      warehouse: warehouse,
      notes: notes,
      subtotal: subtotal,
      discountAmount: discountAmount,
      taxAmount: taxAmount,
      total: total,
      paidAmount: paidAmount,
      outstanding: outstanding,
      lines: lines,
    );
  }
}
