import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/domain/app_session.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../network/supabase_providers.dart';
import 'app_routes.dart';

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
  'vouchers.view',
  'inventory.view',
  'warehouses.view',
  'inventory_movements.view',
  'inventory_movements.create',
  'product_units.view',
  'suppliers.view',
  'chart_of_accounts.view',
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
  final match =
      RegExp(r'^/products/([^/]+)/edit$').firstMatch(_normalizePath(path));
  if (match == null) return false;
  return match.group(1)! != 'new';
}

/// True for `/customers/{segment}/edit` where segment is not `new`.
bool isCustomerEditPath(String path) {
  final match =
      RegExp(r'^/customers/([^/]+)/edit$').firstMatch(_normalizePath(path));
  if (match == null) return false;
  return match.group(1)! != 'new';
}

/// True for `/customers/{segment}` where segment is not `new`.
bool isCustomerDetailPath(String path) {
  final match = RegExp(r'^/customers/([^/]+)$').firstMatch(_normalizePath(path));
  if (match == null) return false;
  return match.group(1)! != 'new';
}

/// True for `/suppliers/{segment}` where segment is not `new`.
bool isSupplierDetailPath(String path) {
  final match = RegExp(r'^/suppliers/([^/]+)$').firstMatch(_normalizePath(path));
  if (match == null) return false;
  return match.group(1)! != 'new';
}

bool _canViewCustomersInline(AppSession session) =>
    session.permissions.can('customers.view');

bool _canAccessCustomerEditInline(AppSession session) =>
    _canViewCustomersInline(session) &&
    session.permissions.can('customers.edit');

/// Inner path permission validation helper.
bool _isPathAllowed(String path, AppSession session) {
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

  if (!_isPathAllowed(normalized, session)) {
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
    hasSupabaseSession: ref.read(supabaseSessionProvider) != null,
    authState: ref.read(authControllerProvider),
  );
}
