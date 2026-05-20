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
  'customers.view',
  'contracts.view',
  'invoices.view',
  'vouchers.view',
  'inventory.view',
  'warehouses.view',
  'inventory_movements.view',
  'inventory_movements.create',
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

/// Inner path permission validation helper.
bool _isPathAllowed(String path, AppSession session) {
  if (session.isManager) return true;

  if (path == AppRoutes.productsNew) {
    return session.permissions.can('products.create');
  }
  if (path == AppRoutes.products || path.startsWith('/products/')) {
    return session.permissions.can('products.view');
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
