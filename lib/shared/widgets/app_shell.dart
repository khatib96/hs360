import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../core/routing/app_routes.dart';
import '../../core/routing/route_guards.dart';
import '../../core/theme/app_theme.dart';
import '../../features/accounting/domain/accounting_permissions.dart';
import '../../features/auth/domain/app_session.dart';
import '../../features/auth/presentation/auth_controller.dart';
import '../../features/customers/domain/customer_permissions.dart'
    hide canViewVouchers;
import '../../core/documents/domain/document_permissions.dart';

class _NavItem {
  const _NavItem({
    required this.titleGetter,
    required this.icon,
    required this.route,
    required this.isVisible,
    this.matchChildren = false,
  });

  final String Function(AppLocalizations) titleGetter;
  final IconData icon;
  final String route;
  final bool Function(AppSession) isVisible;
  final bool matchChildren;
}

class AppShell extends ConsumerWidget {
  const AppShell({
    required this.title,
    required this.body,
    this.actions,
    this.currentRoute,
    super.key,
  });

  final String title;
  final Widget body;
  final List<Widget>? actions;
  final String? currentRoute;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);
    final session = authState.valueOrNull;

    if (session == null) {
      return Scaffold(
        appBar: AppBar(title: Text(title), actions: actions),
        body: SafeArea(child: body),
      );
    }

    String currentPath = currentRoute ?? '';
    try {
      currentPath = currentPath.isEmpty
          ? GoRouterState.of(context).uri.path
          : currentPath;
    } catch (_) {}

    final allItems = [
      _NavItem(
        titleGetter: (l) => l.dashboard,
        icon: Icons.dashboard_outlined,
        route: AppRoutes.dashboard,
        isVisible: canAccessDashboard,
      ),
      _NavItem(
        titleGetter: (l) => l.fieldTodayTitle,
        icon: Icons.assignment_outlined,
        route: AppRoutes.fieldToday,
        isVisible: canAccessField,
      ),
      _NavItem(
        titleGetter: (l) => l.products,
        icon: Icons.shopping_bag_outlined,
        route: AppRoutes.products,
        isVisible: (session) => _can(session, 'products.view'),
        matchChildren: true,
      ),
      _NavItem(
        titleGetter: (l) => l.productsNew,
        icon: Icons.add_box_outlined,
        route: AppRoutes.productsNew,
        isVisible: (session) => _can(session, 'products.create'),
      ),
      _NavItem(
        titleGetter: (l) => l.customers,
        icon: Icons.people_outline,
        route: AppRoutes.customers,
        isVisible: canViewCustomersArea,
        matchChildren: true,
      ),
      _NavItem(
        titleGetter: (l) => l.navContracts,
        icon: Icons.assignment_outlined,
        route: AppRoutes.contracts,
        isVisible: canViewContracts,
        matchChildren: true,
      ),
      _NavItem(
        titleGetter: (l) => l.navInvoices,
        icon: Icons.receipt_long_outlined,
        route: AppRoutes.invoices,
        isVisible: canViewAnyInvoices,
        matchChildren: true,
      ),
      _NavItem(
        titleGetter: (l) => l.navVouchers,
        icon: Icons.payments_outlined,
        route: AppRoutes.vouchers,
        isVisible: canViewVouchers,
        matchChildren: true,
      ),
      _NavItem(
        titleGetter: (l) => l.navJournal,
        icon: Icons.menu_book_outlined,
        route: AppRoutes.journal,
        isVisible: canViewJournal,
        matchChildren: true,
      ),
      _NavItem(
        titleGetter: (l) => l.navCashBank,
        icon: Icons.account_balance_wallet_outlined,
        route: AppRoutes.cashBank,
        isVisible: canViewCashBank,
      ),
      _NavItem(
        titleGetter: (l) => l.chartOfAccounts,
        icon: Icons.account_tree_outlined,
        route: AppRoutes.accounts,
        isVisible: canViewChartOfAccounts,
      ),
      _NavItem(
        titleGetter: (l) => l.warehouses,
        icon: Icons.warehouse_outlined,
        route: AppRoutes.warehouses,
        isVisible: (session) => _can(session, 'warehouses.view'),
      ),
      _NavItem(
        titleGetter: (l) => l.inventory,
        icon: Icons.assessment_outlined,
        route: AppRoutes.inventory,
        isVisible: (session) => _can(session, 'inventory.view'),
        matchChildren: true,
      ),
      _NavItem(
        titleGetter: (l) => l.inventoryMovements,
        icon: Icons.history,
        route: AppRoutes.inventoryMovements,
        isVisible: (session) => _can(session, 'inventory_movements.view'),
      ),
      _NavItem(
        titleGetter: (l) => l.inventoryTransfers,
        icon: Icons.swap_horiz,
        route: AppRoutes.inventoryTransfers,
        isVisible: (session) => _can(session, 'inventory_movements.create'),
      ),
      _NavItem(
        titleGetter: (l) => l.templateSettingsTitle,
        icon: Icons.description_outlined,
        route: AppRoutes.templateSettings,
        isVisible: canViewTemplateSettings,
      ),
    ];

    final authorizedItems = allItems
        .where((item) => item.isVisible(session))
        .toList();
    final activeRoute = _activeNavRoute(currentPath, authorizedItems);
    final isDesktop = MediaQuery.of(context).size.width > 768;

    if (isDesktop) {
      return Scaffold(
        body: Row(
          children: [
            _DesktopNavigation(
              l10n: l10n,
              theme: theme,
              activeRoute: activeRoute,
              items: authorizedItems,
            ),
            const VerticalDivider(width: 1, color: AppColors.neutral200),
            Expanded(
              child: Scaffold(
                appBar: AppBar(title: Text(title), actions: actions),
                body: SafeArea(child: body),
              ),
            ),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title), actions: actions),
      drawer: _MobileNavigationDrawer(
        l10n: l10n,
        theme: theme,
        session: session,
        activeRoute: activeRoute,
        items: authorizedItems,
      ),
      body: SafeArea(child: body),
    );
  }
}

