import '../../features/auth/domain/app_session.dart';
import '../documents/domain/document_kind.dart';
import 'app_navigation_catalog.dart';
import 'app_navigation_models.dart';
import 'app_routes.dart';
import 'route_guards.dart';

export 'app_navigation_catalog.dart' show appNavigationModules;
export 'app_navigation_models.dart';

bool canShowGlobalSearchAnchor(AppSession session) {
  if (session.isManager) return true;
  return session.permissions.hasAny(const [
    'customers.view',
    'suppliers.view',
    'contracts.view',
    'invoices.view',
    'invoices.view_sales',
    'invoices.view_purchase',
    'invoices.view_returns',
    'products.view',
    'product_units.view',
  ]);
}

bool canShowQuickCreateAnchor(AppSession session) {
  if (session.isManager) return true;
  return session.permissions.hasAny(const [
    'customers.create',
    'suppliers.create',
    'products.create',
    'warehouses.create',
    'invoices.create_sales',
    'invoices.create_purchase',
    'invoices.create_sales_return',
    'invoices.create_purchase_return',
    'vouchers.create_receipt',
    'vouchers.create_payment',
    'contracts.create',
    'calendar.create',
    'inventory_movements.create',
    'inventory_documents.create_opening',
    'inventory_documents.create_adjustment',
    'inventory_documents.create_stock_count',
  ]);
}

bool canShowNotificationsAnchor(AppSession session) =>
    session.isManager || session.permissions.can('notifications.view');

List<AppNavigationModule> visibleNavigationModules(
  AppSession session, {
  AppNavigationArea? area,
}) {
  return appNavigationModules
      .where(
        (module) =>
            (area == null || module.area == area) && module.isVisible(session),
      )
      .toList(growable: false);
}

AppNavigationModule? resolveNavigationModule(
  Uri uri,
  AppSession session, {
  String? hintedPath,
}) {
  final path =
      _sourcePath(uri) ?? (uri.path.isNotEmpty ? uri.path : hintedPath);
  if (path == null || path.isEmpty) return null;

  AppNavigationModule? bestModule;
  var bestLength = -1;
  for (final module in visibleNavigationModules(session)) {
    for (final destination in module.visibleDestinations(session)) {
      if (!destination.matches(path)) continue;
      final length = destination.route.length;
      if (length > bestLength) {
        bestLength = length;
        bestModule = module;
      }
    }
  }
  return bestModule;
}

AppNavigationDestination? resolveNavigationDestination(
  Uri uri,
  AppSession session,
  AppNavigationModule? module, {
  String? hintedPath,
}) {
  if (module == null) return null;
  final path =
      _sourcePath(uri) ?? (uri.path.isNotEmpty ? uri.path : hintedPath);
  if (path == null || path.isEmpty) return null;

  AppNavigationDestination? best;
  for (final destination in module.visibleDestinations(session)) {
    if (!destination.matches(path)) continue;
    if (best == null || destination.route.length > best.route.length) {
      best = destination;
    }
  }
  return best;
}

bool shouldShowShellBackButton(Uri uri, AppNavigationDestination? destination) {
  final path = uri.path;
  if (path.isEmpty || path == AppRoutes.blocked) return false;
  if (path == AppRoutes.calendarRoute ||
      path == AppRoutes.inventoryTransfers ||
      path == AppRoutes.documentPreview) {
    return true;
  }
  return destination == null || path != destination.route;
}

String shellBackTarget(
  Uri uri,
  AppSession session,
  AppNavigationModule? module,
) {
  final path = uri.path;
  if (path == AppRoutes.calendarRoute) {
    final date = uri.queryParameters['date'];
    return date == null
        ? AppRoutes.calendar
        : Uri(
            path: AppRoutes.calendar,
            queryParameters: {'date': date},
          ).toString();
  }
  if (path == AppRoutes.documentPreview) {
    return _documentSourcePath(uri) ?? resolveHomeRoute(session);
  }
  if (path == AppRoutes.productsNew) return AppRoutes.products;
  final productEdit = RegExp(r'^/products/([^/]+)/edit$').firstMatch(path);
  if (productEdit != null) {
    return '/products/${productEdit.group(1)!}';
  }
  if (path.startsWith('/products/') || path.startsWith('/product-units/')) {
    return AppRoutes.products;
  }
  final customerEdit = RegExp(r'^/customers/([^/]+)/edit$').firstMatch(path);
  if (customerEdit != null) {
    return '/customers/${customerEdit.group(1)!}';
  }
  if (path.startsWith('/customers/')) return AppRoutes.customers;
  if (path.startsWith('/suppliers/')) return AppRoutes.suppliers;
  final contractConvert = RegExp(
    r'^/contracts/([^/]+)/convert$',
  ).firstMatch(path);
  if (contractConvert != null) {
    return '/contracts/${contractConvert.group(1)!}';
  }
  if (path.startsWith('/contracts/')) return AppRoutes.contracts;
  final invoiceReturn = RegExp(r'^/invoices/([^/]+)/return$').firstMatch(path);
  if (invoiceReturn != null) {
    return '/invoices/${invoiceReturn.group(1)!}';
  }
  if (path.startsWith('/invoices/')) return AppRoutes.invoices;
  if (path.startsWith('/vouchers/')) return AppRoutes.vouchers;
  if (path.startsWith('/journal/')) return AppRoutes.journal;
  if (path == AppRoutes.inventoryTransfers) return AppRoutes.inventory;
  if (path.startsWith('/inventory/documents/')) {
    return AppRoutes.inventoryDocuments;
  }
  if (module != null && module.isVisible(session)) {
    return module.landingRoute(session);
  }
  return resolveHomeRoute(session);
}

String? _sourcePath(Uri uri) {
  if (uri.path != AppRoutes.documentPreview) return null;
  return _documentSourcePath(uri);
}

String? _documentSourcePath(Uri uri) {
  final id = uri.queryParameters['entityId'];
  final kind = DocumentKind.fromDocumentType(uri.queryParameters['kind']);
  if (id == null || id.isEmpty || kind == null) return null;
  final encoded = Uri.encodeComponent(id);
  return switch (kind) {
    DocumentKind.salesInvoice ||
    DocumentKind.purchaseInvoice => '/invoices/$encoded',
    DocumentKind.receiptVoucher ||
    DocumentKind.paymentVoucher => '/vouchers/$encoded',
    DocumentKind.customerStatement => '/customers/$encoded',
    DocumentKind.assetTagLabel => '/product-units/$encoded',
    DocumentKind.contract => '/contracts/$encoded',
  };
}
