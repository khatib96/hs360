import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_filter_bar.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/app_state_view.dart';
import '../../../shared/widgets/app_table_frame.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/presentation/finance_placeholder_screen.dart';
import '../../invoices/presentation/widgets/invoice_design.dart';
import '../domain/contract_permissions.dart';
import 'contract_display_helpers.dart';
import 'contract_list_controller.dart';
import 'widgets/contract_filters_bar.dart';
import 'widgets/contract_table.dart';

class ContractListScreen extends ConsumerWidget {
  const ContractListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final session = ref.watch(authControllerProvider).valueOrNull;
    final state = ref.watch(contractListControllerProvider);
    final controller = ref.read(contractListControllerProvider.notifier);

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

    final isWide = InvoiceDesign.isDesktop(context);
    Widget tableArea;
    if (state.isLoading && state.contracts.isEmpty) {
      tableArea = AppStateView.loading(message: l10n.loading);
    } else if (state.hasError && state.contracts.isEmpty) {
      tableArea = AppStateView.error(
        message: contractErrorMessage(l10n, state.errorCode!),
        action: FilledButton(
          onPressed: controller.refresh,
          child: Text(l10n.retry),
        ),
      );
    } else if (!state.isLoading && state.contracts.isEmpty) {
      tableArea = AppStateView.empty(
        icon: Icons.assignment_outlined,
        message: state.filters.hasActiveFilters
            ? l10n.contractListEmptyFiltered
            : l10n.contractListEmpty,
      );
    } else {
      tableArea = isWide
          ? ContractTable(
              contracts: state.contracts,
              languageCode: locale.languageCode,
            )
          : ContractCardList(
              contracts: state.contracts,
              languageCode: locale.languageCode,
            );
    }

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppFilterBar(
          compact: true,
          child: ContractFiltersBar(
            key: const Key('contract-filters-bar'),
            filters: state.filters,
            onTypeChanged: controller.setType,
            onStatusChanged: controller.setStatus,
            onSearchChanged: controller.setSearch,
            onDateFromChanged: controller.setDateFrom,
            onDateToChanged: controller.setDateTo,
            onLowProfitOverrideChanged: controller.setLowProfitOverrideOnly,
          ),
        ),
        const SizedBox(height: 12),
        Expanded(child: AppTableFrame(child: tableArea)),
        if (state.hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: state.isLoadingMore
                ? const Center(child: CircularProgressIndicator())
                : Center(
                    child: OutlinedButton(
                      onPressed: controller.loadMore,
                      child: Text(l10n.loadMore),
                    ),
                  ),
          ),
        if (state.loadMoreErrorCode != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Center(
              child: Text(contractErrorMessage(l10n, state.loadMoreErrorCode!)),
            ),
          ),
      ],
    );

    return AppShell(
      title: l10n.contractTitle,
      currentRoute: AppRoutes.contracts,
      actions: actions,
      body: Padding(padding: InvoiceDesign.pagePadding, child: body),
    );
  }
}
