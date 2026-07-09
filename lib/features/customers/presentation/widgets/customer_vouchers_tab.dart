import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/localization/locale_controller.dart';
import '../../../../shared/widgets/message_banner.dart';
import '../../../vouchers/domain/voucher_filters.dart';
import '../../../vouchers/domain/voucher_status.dart';
import '../../../vouchers/domain/voucher_type.dart';
import '../../../vouchers/presentation/voucher_display_helpers.dart';
import '../../../vouchers/presentation/widgets/voucher_filters_bar.dart';
import '../../../vouchers/presentation/widgets/voucher_shared_widgets.dart';
import '../../../vouchers/presentation/widgets/voucher_table.dart';
import '../customer_vouchers_controller.dart';

class CustomerVouchersTab extends ConsumerWidget {
  const CustomerVouchersTab({required this.customerId, super.key});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final state = ref.watch(customerVouchersControllerProvider(customerId));
    final notifier = ref.read(
      customerVouchersControllerProvider(customerId).notifier,
    );

    if (state.permissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: MessageBanner(
            key: const Key('customer-vouchers-denied'),
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
          child: VoucherErrorState(
            message: voucherErrorMessage(l10n, state.errorCode!),
            onRetry: () => notifier.load(force: true),
          ),
        ),
      );
    }

    if (!state.hasLoaded) {
      return Center(child: Text(l10n.customerVouchersNotLoaded));
    }

    final filtersBar = CustomerReceiptVoucherFiltersBar(
      filters: state.filters,
      onStatusChanged: notifier.setStatus,
      onSearchChanged: notifier.setSearch,
      onDateFromChanged: notifier.setDateFrom,
      onDateToChanged: notifier.setDateTo,
    );

    Widget listContent;
    if (state.vouchers.isEmpty) {
      final hasUserFilters =
          state.filters.status != null ||
          !state.filters.dateRange.isEmpty ||
          state.filters.search?.trim().isNotEmpty == true;
      listContent = Expanded(
        child: Center(
          child: Text(
            hasUserFilters
                ? l10n.voucherListEmptyFiltered
                : l10n.customerVouchersEmpty,
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
                  ? VoucherTable(
                      vouchers: state.vouchers,
                      languageCode: locale.languageCode,
                    )
                  : VoucherCardList(
                      vouchers: state.vouchers,
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
                  message: voucherErrorMessage(l10n, state.loadMoreErrorCode!),
                ),
              ),
          ],
        ),
      );
    }

    return Padding(
      key: const Key('customer-vouchers-tab'),
      padding: const EdgeInsetsDirectional.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [filtersBar, const SizedBox(height: 16), listContent],
      ),
    );
  }
}

/// Receipt-only filters for customer 360 — no payment type picker.
class CustomerReceiptVoucherFiltersBar extends StatelessWidget {
  const CustomerReceiptVoucherFiltersBar({
    required this.filters,
    required this.onStatusChanged,
    required this.onSearchChanged,
    required this.onDateFromChanged,
    required this.onDateToChanged,
    super.key,
  });

  final VoucherFilters filters;
  final ValueChanged<VoucherStatus?> onStatusChanged;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<DateTime?> onDateFromChanged;
  final ValueChanged<DateTime?> onDateToChanged;

  @override
  Widget build(BuildContext context) {
    return VoucherFiltersBar(
      key: const Key('customer-voucher-filters'),
      filters: filters,
      availableTypes: const [VoucherType.receipt],
      onTypeChanged: (_) {},
      onStatusChanged: onStatusChanged,
      onSearchChanged: onSearchChanged,
      onDateFromChanged: onDateFromChanged,
      onDateToChanged: onDateToChanged,
    );
  }
}
