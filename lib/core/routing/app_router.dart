import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/blocked_screen.dart';
import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/field_ops/presentation/field_today_screen.dart';
import '../../features/products/presentation/product_list_screen.dart';
import '../../features/products/presentation/products_placeholder_screen.dart';
import '../../features/inventory/presentation/inventory_placeholder_screen.dart';
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
        builder: (context, state) => const ProductsPlaceholderScreen(
          mode: ProductsViewMode.create,
        ),
      ),
      GoRoute(
        path: AppRoutes.productsDetail,
        name: AppRoutes.productsDetailName,
        builder: (context, state) => ProductsPlaceholderScreen(
          mode: ProductsViewMode.detail,
          productId: state.pathParameters['id'],
        ),
      ),
      GoRoute(
        path: AppRoutes.warehouses,
        name: AppRoutes.warehousesName,
        builder: (context, state) => const InventoryPlaceholderScreen(
          mode: InventoryViewMode.warehouses,
        ),
      ),
      GoRoute(
        path: AppRoutes.inventory,
        name: AppRoutes.inventoryName,
        builder: (context, state) => const InventoryPlaceholderScreen(
          mode: InventoryViewMode.balances,
        ),
      ),
      GoRoute(
        path: AppRoutes.inventoryMovements,
        name: AppRoutes.inventoryMovementsName,
        builder: (context, state) => const InventoryPlaceholderScreen(
          mode: InventoryViewMode.movements,
        ),
      ),
      GoRoute(
        path: AppRoutes.inventoryTransfers,
        name: AppRoutes.inventoryTransfersName,
        builder: (context, state) => const InventoryPlaceholderScreen(
          mode: InventoryViewMode.transfers,
        ),
      ),
    ],
  );
});
