import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/routing/app_routes.dart';
import 'package:hs360/core/routing/route_guards.dart';
import 'package:hs360/features/auth/domain/app_permissions.dart';
import 'package:hs360/features/auth/domain/app_session.dart';

void main() {
  AppSession session({
    required String accountType,
    Set<String> permissions = const {},
  }) {
    return AppSession(
      userId: 'user-1',
      email: 'test@example.com',
      tenantId: 'tenant-1',
      tenantUserId: 'tu-1',
      accountType: accountType,
      displayName: 'Test User',
      preferredLocale: 'ar',
      permissions: AppPermissions(
        isManager: accountType == 'manager',
        permissions: permissions,
      ),
    );
  }

  AsyncValue<AppSession?> loaded(AppSession value) => AsyncData(value);

  group('resolveHomeRoute', () {
    test('manager -> dashboard', () {
      expect(
        resolveHomeRoute(session(accountType: 'manager')),
        AppRoutes.dashboard,
      );
    });

    test('field permissions -> field today', () {
      expect(
        resolveHomeRoute(
          session(accountType: 'user', permissions: {'visits.view_assigned'}),
        ),
        AppRoutes.fieldToday,
      );
    });

    test('office permissions -> dashboard', () {
      expect(
        resolveHomeRoute(
          session(accountType: 'user', permissions: {'products.view'}),
        ),
        AppRoutes.dashboard,
      );
    });

    test('zero permissions -> blocked', () {
      expect(resolveHomeRoute(session(accountType: 'user')), AppRoutes.blocked);
    });

    test('field + office -> field today wins', () {
      expect(
        resolveHomeRoute(
          session(
            accountType: 'user',
            permissions: {'products.view', 'visits.view_assigned'},
          ),
        ),
        AppRoutes.fieldToday,
      );
    });
  });

  group('guardRedirectForPath', () {
    test('unauthenticated protected route -> login', () {
      expect(
        guardRedirectForPath(
          path: AppRoutes.dashboard,
          hasSupabaseSession: false,
          authState: const AsyncData(null),
        ),
        AppRoutes.login,
      );
    });

    test('unauthenticated public route -> null', () {
      expect(
        guardRedirectForPath(
          path: AppRoutes.login,
          hasSupabaseSession: false,
          authState: const AsyncData(null),
        ),
        isNull,
      );
    });

    test('manager on login -> dashboard', () {
      final manager = session(accountType: 'manager');
      expect(
        guardRedirectForPath(
          path: AppRoutes.login,
          hasSupabaseSession: true,
          authState: loaded(manager),
        ),
        AppRoutes.dashboard,
      );
    });

    test('field user on dashboard -> field today', () {
      final fieldUser = session(
        accountType: 'user',
        permissions: {'visits.view_assigned'},
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.dashboard,
          hasSupabaseSession: true,
          authState: loaded(fieldUser),
        ),
        AppRoutes.fieldToday,
      );
    });

    test('products user on field today -> dashboard', () {
      final productsUser = session(
        accountType: 'user',
        permissions: {'products.view'},
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.fieldToday,
          hasSupabaseSession: true,
          authState: loaded(productsUser),
        ),
        AppRoutes.dashboard,
      );
    });

    test('zero user on dashboard -> blocked', () {
      final zeroUser = session(accountType: 'user');
      expect(
        guardRedirectForPath(
          path: AppRoutes.dashboard,
          hasSupabaseSession: true,
          authState: loaded(zeroUser),
        ),
        AppRoutes.blocked,
      );
    });

    test('loading on protected route -> null', () {
      expect(
        guardRedirectForPath(
          path: AppRoutes.dashboard,
          hasSupabaseSession: true,
          authState: const AsyncLoading(),
        ),
        isNull,
      );
    });

    test('error on login with session -> null (no home loop)', () {
      expect(
        guardRedirectForPath(
          path: AppRoutes.login,
          hasSupabaseSession: true,
          authState: AsyncError(Exception('fail'), StackTrace.empty),
        ),
        isNull,
      );
    });

    test('error on protected route -> login', () {
      expect(
        guardRedirectForPath(
          path: AppRoutes.dashboard,
          hasSupabaseSession: true,
          authState: AsyncError(Exception('fail'), StackTrace.empty),
        ),
        AppRoutes.login,
      );
    });

    test('manager on dashboard when home is dashboard -> null', () {
      final manager = session(accountType: 'manager');
      expect(
        guardRedirectForPath(
          path: AppRoutes.dashboard,
          hasSupabaseSession: true,
          authState: loaded(manager),
        ),
        isNull,
      );
    });

    test('field user on field today when home is field today -> null', () {
      final fieldUser = session(
        accountType: 'user',
        permissions: {'visits.view_assigned'},
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.fieldToday,
          hasSupabaseSession: true,
          authState: loaded(fieldUser),
        ),
        isNull,
      );
    });

    test('zero user on blocked when home is blocked -> null', () {
      final zeroUser = session(accountType: 'user');
      expect(
        guardRedirectForPath(
          path: AppRoutes.blocked,
          hasSupabaseSession: true,
          authState: loaded(zeroUser),
        ),
        isNull,
      );
    });

    test('manager on forgot-password -> dashboard', () {
      final manager = session(accountType: 'manager');
      expect(
        guardRedirectForPath(
          path: AppRoutes.forgotPassword,
          hasSupabaseSession: true,
          authState: loaded(manager),
        ),
        AppRoutes.dashboard,
      );
    });

    test('field user on forgot-password -> field today', () {
      final fieldUser = session(
        accountType: 'user',
        permissions: {'visits.view_assigned'},
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.forgotPassword,
          hasSupabaseSession: true,
          authState: loaded(fieldUser),
        ),
        AppRoutes.fieldToday,
      );
    });

    test('root path when authenticated -> home', () {
      final manager = session(accountType: 'manager');
      expect(
        guardRedirectForPath(
          path: '/',
          hasSupabaseSession: true,
          authState: loaded(manager),
        ),
        AppRoutes.dashboard,
      );
    });

    test(
      'User with warehouses.view can access /warehouses but cannot access /inventory',
      () {
        final warehousesUser = session(
          accountType: 'user',
          permissions: {'warehouses.view'},
        );
        expect(
          guardRedirectForPath(
            path: AppRoutes.warehouses,
            hasSupabaseSession: true,
            authState: loaded(warehousesUser),
          ),
          isNull,
        );
        expect(
          guardRedirectForPath(
            path: AppRoutes.inventory,
            hasSupabaseSession: true,
            authState: loaded(warehousesUser),
          ),
          AppRoutes.dashboard,
        );
      },
    );

    test('isProductEditPath matches edit route and rejects new/edit', () {
      expect(isProductEditPath('/products/abc-123/edit'), isTrue);
      expect(isProductEditPath('/products/new/edit'), isFalse);
      expect(isProductEditPath('/products/abc-123'), isFalse);
    });

    test('edit route requires products.view and products.edit', () {
      final viewOnly = session(
        accountType: 'user',
        permissions: {'products.view'},
      );
      expect(
        guardRedirectForPath(
          path: '/products/p-1/edit',
          hasSupabaseSession: true,
          authState: loaded(viewOnly),
        ),
        AppRoutes.dashboard,
      );

      final editor = session(
        accountType: 'user',
        permissions: {'products.view', 'products.edit'},
      );
      expect(
        guardRedirectForPath(
          path: '/products/p-1/edit',
          hasSupabaseSession: true,
          authState: loaded(editor),
        ),
        isNull,
      );
    });

    test('products.edit alone resolves home to dashboard', () {
      expect(
        resolveHomeRoute(
          session(accountType: 'user', permissions: {'products.edit'}),
        ),
        AppRoutes.dashboard,
      );
    });

    test(
      'User with products.create can access /products/new even if they do not have products.view',
      () {
        final creatorUser = session(
          accountType: 'user',
          permissions: {'products.create'},
        );
        expect(
          guardRedirectForPath(
            path: AppRoutes.productsNew,
            hasSupabaseSession: true,
            authState: loaded(creatorUser),
          ),
          isNull,
        );
        expect(
          guardRedirectForPath(
            path: AppRoutes.products,
            hasSupabaseSession: true,
            authState: loaded(creatorUser),
          ),
          AppRoutes.dashboard,
        );
      },
    );

    test(
      'User with inventory_movements.create can access /inventory/transfers but cannot access /inventory/movements if they lack inventory_movements.view',
      () {
        final transferUser = session(
          accountType: 'user',
          permissions: {'inventory_movements.create'},
        );
        expect(
          guardRedirectForPath(
            path: AppRoutes.inventoryTransfers,
            hasSupabaseSession: true,
            authState: loaded(transferUser),
          ),
          isNull,
        );
        expect(
          guardRedirectForPath(
            path: AppRoutes.inventoryMovements,
            hasSupabaseSession: true,
            authState: loaded(transferUser),
          ),
          AppRoutes.dashboard,
        );
      },
    );

    test('suppliers.view only resolves home to dashboard', () {
      expect(
        resolveHomeRoute(
          session(accountType: 'user', permissions: {'suppliers.view'}),
        ),
        AppRoutes.dashboard,
      );
    });

    test('chart_of_accounts.view only resolves home to dashboard', () {
      expect(
        resolveHomeRoute(
          session(accountType: 'user', permissions: {'chart_of_accounts.view'}),
        ),
        AppRoutes.dashboard,
      );
    });

    test('Phase 4 path matchers reject new and extra segments', () {
      expect(isCustomerEditPath('/customers/c1/edit'), isTrue);
      expect(isCustomerEditPath('/customers/new/edit'), isFalse);
      expect(isCustomerDetailPath('/customers/c1'), isTrue);
      expect(isCustomerDetailPath('/customers/new'), isFalse);
      expect(isCustomerDetailPath('/customers/a/b'), isFalse);
      expect(isSupplierDetailPath('/suppliers/s1'), isTrue);
      expect(isSupplierDetailPath('/suppliers/new'), isFalse);
    });

    test('manager can access all Phase 4 routes', () {
      final manager = session(accountType: 'manager');
      for (final path in [
        AppRoutes.customers,
        '/customers/c1',
        '/customers/c1/edit',
        AppRoutes.suppliers,
        '/suppliers/s1',
        AppRoutes.accounts,
      ]) {
        expect(
          guardRedirectForPath(
            path: path,
            hasSupabaseSession: true,
            authState: loaded(manager),
          ),
          isNull,
          reason: path,
        );
      }
    });

    test('customers.view can access /customers and /customers/:id', () {
      final customerViewer = session(
        accountType: 'user',
        permissions: {'customers.view'},
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.customers,
          hasSupabaseSession: true,
          authState: loaded(customerViewer),
        ),
        isNull,
      );
      expect(
        guardRedirectForPath(
          path: '/customers/c1',
          hasSupabaseSession: true,
          authState: loaded(customerViewer),
        ),
        isNull,
      );
    });

    test('customers.view alone cannot access /customers/:id/edit', () {
      final viewOnly = session(
        accountType: 'user',
        permissions: {'customers.view'},
      );
      expect(
        guardRedirectForPath(
          path: '/customers/c1/edit',
          hasSupabaseSession: true,
          authState: loaded(viewOnly),
        ),
        AppRoutes.dashboard,
      );
    });

    test(
      'customers.view and customers.edit can access /customers/:id/edit',
      () {
        final editor = session(
          accountType: 'user',
          permissions: {'customers.view', 'customers.edit'},
        );
        expect(
          guardRedirectForPath(
            path: '/customers/c1/edit',
            hasSupabaseSession: true,
            authState: loaded(editor),
          ),
          isNull,
        );
      },
    );

    test('customers.edit only cannot access /customers/:id/edit', () {
      final editOnly = session(
        accountType: 'user',
        permissions: {'customers.edit'},
      );
      expect(resolveHomeRoute(editOnly), AppRoutes.blocked);
      expect(
        guardRedirectForPath(
          path: '/customers/c1/edit',
          hasSupabaseSession: true,
          authState: loaded(editOnly),
        ),
        AppRoutes.blocked,
      );
    });

    test('suppliers.view can access /customers and /suppliers', () {
      final supplierViewer = session(
        accountType: 'user',
        permissions: {'suppliers.view'},
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.customers,
          hasSupabaseSession: true,
          authState: loaded(supplierViewer),
        ),
        isNull,
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.suppliers,
          hasSupabaseSession: true,
          authState: loaded(supplierViewer),
        ),
        isNull,
      );
    });

    test('suppliers.view cannot access /customers/:id', () {
      final supplierViewer = session(
        accountType: 'user',
        permissions: {'suppliers.view'},
      );
      expect(
        guardRedirectForPath(
          path: '/customers/c1',
          hasSupabaseSession: true,
          authState: loaded(supplierViewer),
        ),
        AppRoutes.dashboard,
      );
    });

    test('chart_of_accounts.view can access /accounts', () {
      final coaViewer = session(
        accountType: 'user',
        permissions: {'chart_of_accounts.view'},
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.accounts,
          hasSupabaseSession: true,
          authState: loaded(coaViewer),
        ),
        isNull,
      );
    });

    test('zero-permission user is blocked from Phase 4 routes', () {
      final zeroUser = session(accountType: 'user');
      for (final path in [
        AppRoutes.customers,
        '/customers/c1',
        AppRoutes.suppliers,
        AppRoutes.accounts,
      ]) {
        expect(
          guardRedirectForPath(
            path: path,
            hasSupabaseSession: true,
            authState: loaded(zeroUser),
          ),
          AppRoutes.blocked,
          reason: path,
        );
      }
    });

    test('Phase 5 finance path matchers reject new and reserved segments', () {
      expect(isInvoiceDetailPath('/invoices/inv-1'), isTrue);
      expect(isInvoiceDetailPath('/invoices/new/sales'), isFalse);
      expect(isInvoiceReturnPath('/invoices/inv-1/return'), isTrue);
      expect(isInvoicesNewSalesPath('/invoices/new/sales'), isTrue);
      expect(isInvoicesNewPurchasePath('/invoices/new/purchase'), isTrue);
      expect(isVoucherDetailPath('/vouchers/v-1'), isTrue);
      expect(isVoucherDetailPath('/vouchers/new/receipt'), isFalse);
      expect(isVouchersNewReceiptPath('/vouchers/new/receipt'), isTrue);
      expect(isJournalDetailPath('/journal/j-1'), isTrue);
      expect(
        isInventoryDocumentDetailPath('/inventory/documents/doc-1'),
        isTrue,
      );
      expect(
        isInventoryDocumentDetailPath('/inventory/documents/opening-stock'),
        isFalse,
      );
    });

    test('invoices.view_sales resolves home to dashboard', () {
      expect(
        resolveHomeRoute(
          session(accountType: 'user', permissions: {'invoices.view_sales'}),
        ),
        AppRoutes.dashboard,
      );
    });

    test('journal.view only can access journal routes', () {
      final journalUser = session(
        accountType: 'user',
        permissions: {'journal.view'},
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.journal,
          hasSupabaseSession: true,
          authState: loaded(journalUser),
        ),
        isNull,
      );
      expect(
        guardRedirectForPath(
          path: '/journal/j-1',
          hasSupabaseSession: true,
          authState: loaded(journalUser),
        ),
        isNull,
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.invoices,
          hasSupabaseSession: true,
          authState: loaded(journalUser),
        ),
        AppRoutes.dashboard,
      );
    });

    test('cash_bank.view only can access cash-bank route', () {
      final cashUser = session(
        accountType: 'user',
        permissions: {'cash_bank.view'},
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.cashBank,
          hasSupabaseSession: true,
          authState: loaded(cashUser),
        ),
        isNull,
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.journal,
          hasSupabaseSession: true,
          authState: loaded(cashUser),
        ),
        AppRoutes.dashboard,
      );
    });

    test('invoice detail respects type-specific view permissions', () {
      final salesViewer = session(
        accountType: 'user',
        permissions: {'invoices.view_sales'},
      );
      final purchaseViewer = session(
        accountType: 'user',
        permissions: {'invoices.view_purchase'},
      );

      expect(
        guardRedirectForPath(
          path: '/invoices/inv-1',
          queryParameters: const {'type': 'sales'},
          hasSupabaseSession: true,
          authState: loaded(salesViewer),
        ),
        isNull,
      );
      expect(
        guardRedirectForPath(
          path: '/invoices/inv-1',
          queryParameters: const {'type': 'purchase'},
          hasSupabaseSession: true,
          authState: loaded(salesViewer),
        ),
        AppRoutes.dashboard,
      );
      expect(
        guardRedirectForPath(
          path: '/invoices/inv-1',
          queryParameters: const {'type': 'purchase'},
          hasSupabaseSession: true,
          authState: loaded(purchaseViewer),
        ),
        isNull,
      );
    });

    test('invoice create routes require create permissions', () {
      final salesCreator = session(
        accountType: 'user',
        permissions: {'invoices.create_sales'},
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.invoicesNewSales,
          hasSupabaseSession: true,
          authState: loaded(salesCreator),
        ),
        isNull,
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.invoicesNewPurchase,
          hasSupabaseSession: true,
          authState: loaded(salesCreator),
        ),
        AppRoutes.blocked,
      );
    });

    test('purchase form route distinguishes create vs draft edit', () {
      final createOnly = session(
        accountType: 'user',
        permissions: {'invoices.view_purchase', 'invoices.create_purchase'},
      );
      final editOnly = session(
        accountType: 'user',
        permissions: {'invoices.view_purchase', 'invoices.edit_draft'},
      );
      final both = session(
        accountType: 'user',
        permissions: {
          'invoices.view_purchase',
          'invoices.create_purchase',
          'invoices.edit_draft',
        },
      );

      expect(
        guardRedirectForPath(
          path: AppRoutes.invoicesNewPurchase,
          hasSupabaseSession: true,
          authState: loaded(createOnly),
        ),
        isNull,
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.invoicesNewPurchase,
          queryParameters: const {'draftId': 'draft-1'},
          hasSupabaseSession: true,
          authState: loaded(createOnly),
        ),
        AppRoutes.dashboard,
      );

      expect(
        guardRedirectForPath(
          path: AppRoutes.invoicesNewPurchase,
          hasSupabaseSession: true,
          authState: loaded(editOnly),
        ),
        AppRoutes.dashboard,
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.invoicesNewPurchase,
          queryParameters: const {'draftId': 'draft-1'},
          hasSupabaseSession: true,
          authState: loaded(editOnly),
        ),
        isNull,
      );

      expect(
        guardRedirectForPath(
          path: AppRoutes.invoicesNewPurchase,
          hasSupabaseSession: true,
          authState: loaded(both),
        ),
        isNull,
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.invoicesNewPurchase,
          queryParameters: const {'draftId': 'draft-1'},
          hasSupabaseSession: true,
          authState: loaded(both),
        ),
        isNull,
      );
    });

    test('invoice return route requires create return permission', () {
      final returnCreator = session(
        accountType: 'user',
        permissions: {'invoices.create_sales_return'},
      );
      expect(
        guardRedirectForPath(
          path: '/invoices/inv-1/return',
          hasSupabaseSession: true,
          authState: loaded(returnCreator),
        ),
        isNull,
      );
    });

    test('voucher create routes require create permissions', () {
      final receiptCreator = session(
        accountType: 'user',
        permissions: {'vouchers.create_receipt'},
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.vouchersNewReceipt,
          hasSupabaseSession: true,
          authState: loaded(receiptCreator),
        ),
        isNull,
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.vouchersNewPayment,
          hasSupabaseSession: true,
          authState: loaded(receiptCreator),
        ),
        AppRoutes.blocked,
      );
    });

    test('inventory_documents.view can access list and detail routes', () {
      final viewer = session(
        accountType: 'user',
        permissions: {'inventory_documents.view'},
      );
      for (final path in [
        AppRoutes.inventoryDocuments,
        '/inventory/documents/doc-1',
      ]) {
        expect(
          guardRedirectForPath(
            path: path,
            hasSupabaseSession: true,
            authState: loaded(viewer),
          ),
          isNull,
          reason: path,
        );
      }
    });

    test(
      'inventory_documents.create_opening required for opening stock form',
      () {
        final viewerOnly = session(
          accountType: 'user',
          permissions: {'inventory_documents.view'},
        );
        expect(
          guardRedirectForPath(
            path: AppRoutes.inventoryDocumentsOpeningStock,
            hasSupabaseSession: true,
            authState: loaded(viewerOnly),
          ),
          AppRoutes.blocked,
        );

        final creator = session(
          accountType: 'user',
          permissions: {'inventory_documents.create_opening'},
        );
        expect(
          guardRedirectForPath(
            path: AppRoutes.inventoryDocumentsOpeningStock,
            hasSupabaseSession: true,
            authState: loaded(creator),
          ),
          isNull,
        );
      },
    );

    test('settings.tax.view can access tax settings route', () {
      final taxViewer = session(
        accountType: 'user',
        permissions: {'settings.tax.view'},
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.taxSettings,
          hasSupabaseSession: true,
          authState: loaded(taxViewer),
        ),
        isNull,
      );
    });

    test('legacy invoices.view grants invoice list access', () {
      final legacyViewer = session(
        accountType: 'user',
        permissions: {'invoices.view'},
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.invoices,
          hasSupabaseSession: true,
          authState: loaded(legacyViewer),
        ),
        isNull,
      );
    });

    test('document preview blocks missing or invalid kind', () {
      final viewer = session(
        accountType: 'user',
        permissions: {'invoices.view_sales', 'invoices.print'},
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.documentPreview,
          hasSupabaseSession: true,
          authState: loaded(viewer),
        ),
        AppRoutes.dashboard,
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.documentPreview,
          queryParameters: const {'kind': 'unknown', 'entityId': 'x'},
          hasSupabaseSession: true,
          authState: loaded(viewer),
        ),
        AppRoutes.dashboard,
      );
    });

    test('document preview sales invoice requires print permission', () {
      final viewOnly = session(
        accountType: 'user',
        permissions: {'invoices.view_sales'},
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.documentPreview,
          queryParameters: const {'kind': 'sales_invoice', 'entityId': 'inv-1'},
          hasSupabaseSession: true,
          authState: loaded(viewOnly),
        ),
        AppRoutes.dashboard,
      );

      final withPrint = session(
        accountType: 'user',
        permissions: {'invoices.view_sales', 'invoices.print'},
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.documentPreview,
          queryParameters: const {'kind': 'sales_invoice', 'entityId': 'inv-1'},
          hasSupabaseSession: true,
          authState: loaded(withPrint),
        ),
        isNull,
      );
    });

    test(
      'document preview allows customer statement with ledger permission',
      () {
        final ledgerViewer = session(
          accountType: 'user',
          permissions: {'customers.view_ledger'},
        );
        expect(
          guardRedirectForPath(
            path: AppRoutes.documentPreview,
            queryParameters: const {
              'kind': 'customer_statement',
              'entityId': 'cust-1',
            },
            hasSupabaseSession: true,
            authState: loaded(ledgerViewer),
          ),
          isNull,
        );
      },
    );

    test('document preview payment voucher always blocked', () {
      final withPrint = session(
        accountType: 'user',
        permissions: {'vouchers.view', 'vouchers.print'},
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.documentPreview,
          queryParameters: const {'kind': 'payment_voucher', 'entityId': 'v-1'},
          hasSupabaseSession: true,
          authState: loaded(withPrint),
        ),
        AppRoutes.dashboard,
      );
    });

    test('contract path matchers exclude new segment', () {
      expect(isContractsNewPath('/contracts/new'), isTrue);
      expect(isContractDetailPath('/contracts/new'), isFalse);
      expect(isContractDetailPath('/contracts/contract-1'), isTrue);
      expect(isContractConvertPath('/contracts/contract-1/convert'), isTrue);
    });

    test('contract routes enforce permissions', () {
      final manager = session(accountType: 'manager');
      final viewer = session(
        accountType: 'user',
        permissions: {'contracts.view'},
      );
      final creator = session(
        accountType: 'user',
        permissions: {'contracts.create'},
      );
      final convertUser = session(
        accountType: 'user',
        permissions: {'contracts.convert_trial'},
      );
      final zero = session(accountType: 'user');

      for (final path in [
        AppRoutes.contracts,
        AppRoutes.contractsNew,
        '/contracts/contract-1',
        '/contracts/contract-1/convert',
      ]) {
        expect(
          guardRedirectForPath(
            path: path,
            hasSupabaseSession: true,
            authState: loaded(manager),
          ),
          isNull,
        );
      }

      expect(
        guardRedirectForPath(
          path: AppRoutes.contracts,
          hasSupabaseSession: true,
          authState: loaded(viewer),
        ),
        isNull,
      );
      expect(
        guardRedirectForPath(
          path: '/contracts/contract-1',
          hasSupabaseSession: true,
          authState: loaded(viewer),
        ),
        isNull,
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.contractsNew,
          hasSupabaseSession: true,
          authState: loaded(viewer),
        ),
        AppRoutes.dashboard,
      );
      expect(
        guardRedirectForPath(
          path: '/contracts/contract-1/convert',
          hasSupabaseSession: true,
          authState: loaded(viewer),
        ),
        AppRoutes.dashboard,
      );

      expect(
        guardRedirectForPath(
          path: AppRoutes.contractsNew,
          hasSupabaseSession: true,
          authState: loaded(creator),
        ),
        isNull,
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.contracts,
          hasSupabaseSession: true,
          authState: loaded(creator),
        ),
        AppRoutes.blocked,
      );
      expect(
        guardRedirectForPath(
          path: '/contracts/contract-1',
          hasSupabaseSession: true,
          authState: loaded(creator),
        ),
        AppRoutes.blocked,
      );
      expect(resolveHomeRoute(creator), AppRoutes.blocked);

      expect(
        guardRedirectForPath(
          path: '/contracts/contract-1/convert',
          hasSupabaseSession: true,
          authState: loaded(convertUser),
        ),
        isNull,
      );
      expect(
        guardRedirectForPath(
          path: AppRoutes.contracts,
          hasSupabaseSession: true,
          authState: loaded(convertUser),
        ),
        AppRoutes.blocked,
      );

      for (final path in [
        AppRoutes.contracts,
        AppRoutes.contractsNew,
        '/contracts/contract-1',
        '/contracts/contract-1/convert',
      ]) {
        expect(
          guardRedirectForPath(
            path: path,
            hasSupabaseSession: true,
            authState: loaded(zero),
          ),
          AppRoutes.blocked,
        );
      }
    });
  });
}
