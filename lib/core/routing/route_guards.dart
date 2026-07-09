import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/app_session.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/contracts/domain/contract_permissions.dart';
import '../../features/finance_shared/domain/finance_permissions.dart';
import '../../features/invoices/domain/invoice_type.dart';
import '../network/supabase_providers.dart';
import '../documents/domain/document_kind.dart';
import '../documents/domain/document_permissions.dart';
import 'app_routes.dart';

export '../../features/contracts/domain/contract_permissions.dart';
export '../../features/finance_shared/domain/finance_permissions.dart';

const _fieldPermissionIds = [
  'visits.view_assigned',
  'visits.edit_assigned',
  'visits.complete_refill',
];

const _officePermissionIds = [
  'dashboard.view',
  'products.view',
  'products.create',
  'products.edit',
  'customers.view',
  'contracts.view',
  'invoices.view',
  'invoices.view_sales',
  'invoices.view_purchase',
  'invoices.view_returns',
  'vouchers.view',
  'journal.view',
  'cash_bank.view',
  'inventory.view',
  'warehouses.view',
  'inventory_movements.view',
  'inventory_movements.create',
  'product_units.view',
  'suppliers.view',
  'chart_of_accounts.view',
  'settings.templates.view',
  'settings.templates.edit',
  'settings.tax.view',
  'settings.tax.edit',
];

bool isPublicRoute(String path) =>
    path == AppRoutes.login || path == AppRoutes.forgotPassword;

String resolveHomeRoute(AppSession session) {
  if (session.isManager) return AppRoutes.dashboard;
  if (session.permissions.hasAny(_fieldPermissionIds)) {
    return AppRoutes.fieldToday;
  }
  if (session.permissions.hasAny(_officePermissionIds)) {
    return AppRoutes.dashboard;
  }
  return AppRoutes.blocked;
}

bool canAccessDashboard(AppSession session) =>
    session.isManager || session.permissions.hasAny(_officePermissionIds);

bool canAccessField(AppSession session) =>
    session.isManager || session.permissions.hasAny(_fieldPermissionIds);

/// True for `/products/{segment}/edit` where segment is not `new`.
bool isProductEditPath(String path) {
  final match = RegExp(
    r'^/products/([^/]+)/edit$',
  ).firstMatch(_normalizePath(path));
  if (match == null) return false;
  return match.group(1)! != 'new';
}

/// True for `/customers/{segment}/edit` where segment is not `new`.
bool isCustomerEditPath(String path) {
  final match = RegExp(
    r'^/customers/([^/]+)/edit$',
  ).firstMatch(_normalizePath(path));
  if (match == null) return false;
  return match.group(1)! != 'new';
}

/// True for `/customers/{segment}` where segment is not `new`.
bool isCustomerDetailPath(String path) {
  final match = RegExp(
    r'^/customers/([^/]+)$',
  ).firstMatch(_normalizePath(path));
  if (match == null) return false;
  return match.group(1)! != 'new';
}

/// True for `/suppliers/{segment}` where segment is not `new`.
bool isSupplierDetailPath(String path) {
  final match = RegExp(
    r'^/suppliers/([^/]+)$',
  ).firstMatch(_normalizePath(path));
  if (match == null) return false;
  return match.group(1)! != 'new';
}

bool isInvoiceDetailPath(String path) {
  final match = RegExp(r'^/invoices/([^/]+)$').firstMatch(_normalizePath(path));
  if (match == null) return false;
  final segment = match.group(1)!;
  return segment != 'new';
}

bool isInvoiceReturnPath(String path) {
  return RegExp(r'^/invoices/([^/]+)/return$').hasMatch(_normalizePath(path));
}

bool isInvoicesNewSalesPath(String path) =>
    _normalizePath(path) == AppRoutes.invoicesNewSales;

bool isInvoicesNewPurchasePath(String path) =>
    _normalizePath(path) == AppRoutes.invoicesNewPurchase;

bool isInvoicesNewSalesReturnPath(String path) =>
    _normalizePath(path) == AppRoutes.invoicesNewSalesReturn;

bool isInvoicesNewPurchaseReturnPath(String path) =>
    _normalizePath(path) == AppRoutes.invoicesNewPurchaseReturn;

bool isVoucherDetailPath(String path) {
  final match = RegExp(r'^/vouchers/([^/]+)$').firstMatch(_normalizePath(path));
  if (match == null) return false;
  return match.group(1)! != 'new';
}

