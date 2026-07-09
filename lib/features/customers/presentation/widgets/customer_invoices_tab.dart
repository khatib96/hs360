import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/localization/locale_controller.dart';
import '../../../../shared/widgets/message_banner.dart';
import '../../../invoices/domain/invoice_type.dart';
import '../../../invoices/presentation/widgets/invoice_filters_bar.dart';
import '../../../invoices/presentation/widgets/invoice_shared_widgets.dart';
import '../../../invoices/presentation/widgets/invoice_table.dart';
import '../customer_invoices_controller.dart';

class CustomerInvoicesTab extends ConsumerWidget {
  const CustomerInvoicesTab({required this.customerId, super.key});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final state = ref.watch(customerInvoicesControllerProvider(customerId));
    final notifier = ref.read(
      customerInvoicesControllerProvider(customerId).notifier,
    );

    if (state.permissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: MessageBanner(
            key: const Key('customer-invoices-denied'),
            variant: MessageBannerVariant.info,
            message: l10n.moduleAccessUnavailable,
          ),
        ),
      );
    }

    if (state.isLoading && !state.hasLoaded) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorCode != null && !state.hasLoaded) {
      return Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              InvoiceErrorState(
                message: invoiceErrorMessage(l10n, state.errorCode!),
                onRetry: () => notifier.load(force: true),
              ),
            ],
          ),
        ),
      );
    }

    if (!state.hasLoaded) {
      return Center(child: Text(l10n.customerInvoicesNotLoaded));
    }

    final filtersBar = InvoiceFiltersBar(
      key: const Key('customer-invoice-filters'),
      filters: state.filters,
      availableTypes: const [InvoiceType.sales],
      onTypeChanged: (_) {},
      onStatusChanged: notifier.setStatus,
      onSearchChanged: notifier.setSearch,
      onDateFromChanged: notifier.setDateFrom,
      onDateToChanged: notifier.setDateTo,
    );

    Widget listContent;
    if (state.invoices.isEmpty) {
      final hasUserFilters =
          state.filters.status != null ||
          !state.filters.dateRange.isEmpty ||
          state.filters.search?.trim().isNotEmpty == true;
      listContent = Expanded(
        child: Center(
          child: Text(
            hasUserFilters
                ? l10n.invoiceListEmptyFiltered
                : l10n.customerInvoicesEmpty,
          ),
        ),
      );
    } else {
      final isWide = MediaQuery.sizeOf(context).width > 768;
      listContent = Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: isWide
                  ? InvoiceTable(
                      invoices: state.invoices,
                      languageCode: locale.languageCode,
                    )
                  : InvoiceCardList(
                      invoices: state.invoices,
                      languageCode: locale.languageCode,
                    ),
            ),
            if (state.hasMore)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: state.isLoadingMore
                    ? const Center(child: CircularProgressIndicator())
                    : Center(
                        child: OutlinedButton(
                          onPressed: notifier.loadMore,
                          child: Text(l10n.loadMore),
                        ),
                      ),
              ),
            if (state.loadMoreErrorCode != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: MessageBanner(
                  variant: MessageBannerVariant.error,
                  message: invoiceErrorMessage(l10n, state.loadMoreErrorCode!),
                ),
              ),
          ],
        ),
      );
    }

    return Padding(
      key: const Key('customer-invoices-tab'),
      padding: const EdgeInsetsDirectional.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [filtersBar, const SizedBox(height: 16), listContent],
      ),
    );
  }
}
