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
import '../supplier_payment_vouchers_controller.dart';

class SupplierPaymentVouchersTab extends ConsumerWidget {
  const SupplierPaymentVouchersTab({required this.supplierId, super.key});

  final String supplierId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final state = ref.watch(
      supplierPaymentVouchersControllerProvider(supplierId),
    );
    final notifier = ref.read(
      supplierPaymentVouchersControllerProvider(supplierId).notifier,
    );

    if (state.permissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: MessageBanner(
            key: const Key('supplier-vouchers-denied'),
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
        child: VoucherErrorState(
          message: voucherErrorMessage(l10n, state.errorCode!),
          onRetry: () => notifier.load(force: true),
        ),
      );
    }

    if (!state.hasLoaded) {
      return Center(child: Text(l10n.supplierVouchersNotLoaded));
    }

    final filtersBar = SupplierPaymentVoucherFiltersBar(
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
                : l10n.supplierVouchersEmpty,
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
      key: const Key('supplier-vouchers-tab'),
      padding: const EdgeInsetsDirectional.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [filtersBar, const SizedBox(height: 16), listContent],
      ),
    );
  }
}

class SupplierPaymentVoucherFiltersBar extends StatelessWidget {
  const SupplierPaymentVoucherFiltersBar({
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
      key: const Key('supplier-voucher-filters'),
      filters: filters,
      availableTypes: const [VoucherType.payment],
      onTypeChanged: (_) {},
      onStatusChanged: onStatusChanged,
      onSearchChanged: onSearchChanged,
      onDateFromChanged: onDateFromChanged,
      onDateToChanged: onDateToChanged,
    );
  }
}