bool isVouchersNewReceiptPath(String path) =>
    _normalizePath(path) == AppRoutes.vouchersNewReceipt;

bool isVouchersNewPaymentPath(String path) =>
    _normalizePath(path) == AppRoutes.vouchersNewPayment;

bool isContractsNewPath(String path) =>
    _normalizePath(path) == AppRoutes.contractsNew;

bool isContractConvertPath(String path) {
  return RegExp(r'^/contracts/([^/]+)/convert$').hasMatch(_normalizePath(path));
}

bool isContractDetailPath(String path) {
  final match = RegExp(
    r'^/contracts/([^/]+)$',
  ).firstMatch(_normalizePath(path));
  if (match == null) return false;
  return match.group(1)! != 'new';
}

bool isJournalDetailPath(String path) {
  final match = RegExp(r'^/journal/([^/]+)$').firstMatch(_normalizePath(path));
  return match != null;
}

bool isInventoryDocumentDetailPath(String path) {
  final normalized = _normalizePath(path);
  if (normalized == AppRoutes.inventoryDocumentsOpeningStock ||
      normalized == AppRoutes.inventoryDocumentsStockIn ||
      normalized == AppRoutes.inventoryDocumentsStockOut ||
      normalized == AppRoutes.inventoryDocumentsStockCount) {
    return false;
  }
  return RegExp(r'^/inventory/documents/([^/]+)$').hasMatch(normalized);
}

bool _canViewCustomersInline(AppSession session) =>
    session.permissions.can('customers.view');

bool _canAccessCustomerEditInline(AppSession session) =>
    _canViewCustomersInline(session) &&
    session.permissions.can('customers.edit');

bool _canViewInvoiceDetail(
  AppSession session, {
  Map<String, String> queryParameters = const {},
}) {
  final typeRaw = queryParameters['type'];
  if (typeRaw == null || typeRaw.isEmpty) {
    return canViewAnyInvoices(session);
  }
  try {
    final type = InvoiceType.fromDb(typeRaw);
    return switch (type) {
      InvoiceType.sales => canViewSalesInvoices(session),
      InvoiceType.purchase => canViewPurchaseInvoices(session),
      InvoiceType.salesReturn ||
      InvoiceType.purchaseReturn => canViewReturnInvoices(session),
    };
  } on FormatException {
    return canViewAnyInvoices(session);
  }
}

