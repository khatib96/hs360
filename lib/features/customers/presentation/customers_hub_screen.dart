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

    final selectedTab =
        initialTab == CustomersHubTab.suppliers && showSuppliers ||
            !showCustomers && showSuppliers
        ? CustomersHubTab.suppliers
        : CustomersHubTab.customers;
    Widget body;
    if (!showCustomers && !showSuppliers) {
      body = _PlaceholderBody(message: l10n.moduleAccessUnavailable);
    } else {
      body = selectedTab == CustomersHubTab.suppliers
          ? const SuppliersTabBody()
          : const CustomersTabBody();
    }

    return AppShell(
      title: selectedTab == CustomersHubTab.suppliers
          ? l10n.suppliers
          : l10n.customers,
      currentRoute: selectedTab == CustomersHubTab.suppliers
          ? AppRoutes.suppliers
          : AppRoutes.customers,
      body: body,
    );
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
