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
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/domain/finance_permissions.dart';
import '../../finance_shared/presentation/finance_placeholder_screen.dart';
import '../domain/invoice_permissions.dart';
import '../domain/invoice_type.dart';
import 'invoice_list_controller.dart';
import 'invoice_display_helpers.dart';
import 'widgets/invoice_design.dart';
import 'widgets/invoice_filters_bar.dart';
import 'widgets/invoice_shared_widgets.dart';
import 'widgets/invoice_table.dart';

class InvoiceListScreen extends ConsumerWidget {
  const InvoiceListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final session = ref.watch(authControllerProvider).valueOrNull;
    final state = ref.watch(invoiceListControllerProvider);
    final controller = ref.read(invoiceListControllerProvider.notifier);

    if (session != null && !canViewAnyInvoices(session)) {
      return FinancePlaceholderScreen(
        titleGetter: (l) => l.invoiceTitle,
        bodyGetter: (l) => l.financeModuleAccessUnavailable,
        canView: (_) => false,
        currentRoute: AppRoutes.invoices,
      );
    }

    final availableTypes = session == null
        ? const <InvoiceType>[]
        : invoiceListTypeOptions(
            canViewSales: canViewSalesInvoices(session),
            canViewPurchase: canViewPurchaseInvoices(session),
            canViewReturns: canViewReturnInvoices(session),
          );

    final isWide = InvoiceDesign.isDesktop(context);

    Widget tableArea;
    if (state.isLoading && state.invoices.isEmpty) {
      tableArea = AppStateView.loading(message: l10n.loading);
    } else if (state.hasError && state.invoices.isEmpty) {
      tableArea = AppStateView.error(
        message: invoiceErrorMessage(l10n, state.errorCode!),
        action: FilledButton(
          onPressed: controller.refresh,
          child: Text(l10n.retry),
        ),
      );
    } else if (!state.isLoading && state.invoices.isEmpty) {
      tableArea = AppStateView.empty(
        icon: Icons.receipt_long_outlined,
        message: state.filters.hasActiveFilters
            ? l10n.invoiceListEmptyFiltered
            : l10n.invoiceListEmpty,
      );
    } else {
      tableArea = isWide
          ? InvoiceTable(
              invoices: state.invoices,
              languageCode: locale.languageCode,
            )
          : InvoiceCardList(
              invoices: state.invoices,
              languageCode: locale.languageCode,
            );
    }

    final tableContainer = AppTableFrame(child: tableArea);

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (availableTypes.isNotEmpty) ...[
          AppFilterBar(
            compact: true,
            child: InvoiceFiltersBar(
              key: const Key('invoice-filters-bar'),
              filters: state.filters,
              availableTypes: availableTypes,
              onTypeChanged: controller.setType,
              onStatusChanged: controller.setStatus,
              onSearchChanged: controller.setSearch,
              onDateFromChanged: controller.setDateFrom,
              onDateToChanged: controller.setDateTo,
            ),
          ),
          const SizedBox(height: 12),
        ],
        Expanded(child: tableContainer),
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
      ],
    );

    final actions = _buildActions(context, l10n, session, isWide);

    return AppShell(
      title: l10n.invoiceTitle,
      currentRoute: AppRoutes.invoices,
      actions: actions.isEmpty ? null : actions,
      body: Stack(
        children: [
          Padding(padding: InvoiceDesign.pagePadding, child: body),
          if (state.isLoading && state.invoices.isNotEmpty)
            const Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: LinearProgressIndicator(),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildActions(
    BuildContext context,
    AppLocalizations l10n,
    AppSession? session,
    bool isWide,
  ) {
    if (session == null) return const [];

    final canSales = canCreateSalesInvoice(session);
    final canPurchase = canCreatePurchaseInvoice(session);
    final canSalesReturn = canCreateSalesReturn(session);
    final canPurchaseReturn = canCreatePurchaseReturn(session);

    if (!canSales && !canPurchase && !canSalesReturn && !canPurchaseReturn) {
      return const [];
    }

    final items = <Widget>[
      if (canSales)
        MenuItemButton(
          leadingIcon: const Icon(Icons.point_of_sale_outlined, size: 18),
          onPressed: () => context.go(AppRoutes.invoicesNewSales),
          child: Text(invoiceTypeLabel(l10n, InvoiceType.sales)),
        ),
      if (canPurchase)
        MenuItemButton(
          leadingIcon: const Icon(Icons.shopping_cart_outlined, size: 18),
          onPressed: () => context.go(AppRoutes.invoicesNewPurchase),
          child: Text(invoiceTypeLabel(l10n, InvoiceType.purchase)),
        ),
      if (canSalesReturn)
        MenuItemButton(
          leadingIcon: const Icon(Icons.assignment_return_outlined, size: 18),
          onPressed: () => context.go(AppRoutes.invoicesNewSalesReturn),
          child: Text(invoiceTypeLabel(l10n, InvoiceType.salesReturn)),
        ),
      if (canPurchaseReturn)
        MenuItemButton(
          leadingIcon: const Icon(Icons.assignment_return_outlined, size: 18),
          onPressed: () => context.go(AppRoutes.invoicesNewPurchaseReturn),
          child: Text(invoiceTypeLabel(l10n, InvoiceType.purchaseReturn)),
        ),
    ];

    return [
      Padding(
        padding: const EdgeInsetsDirectional.only(end: 8),
        child: MenuAnchor(
          alignmentOffset: const Offset(0, 4),
          menuChildren: items,
          builder: (context, controller, child) => FilledButton.icon(
            onPressed: () =>
                controller.isOpen ? controller.close() : controller.open(),
            icon: const Icon(Icons.add, size: 18),
            label: Text(l10n.invoiceCreateNew),
          ),
        ),
      ),
    ];
  }
}