/// Inner path permission validation helper.
bool _isPathAllowed(
  String path,
  AppSession session, {
  Map<String, String> queryParameters = const {},
}) {
  if (session.isManager) return true;

  if (path == AppRoutes.productsNew) {
    return session.permissions.can('products.create');
  }
  if (isProductEditPath(path)) {
    return session.permissions.can('products.view') &&
        session.permissions.can('products.edit');
  }
  if (path == AppRoutes.products || path.startsWith('/products/')) {
    return session.permissions.can('products.view');
  }
  if (path.startsWith('/product-units/')) {
    return session.permissions.can('product_units.view');
  }
  if (path == AppRoutes.warehouses) {
    return session.permissions.can('warehouses.view');
  }
  if (path == AppRoutes.inventoryMovements) {
    return session.permissions.can('inventory_movements.view');
  }
  if (path == AppRoutes.inventoryTransfers) {
    return session.permissions.can('inventory_movements.create');
  }
  if (path == AppRoutes.inventory) {
    return session.permissions.can('inventory.view');
  }

  if (isCustomerEditPath(path)) {
    return _canAccessCustomerEditInline(session);
  }
  if (isCustomerDetailPath(path)) {
    return _canViewCustomersInline(session);
  }
  if (path == AppRoutes.customers) {
    return session.permissions.can('customers.view') ||
        session.permissions.can('suppliers.view');
  }
  if (isSupplierDetailPath(path)) {
    return session.permissions.can('suppliers.view');
  }
  if (path == AppRoutes.suppliers) {
    return session.permissions.can('suppliers.view');
  }
  if (path == AppRoutes.accounts) {
    return session.permissions.can('chart_of_accounts.view');
  }
  if (path == AppRoutes.templateSettings) {
    return session.permissions.can('settings.templates.view') ||
        session.permissions.can('settings.templates.edit');
  }
  if (path == AppRoutes.taxSettings) {
    return canViewTaxSettings(session);
  }
  if (path == AppRoutes.documentPreview) {
    final kind = DocumentKind.fromDocumentType(queryParameters['kind']);
    if (kind == null) return false;
    return canPreviewDocument(session, kind);
  }

  if (path == AppRoutes.invoices) {
    return canViewAnyInvoices(session);
  }
  if (isInvoicesNewSalesPath(path)) {
    return canCreateSalesInvoice(session);
  }
  if (isInvoicesNewPurchasePath(path)) {
    final draftId = queryParameters['draftId']?.trim();
    if (draftId != null && draftId.isNotEmpty) {
      return canEditInvoiceDraft(session);
    }
    return canCreatePurchaseInvoice(session);
  }
  if (isInvoicesNewSalesReturnPath(path)) {
    return canCreateSalesReturn(session);
  }
  if (isInvoicesNewPurchaseReturnPath(path)) {
    return canCreatePurchaseReturn(session);
  }
  if (isInvoiceReturnPath(path)) {
    return canCreateAnyReturn(session);
  }
  if (isInvoiceDetailPath(path)) {
    return _canViewInvoiceDetail(session, queryParameters: queryParameters);
  }
  if (path == AppRoutes.vouchers) {
    return canViewVouchers(session);
  }
  if (isVouchersNewReceiptPath(path)) {
    return canCreateReceiptVoucher(session);
  }
  if (isVouchersNewPaymentPath(path)) {
    return canCreatePaymentVoucher(session);
  }
  if (isVoucherDetailPath(path)) {
    return canViewVouchers(session);
  }
  if (path == AppRoutes.contracts) {
    return canViewContracts(session);
  }
  if (isContractsNewPath(path)) {
    return canCreateContract(session);
  }
  if (isContractConvertPath(path)) {
    return canConvertTrial(session);
  }
  if (isContractDetailPath(path)) {
    return canViewContracts(session);
  }
  if (path == AppRoutes.journal) {
    return canViewJournal(session);
  }
  if (isJournalDetailPath(path)) {
    return canViewJournal(session);
  }
  if (path == AppRoutes.cashBank) {
    return canViewCashBank(session);
  }
  if (path == AppRoutes.inventoryDocuments ||
      isInventoryDocumentDetailPath(path)) {
    return canViewInventoryDocuments(session);
  }
  if (path == AppRoutes.inventoryDocumentsOpeningStock) {
    return canCreateOpeningStock(session);
  }
  if (path == AppRoutes.inventoryDocumentsStockIn ||
      path == AppRoutes.inventoryDocumentsStockOut) {
    return canCreateInventoryAdjustment(session);
  }
  if (path == AppRoutes.inventoryDocumentsStockCount) {
    return canCreateStockCount(session);
  }

  // Dashboard and Field specific permissions
  if (path == AppRoutes.dashboard) {
    return canAccessDashboard(session);
  }
  if (path == AppRoutes.fieldToday) {
    return canAccessField(session);
  }

  return true;
}

/// Pure redirect logic for unit tests. Returns a path or null (no redirect).
String? guardRedirectForPath({
  required String path,
  Map<String, String> queryParameters = const {},
  required bool hasSupabaseSession,
  required AsyncValue<AppSession?> authState,
}) {
  final normalized = _normalizePath(path);

  if (!hasSupabaseSession) {
    if (isPublicRoute(normalized)) return null;
    return AppRoutes.login;
  }

  if (authState.isLoading) {
    return null;
  }

  if (authState.hasError || authState.valueOrNull == null) {
    if (isPublicRoute(normalized)) return null;
    return AppRoutes.login;
  }

  final session = authState.valueOrNull!;
  final home = resolveHomeRoute(session);

  if (isPublicRoute(normalized)) {
    return normalized == home ? null : home;
  }

  if (normalized == '/') {
    return home;
  }

  if (!_isPathAllowed(normalized, session, queryParameters: queryParameters)) {
    return normalized == home ? null : home;
  }

  if (normalized == AppRoutes.blocked) {
    return null;
  }

  return null;
}

String _normalizePath(String path) {
  if (path.isEmpty || path == '/') return path;
  return path.endsWith('/') && path.length > 1
      ? path.substring(0, path.length - 1)
      : path;
}

/// Thin wrapper for GoRouter — uses [ref.read] only (not watch).
String? guardRedirect(Ref ref, GoRouterState state) {
  return guardRedirectForPath(
    path: state.uri.path,
    queryParameters: state.uri.queryParameters,
    hasSupabaseSession: ref.read(supabaseSessionProvider) != null,
    authState: ref.read(authControllerProvider),
  );
}
