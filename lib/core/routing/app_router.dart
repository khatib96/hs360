import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/blocked_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/field_ops/presentation/field_today_screen.dart';
import '../../features/products/presentation/product_detail_screen.dart';
import '../../features/products/presentation/product_unit_detail_screen.dart';
import '../../features/products/presentation/product_list_screen.dart';
import '../../features/products/presentation/product_wizard_screen.dart';
import '../../features/accounting/presentation/chart_of_accounts_screen.dart';
import '../../features/customers/presentation/customer_detail_screen.dart';
import '../../features/customers/presentation/customer_edit_screen.dart';
import '../../features/customers/presentation/customers_hub_screen.dart';
import '../../features/suppliers/presentation/supplier_detail_placeholder_screen.dart';
import '../../features/inventory/presentation/inventory_movements_screen.dart';
import '../../features/inventory/presentation/inventory_transfers_screen.dart';
import '../../features/inventory/presentation/inventory_screen.dart';
import '../../features/inventory/presentation/warehouses_screen.dart';
import '../../core/documents/domain/document_kind.dart';
import '../../core/documents/presentation/document_preview_screen.dart';
import '../../core/documents/presentation/document_preview_state.dart';
import '../../features/settings/presentation/template_settings_screen.dart';
import '../../features/settings/presentation/tax_settings_placeholder_screen.dart';
import '../../features/invoices/presentation/invoice_detail_placeholder_screen.dart';
import '../../features/invoices/presentation/invoice_form_placeholder_screen.dart';
import '../../features/invoices/presentation/invoice_list_placeholder_screen.dart';
import '../../features/invoices/presentation/invoice_return_placeholder_screen.dart';
import '../../features/vouchers/presentation/voucher_detail_placeholder_screen.dart';
import '../../features/vouchers/presentation/voucher_form_placeholder_screen.dart';
import '../../features/vouchers/presentation/voucher_list_placeholder_screen.dart';
import '../../features/journal/presentation/cash_bank_placeholder_screen.dart';
import '../../features/journal/presentation/journal_detail_placeholder_screen.dart';
import '../../features/journal/presentation/journal_list_placeholder_screen.dart';
import '../../features/inventory_accounting/presentation/inventory_document_detail_placeholder_screen.dart';
import '../../features/inventory_accounting/presentation/inventory_document_form_placeholder_screen.dart';
import '../../features/inventory_accounting/presentation/inventory_document_list_placeholder_screen.dart';
import 'app_routes.dart';
import 'route_guards.dart';
import 'router_refresh_notifier.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final goRouterProvider = Provider<GoRouter>((ref) {
  final refresh = ref.watch(routerRefreshNotifierProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: AppRoutes.login,
    refreshListenable: refresh,
    redirect: (context, state) => guardRedirect(ref, state),
    routes: [
      GoRoute(path: '/', builder: (context, state) => const SizedBox.shrink()),
      GoRoute(
        path: AppRoutes.login,
        name: AppRoutes.loginName,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.forgotPassword,
        name: AppRoutes.forgotPasswordName,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.dashboard,
        name: AppRoutes.dashboardName,
        builder: (context, state) => const DashboardScreen(),
      ),
      GoRoute(
        path: AppRoutes.fieldToday,
        name: AppRoutes.fieldTodayName,
        builder: (context, state) => const FieldTodayScreen(),
      ),
      GoRoute(
        path: AppRoutes.blocked,
        name: AppRoutes.blockedName,
        builder: (context, state) => const BlockedScreen(),
      ),
      GoRoute(
        path: AppRoutes.products,
        name: AppRoutes.productsName,
        builder: (context, state) => const ProductListScreen(),
      ),
      GoRoute(
        path: AppRoutes.productsNew,
        name: AppRoutes.productsNewName,
        builder: (context, state) => const ProductWizardScreen(),
      ),
      GoRoute(
        path: AppRoutes.productsEdit,
        name: AppRoutes.productsEditName,
        builder: (context, state) =>
            ProductWizardScreen(productId: state.pathParameters['id']),
      ),
      GoRoute(
        path: AppRoutes.productsDetail,
        name: AppRoutes.productsDetailName,
        builder: (context, state) =>
            ProductDetailScreen(productId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.productUnitsDetail,
        name: AppRoutes.productUnitsDetailName,
        builder: (context, state) =>
            ProductUnitDetailScreen(unitId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.warehouses,
        name: AppRoutes.warehousesName,
        builder: (context, state) => const WarehousesScreen(),
      ),
      GoRoute(
        path: AppRoutes.inventory,
        name: AppRoutes.inventoryName,
        builder: (context, state) => InventoryScreen(
          initialWarehouseId: state.uri.queryParameters['warehouseId'],
        ),
      ),
      GoRoute(
        path: AppRoutes.customersEdit,
        name: AppRoutes.customersEditName,
        builder: (context, state) =>
            CustomerEditScreen(customerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.customersDetail,
        name: AppRoutes.customersDetailName,
        builder: (context, state) =>
            CustomerDetailScreen(customerId: state.pathParameters['id']!),
      ),
      GoRoute(
        path: AppRoutes.customers,
        name: AppRoutes.customersName,
        builder: (context, state) => const CustomersHubScreen(),
      ),
      GoRoute(
        path: AppRoutes.suppliersDetail,
        name: AppRoutes.suppliersDetailName,
        builder: (context, state) => SupplierDetailPlaceholderScreen(
          supplierId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.suppliers,
        name: AppRoutes.suppliersName,
        builder: (context, state) =>
            const CustomersHubScreen(initialTab: CustomersHubTab.suppliers),
      ),
      GoRoute(
        path: AppRoutes.accounts,
        name: AppRoutes.accountsName,
        builder: (context, state) => const ChartOfAccountsScreen(),
      ),
      GoRoute(
        path: AppRoutes.inventoryMovements,
        name: AppRoutes.inventoryMovementsName,
        builder: (context, state) => const InventoryMovementsScreen(),
      ),
      GoRoute(
        path: AppRoutes.inventoryTransfers,
        name: AppRoutes.inventoryTransfersName,
        builder: (context, state) => const InventoryTransfersScreen(),
      ),
      GoRoute(
        path: AppRoutes.templateSettings,
        name: AppRoutes.templateSettingsName,
        builder: (context, state) => const TemplateSettingsScreen(),
      ),
      GoRoute(
        path: AppRoutes.taxSettings,
        name: AppRoutes.taxSettingsName,
        builder: (context, state) => TaxSettingsPlaceholderScreen(),
      ),
      GoRoute(
        path: AppRoutes.invoicesNewSales,
        name: AppRoutes.invoicesNewSalesName,
        builder: (context, state) =>
            InvoiceFormPlaceholderScreen(mode: InvoiceFormMode.sales),
      ),
      GoRoute(
        path: AppRoutes.invoicesNewPurchase,
        name: AppRoutes.invoicesNewPurchaseName,
        builder: (context, state) =>
            InvoiceFormPlaceholderScreen(mode: InvoiceFormMode.purchase),
      ),
      GoRoute(
        path: AppRoutes.invoiceReturn,
        name: AppRoutes.invoiceReturnName,
        builder: (context, state) => InvoiceReturnPlaceholderScreen(
          invoiceId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.invoicesDetail,
        name: AppRoutes.invoicesDetailName,
        builder: (context, state) => InvoiceDetailPlaceholderScreen(
          invoiceId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.invoices,
        name: AppRoutes.invoicesName,
        builder: (context, state) => InvoiceListPlaceholderScreen(),
      ),
      GoRoute(
        path: AppRoutes.vouchersNewReceipt,
        name: AppRoutes.vouchersNewReceiptName,
        builder: (context, state) =>
            VoucherFormPlaceholderScreen(mode: VoucherFormMode.receipt),
      ),
      GoRoute(
        path: AppRoutes.vouchersNewPayment,
        name: AppRoutes.vouchersNewPaymentName,
        builder: (context, state) =>
            VoucherFormPlaceholderScreen(mode: VoucherFormMode.payment),
      ),
      GoRoute(
        path: AppRoutes.vouchersDetail,
        name: AppRoutes.vouchersDetailName,
        builder: (context, state) => VoucherDetailPlaceholderScreen(
          voucherId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.vouchers,
        name: AppRoutes.vouchersName,
        builder: (context, state) => VoucherListPlaceholderScreen(),
      ),
      GoRoute(
        path: AppRoutes.journalDetail,
        name: AppRoutes.journalDetailName,
        builder: (context, state) => JournalDetailPlaceholderScreen(
          entryId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.journal,
        name: AppRoutes.journalName,
        builder: (context, state) => JournalListPlaceholderScreen(),
      ),
      GoRoute(
        path: AppRoutes.cashBank,
        name: AppRoutes.cashBankName,
        builder: (context, state) => CashBankPlaceholderScreen(),
      ),
      GoRoute(
        path: AppRoutes.inventoryDocumentsOpeningStock,
        name: AppRoutes.inventoryDocumentsOpeningStockName,
        builder: (context, state) => InventoryDocumentFormPlaceholderScreen(
          mode: InventoryDocumentFormMode.openingStock,
        ),
      ),
      GoRoute(
        path: AppRoutes.inventoryDocumentsStockIn,
        name: AppRoutes.inventoryDocumentsStockInName,
        builder: (context, state) => InventoryDocumentFormPlaceholderScreen(
          mode: InventoryDocumentFormMode.stockIn,
        ),
      ),
      GoRoute(
        path: AppRoutes.inventoryDocumentsStockOut,
        name: AppRoutes.inventoryDocumentsStockOutName,
        builder: (context, state) => InventoryDocumentFormPlaceholderScreen(
          mode: InventoryDocumentFormMode.stockOut,
        ),
      ),
      GoRoute(
        path: AppRoutes.inventoryDocumentsStockCount,
        name: AppRoutes.inventoryDocumentsStockCountName,
        builder: (context, state) => InventoryDocumentFormPlaceholderScreen(
          mode: InventoryDocumentFormMode.stockCount,
        ),
      ),
      GoRoute(
        path: AppRoutes.inventoryDocumentsDetail,
        name: AppRoutes.inventoryDocumentsDetailName,
        builder: (context, state) => InventoryDocumentDetailPlaceholderScreen(
          documentId: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: AppRoutes.inventoryDocuments,
        name: AppRoutes.inventoryDocumentsName,
        builder: (context, state) => InventoryDocumentListPlaceholderScreen(),
      ),
      GoRoute(
        path: AppRoutes.documentPreview,
        name: AppRoutes.documentPreviewName,
        builder: (context, state) {
          final query = state.uri.queryParameters;
          final kind = DocumentKind.fromDocumentType(query['kind']);
          final entityId = query['entityId'];
          if (kind == null || entityId == null || entityId.isEmpty) {
            return const Scaffold(
              body: Center(child: Text('Invalid document preview request')),
            );
          }
          DateTime? parseDate(String? raw) =>
              raw == null || raw.isEmpty ? null : DateTime.tryParse(raw);
          return DocumentPreviewScreen(
            args: DocumentPreviewArgs(
              kind: kind,
              entityId: entityId,
              fromDate: parseDate(query['from']),
              toDate: parseDate(query['to']),
            ),
          );
        },
      ),
    ],
  );
});
