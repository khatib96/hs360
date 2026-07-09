import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/localization/locale_controller.dart';
import '../../../../core/routing/app_routes.dart';
import '../../../../shared/widgets/message_banner.dart';
import '../../../contracts/presentation/contract_display_helpers.dart';
import '../../../contracts/presentation/widgets/contract_compact_table.dart';
import '../../../invoices/presentation/widgets/invoice_design.dart';
import '../../../invoices/presentation/widgets/invoice_shared_widgets.dart';
import '../customer_contracts_controller.dart';

class CustomerContractsTab extends ConsumerWidget {
  const CustomerContractsTab({required this.customerId, super.key});

  final String customerId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final state = ref.watch(customerContractsControllerProvider(customerId));
    final notifier = ref.read(
      customerContractsControllerProvider(customerId).notifier,
    );

    if (state.permissionDenied) {
      return Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: MessageBanner(
            key: const Key('customer-contracts-denied'),
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
                message: contractErrorMessage(l10n, state.errorCode!),
                onRetry: () => notifier.load(force: true),
              ),
            ],
          ),
        ),
      );
    }

    if (!state.hasLoaded) {
      return Center(child: Text(l10n.customerContractsNotLoaded));
    }

    if (state.contracts.isEmpty) {
      return Center(
        child: Text(
          l10n.customerContractsEmpty,
          key: const Key('customer-contracts-empty'),
        ),
      );
    }

    return Padding(
      padding: InvoiceDesign.pagePadding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: DecoratedBox(
              decoration: InvoiceDesign.panel,
              child: ContractCompactTable(
                contracts: state.contracts,
                languageCode: locale.languageCode,
                onRowTap: (contract) =>
                    context.go(AppRoutes.contractDetailPath(contract.id)),
              ),
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
              child: Center(
                child: Text(
                  contractErrorMessage(l10n, state.loadMoreErrorCode!),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