class _DesktopNavigation extends StatelessWidget {
  const _DesktopNavigation({
    required this.l10n,
    required this.theme,
    required this.items,
    required this.activeRoute,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final List<_NavItem> items;
  final String? activeRoute;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.pureWhite),
      child: Stack(
        children: [
          const Positioned.fill(
            child: CustomPaint(painter: _ShellNavBackgroundPainter()),
          ),
          SizedBox(
            width: 240,
            child: SafeArea(
              child: Column(
                children: [
                  const Padding(
                    padding: EdgeInsetsDirectional.symmetric(
                      vertical: 24,
                      horizontal: 16,
                    ),
                    child: AppBrandMark(title: 'HS360', width: 180),
                  ),
                  const Divider(color: AppColors.neutral100, height: 1),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsetsDirectional.symmetric(
                        vertical: 12,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final isActive = activeRoute == item.route;

                        return _NavigationTile(
                          item: item,
                          l10n: l10n,
                          theme: theme,
                          isActive: isActive,
                          onTap: () => context.go(item.route),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MobileNavigationDrawer extends StatelessWidget {
  const _MobileNavigationDrawer({
    required this.l10n,
    required this.theme,
    required this.session,
    required this.items,
    required this.activeRoute,
  });

  final AppLocalizations l10n;
  final ThemeData theme;
  final AppSession session;
  final List<_NavItem> items;
  final String? activeRoute;

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: AppColors.pureWhite,
      child: Column(
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(color: AppColors.pureWhite),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: _ShellNavBackgroundPainter()),
                ),
                Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const AppBrandMark(title: 'HS360', width: 180),
                      const SizedBox(height: 8),
                      Text(
                        session.displayName,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.charcoal,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsetsDirectional.symmetric(vertical: 8),
              itemCount: items.length,
              itemBuilder: (context, index) {
                final item = items[index];
                final isActive = activeRoute == item.route;

                return _NavigationTile(
                  item: item,
                  l10n: l10n,
                  theme: theme,
                  isActive: isActive,
                  onTap: () {
                    Navigator.pop(context);
                    context.go(item.route);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _NavigationTile extends StatelessWidget {
  const _NavigationTile({
    required this.item,
    required this.l10n,
    required this.theme,
    required this.isActive,
    required this.onTap,
  });

  final _NavItem item;
  final AppLocalizations l10n;
  final ThemeData theme;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final foreground = isActive ? AppColors.pureWhite : AppColors.charcoal;

    final borderRadius = BorderRadius.circular(8);

    return Padding(
      padding: const EdgeInsetsDirectional.symmetric(
        horizontal: 12,
        vertical: 4,
      ),
      child: Material(
        color: isActive ? AppColors.gold : Colors.transparent,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: ListTile(
          contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
          leading: Icon(item.icon, color: foreground),
          title: Text(
            item.titleGetter(l10n),
            style: theme.textTheme.bodyMedium?.copyWith(
              color: foreground,
              fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          shape: RoundedRectangleBorder(borderRadius: borderRadius),
          tileColor: Colors.transparent,
          selected: isActive,
          selectedTileColor: Colors.transparent,
          onTap: onTap,
        ),
      ),
    );
  }
}

bool _can(AppSession session, String permissionId) =>
    session.isManager || session.permissions.can(permissionId);

String? _activeNavRoute(String currentPath, List<_NavItem> items) {
  _NavItem? bestMatch;

  for (final item in items) {
    if (!_matchesNavItem(currentPath, item)) continue;
    if (bestMatch == null || item.route.length > bestMatch.route.length) {
      bestMatch = item;
    }
  }

  return bestMatch?.route;
}

bool _matchesNavItem(String currentPath, _NavItem item) {
  if (currentPath == item.route) return true;
  return item.matchChildren && currentPath.startsWith('${item.route}/');
}

class _ShellNavBackgroundPainter extends CustomPainter {
  const _ShellNavBackgroundPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final ribbonPaint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 28
      ..strokeCap = StrokeCap.round;

    final finePaint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final accentPaint = Paint()
      ..color = AppColors.gold.withValues(alpha: 0.12)
      ..style = PaintingStyle.fill;

    final mainCurve = Path()
      ..moveTo(size.width * 0.08, size.height * 0.14)
      ..cubicTo(
        size.width * 0.46,
        size.height * 0.02,
        size.width * 0.56,
        size.height * 0.36,
        size.width * 1.04,
        size.height * 0.18,
      );
    canvas.drawPath(mainCurve, ribbonPaint);

    final lowerCurve = Path()
      ..moveTo(size.width * 0.04, size.height * 0.9)
      ..cubicTo(
        size.width * 0.36,
        size.height * 0.76,
        size.width * 0.7,
        size.height * 1.04,
        size.width * 1.08,
        size.height * 0.78,
      );
    canvas.drawPath(lowerCurve, finePaint);

    final corner = Path()
      ..moveTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.18)
      ..lineTo(size.width * 0.84, size.height * 0.06)
      ..close();
    canvas.drawPath(corner, accentPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AppBrandMark extends StatelessWidget {
  static const logoAssetPath = 'assets/brand/hs-logo-gold.png';

  const AppBrandMark({required this.title, this.width = 220, super.key});

  final String title;
  final double width;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      image: true,
      label: title,
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          child: Image.asset(
            logoAssetPath,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.high,
            errorBuilder: (context, error, stackTrace) {
              return Text(
                title,
                style: const TextStyle(
                  color: AppColors.gold,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
