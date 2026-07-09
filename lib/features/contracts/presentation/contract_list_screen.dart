import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/presentation/finance_placeholder_screen.dart';
import '../../invoices/presentation/widgets/invoice_design.dart';
import '../domain/contract_permissions.dart';

class ContractListScreen extends ConsumerWidget {
  const ContractListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(authControllerProvider).valueOrNull;

    if (session != null && !canViewContracts(session)) {
      return FinancePlaceholderScreen(
        titleGetter: (l) => l.contractTitle,
        bodyGetter: (l) => l.financeModuleAccessUnavailable,
        canView: (_) => false,
        currentRoute: AppRoutes.contracts,
      );
    }

    final actions = <Widget>[];
    if (session != null && canCreateContract(session)) {
      actions.add(
        FilledButton.icon(
          onPressed: () => context.go(AppRoutes.contractsNew),
          icon: const Icon(Icons.add, size: 18),
          label: Text(l10n.contractCreateNew),
        ),
      );
    }

    return AppShell(
      title: l10n.contractTitle,
      currentRoute: AppRoutes.contracts,
      actions: actions,
      body: SingleChildScrollView(
        padding: InvoiceDesign.pagePadding,
        child: DecoratedBox(
          decoration: InvoiceDesign.panel,
          child: Padding(
            padding: const EdgeInsetsDirectional.all(24),
            child: Text(
              l10n.contractListPrepared,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
          ),
        ),
      ),
    );
  }
}
