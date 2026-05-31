import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../suppliers/domain/supplier_permissions.dart';
import '../../suppliers/presentation/suppliers_tab_body.dart';
import '../domain/customer_permissions.dart';
import 'customers_tab_body.dart';

enum CustomersHubTab { customers, suppliers }

class CustomersHubScreen extends ConsumerWidget {
  const CustomersHubScreen({this.initialTab, super.key});

  final CustomersHubTab? initialTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(authControllerProvider).valueOrNull;

    final showCustomers = session != null && canViewCustomers(session);
    final showSuppliers = session != null && canViewSuppliers(session);

    final visibleTabCount =
        (showCustomers ? 1 : 0) + (showSuppliers ? 1 : 0);

    Widget body;
    if (visibleTabCount == 0) {
      body = _PlaceholderBody(message: l10n.moduleAccessUnavailable);
    } else if (visibleTabCount == 1) {
      body = showCustomers
          ? const CustomersTabBody()
          : const SuppliersTabBody();
    } else {
      final initialIndex = _resolveInitialIndex(
        showCustomers: showCustomers,
        showSuppliers: showSuppliers,
        initialTab: initialTab,
      );
      body = DefaultTabController(
        length: 2,
        initialIndex: initialIndex,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TabBar(
              tabs: [
                Tab(key: const Key('customers-tab'), text: l10n.customers),
                Tab(key: const Key('suppliers-tab'), text: l10n.suppliers),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  CustomersTabBody(),
                  SuppliersTabBody(),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return AppShell(
      title: l10n.customers,
      currentRoute: AppRoutes.customers,
      body: body,
    );
  }

  int _resolveInitialIndex({
    required bool showCustomers,
    required bool showSuppliers,
    required CustomersHubTab? initialTab,
  }) {
    if (initialTab == CustomersHubTab.suppliers && showSuppliers) {
      return 1;
    }
    return 0;
  }
}

class _PlaceholderBody extends StatelessWidget {
  const _PlaceholderBody({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Text(
          message,
          style: theme.textTheme.bodyLarge,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
