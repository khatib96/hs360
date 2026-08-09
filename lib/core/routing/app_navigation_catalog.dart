import 'package:flutter/material.dart';

import '../../features/accounting/domain/accounting_permissions.dart';
import '../../features/auth/domain/app_session.dart';
import '../../features/calendar/domain/calendar_permissions.dart';
import '../../features/customers/domain/customer_permissions.dart'
    hide canViewVouchers;
import '../../features/suppliers/domain/supplier_permissions.dart';
import '../documents/domain/document_permissions.dart';
import 'app_navigation_models.dart';
import 'app_routes.dart';
import 'route_guards.dart';

final List<AppNavigationModule> appNavigationModules = [
  AppNavigationModule(
    id: AppModuleId.dashboard,
    label: (l10n) => l10n.dashboard,
    icon: Icons.dashboard_outlined,
    destinations: [
      AppNavigationDestination(
        id: 'dashboard',
        label: (l10n) => l10n.dashboard,
        icon: Icons.dashboard_outlined,
        route: AppRoutes.dashboard,
        isVisible: canAccessDashboard,
        matchChildren: true,
      ),
    ],
  ),
  AppNavigationModule(
    id: AppModuleId.dailyActivity,
    label: (l10n) => l10n.dailyActivityTitle,
    icon: Icons.history_rounded,
    destinations: [
      AppNavigationDestination(
        id: 'daily-activity',
        label: (l10n) => l10n.dailyActivityTitle,
        icon: Icons.history_rounded,
        route: AppRoutes.dailyActivity,
        isVisible: canAccessDailyActivity,
      ),
    ],
  ),
  AppNavigationModule(
    id: AppModuleId.appointments,
    label: (l10n) => l10n.navAppointmentsVisits,
    icon: Icons.event_available_outlined,
    destinations: [
      AppNavigationDestination(
        id: 'calendar',
        label: (l10n) => l10n.navCalendar,
        icon: Icons.calendar_month_outlined,
        route: AppRoutes.calendar,
        isVisible: canAccessCalendar,
        matchChildren: true,
      ),
      AppNavigationDestination(
        id: 'today-agenda',
        label: (l10n) => l10n.fieldTodayTitle,
        icon: Icons.today_outlined,
        route: AppRoutes.fieldToday,
        isVisible: canAccessField,
      ),
      AppNavigationDestination(
        id: 'route-view',
        label: (l10n) => l10n.calendarRouteTitle,
        icon: Icons.route_outlined,
        route: AppRoutes.calendarRoute,
        isVisible: canAccessCalendar,
      ),
    ],
  ),
  AppNavigationModule(
    id: AppModuleId.contracts,
    label: (l10n) => l10n.navContracts,
    icon: Icons.assignment_outlined,
    destinations: [
      AppNavigationDestination(
        id: 'contracts',
        label: (l10n) => l10n.navContracts,
        icon: Icons.assignment_outlined,
        route: AppRoutes.contracts,
        isVisible: canViewContracts,
        matchChildren: true,
      ),
    ],
  ),
  AppNavigationModule(
    id: AppModuleId.parties,
    label: (l10n) => l10n.navCustomersSuppliers,
    icon: Icons.groups_outlined,
    destinations: [
      AppNavigationDestination(
        id: 'customers',
        label: (l10n) => l10n.customers,
        icon: Icons.people_outline,
        route: AppRoutes.customers,
        isVisible: canViewCustomers,
        matchChildren: true,
      ),
      AppNavigationDestination(
        id: 'suppliers',
        label: (l10n) => l10n.suppliers,
        icon: Icons.local_shipping_outlined,
        route: AppRoutes.suppliers,
        isVisible: canViewSuppliers,
        matchChildren: true,
      ),
    ],
  ),
  AppNavigationModule(
    id: AppModuleId.finance,
    label: (l10n) => l10n.navFinance,
    icon: Icons.account_balance_outlined,
    destinations: [
      AppNavigationDestination(
        id: 'invoices',
        label: (l10n) => l10n.navInvoices,
        icon: Icons.receipt_long_outlined,
        route: AppRoutes.invoices,
        isVisible: canViewAnyInvoices,
        matchChildren: true,
      ),
      AppNavigationDestination(
        id: 'vouchers',
        label: (l10n) => l10n.navVouchers,
        icon: Icons.payments_outlined,
        route: AppRoutes.vouchers,
        isVisible: canViewVouchers,
        matchChildren: true,
      ),
      AppNavigationDestination(
        id: 'cash-bank',
        label: (l10n) => l10n.navCashBank,
        icon: Icons.account_balance_wallet_outlined,
        route: AppRoutes.cashBank,
        isVisible: canViewCashBank,
      ),
      AppNavigationDestination(
        id: 'accounts',
        label: (l10n) => l10n.chartOfAccounts,
        icon: Icons.account_tree_outlined,
        route: AppRoutes.accounts,
        isVisible: canViewChartOfAccounts,
      ),
      AppNavigationDestination(
        id: 'journal',
        label: (l10n) => l10n.navJournal,
        icon: Icons.menu_book_outlined,
        route: AppRoutes.journal,
        isVisible: canViewJournal,
        matchChildren: true,
      ),
    ],
  ),
  AppNavigationModule(
    id: AppModuleId.inventory,
    label: (l10n) => l10n.navInventory,
    icon: Icons.inventory_2_outlined,
    destinations: [
      AppNavigationDestination(
        id: 'inventory-balances',
        label: (l10n) => l10n.inventory,
        icon: Icons.assessment_outlined,
        route: AppRoutes.inventory,
        isVisible: (session) => _can(session, 'inventory.view'),
      ),
      AppNavigationDestination(
        id: 'products',
        label: (l10n) => l10n.products,
        icon: Icons.shopping_bag_outlined,
        route: AppRoutes.products,
        isVisible: (session) => _can(session, 'products.view'),
        matchChildren: true,
        additionalPrefixes: ['/product-units/'],
      ),
      AppNavigationDestination(
        id: 'warehouses',
        label: (l10n) => l10n.warehouses,
        icon: Icons.warehouse_outlined,
        route: AppRoutes.warehouses,
        isVisible: (session) => _can(session, 'warehouses.view'),
      ),
      AppNavigationDestination(
        id: 'inventory-documents',
        label: (l10n) => l10n.inventoryDocumentsTitle,
        icon: Icons.description_outlined,
        route: AppRoutes.inventoryDocuments,
        isVisible: canViewInventoryDocuments,
        matchChildren: true,
      ),
      AppNavigationDestination(
        id: 'inventory-movements',
        label: (l10n) => l10n.inventoryMovements,
        icon: Icons.history,
        route: AppRoutes.inventoryMovements,
        isVisible: (session) => _can(session, 'inventory_movements.view'),
      ),
      AppNavigationDestination(
        id: 'inventory-transfers',
        label: (l10n) => l10n.inventoryTransfers,
        icon: Icons.swap_horiz,
        route: AppRoutes.inventoryTransfers,
        isVisible: (session) => _can(session, 'inventory_movements.create'),
      ),
    ],
  ),
  AppNavigationModule(
    id: AppModuleId.settings,
    label: (l10n) => l10n.navSettings,
    icon: Icons.settings_outlined,
    area: AppNavigationArea.system,
    destinations: [
      AppNavigationDestination(
        id: 'template-settings',
        label: (l10n) => l10n.templateSettingsTitle,
        icon: Icons.description_outlined,
        route: AppRoutes.templateSettings,
        isVisible: canViewTemplateSettings,
      ),
      AppNavigationDestination(
        id: 'tax-settings',
        label: (l10n) => l10n.taxSettingsTitle,
        icon: Icons.percent_outlined,
        route: AppRoutes.taxSettings,
        isVisible: canViewTaxSettings,
      ),
      AppNavigationDestination(
        id: 'calendar-settings',
        label: (l10n) => l10n.calendarSettingsTitle,
        icon: Icons.calendar_month_outlined,
        route: AppRoutes.calendarSettings,
        isVisible: canViewCalendarSettings,
      ),
    ],
  ),
];

bool _can(AppSession session, String permissionId) =>
    session.isManager || session.permissions.can(permissionId);
