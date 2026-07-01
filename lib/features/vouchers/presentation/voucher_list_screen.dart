import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/presentation/finance_placeholder_screen.dart';
import '../../invoices/presentation/widgets/invoice_design.dart';
import '../domain/voucher_permissions.dart';
import '../domain/voucher_type.dart';
import 'voucher_display_helpers.dart';
import 'voucher_list_controller.dart';
import 'widgets/voucher_filters_bar.dart';
import 'widgets/voucher_shared_widgets.dart';
import 'widgets/voucher_table.dart';

class VoucherListScreen extends ConsumerWidget {
  const VoucherListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final session = ref.watch(authControllerProvider).valueOrNull;
    final state = ref.watch(voucherListControllerProvider);
    final controller = ref.read(voucherListControllerProvider.notifier);

    if (session != null && !canViewVouchers(session)) {
      return FinancePlaceholderScreen(
        titleGetter: (l) => l.voucherTitle,
        bodyGetter: (l) => l.financeModuleAccessUnavailable,
        canView: (_) => false,
        currentRoute: AppRoutes.vouchers,
      );
    }

    final availableTypes = session == null
        ? const <VoucherType>[]
        : voucherListTypeOptions();

    final isWide = InvoiceDesign.isDesktop(context);
    Widget tableArea;
    if (state.isLoading && state.vouchers.isEmpty) {
      tableArea = _InTableMessage(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.loading),
          ],
        ),
      );
    } else if (state.hasError && state.vouchers.isEmpty) {
      tableArea = _InTableMessage(
        child: VoucherErrorState(
          message: voucherErrorMessage(l10n, state.errorCode!),
          onRetry: controller.refresh,
        ),
      );
    } else if (!state.isLoading && state.vouchers.isEmpty) {
      tableArea = _InTableMessage(
        child: Text(
          state.filters.hasActiveFilters
              ? l10n.voucherListEmptyFiltered
              : l10n.voucherListEmpty,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    } else {
      tableArea = isWide
          ? VoucherTable(
              vouchers: state.vouchers,
              languageCode: locale.languageCode,
            )
          : VoucherCardList(
              vouchers: state.vouchers,
              languageCode: locale.languageCode,
            );
    }

    final tableContainer = DecoratedBox(
      decoration: InvoiceDesign.panel,
      child: ClipRRect(borderRadius: InvoiceDesign.radius, child: tableArea),
    );

    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (session != null) ...[
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: _VoucherCreateMenu(session: session),
          ),
          const SizedBox(height: 12),
        ],
        if (availableTypes.isNotEmpty) ...[
          VoucherFiltersBar(
            key: const Key('voucher-filters-bar'),
            filters: state.filters,
            availableTypes: availableTypes,
            onTypeChanged: controller.setType,
            onStatusChanged: controller.setStatus,
            onSearchChanged: controller.setSearch,
            onDateFromChanged: controller.setDateFrom,
            onDateToChanged: controller.setDateTo,
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

    return AppShell(
      title: l10n.voucherTitle,
      currentRoute: AppRoutes.vouchers,
      body: Stack(
        children: [
          Padding(padding: InvoiceDesign.pagePadding, child: body),
          if (state.isLoading && state.vouchers.isNotEmpty)
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
}

class _VoucherCreateMenu extends StatelessWidget {
  const _VoucherCreateMenu({required this.session});

  final AppSession session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final items = <Widget>[
      if (canCreateReceiptVoucher(session))
        MenuItemButton(
          leadingIcon: const Icon(Icons.payments_outlined, size: 18),
          onPressed: () => context.go(AppRoutes.vouchersNewReceipt),
          child: Text(l10n.voucherCreateReceipt),
        ),
      if (canCreatePaymentVoucher(session))
        MenuItemButton(
          leadingIcon: const Icon(Icons.outbox_outlined, size: 18),
          onPressed: () => context.go(AppRoutes.vouchersNewPayment),
          child: Text(l10n.voucherCreatePayment),
        ),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    return MenuAnchor(
      alignmentOffset: const Offset(0, 4),
      menuChildren: items,
      builder: (context, controller, child) => FilledButton.icon(
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: const Icon(Icons.add, size: 18),
        label: Text(l10n.invoiceCreateNew),
      ),
    );
  }
}

class _InTableMessage extends StatelessWidget {
  const _InTableMessage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(32),
        child: child,
      ),
    );
  }
}
