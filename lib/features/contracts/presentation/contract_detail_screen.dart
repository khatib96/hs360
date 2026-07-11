import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/presentation/finance_placeholder_screen.dart';
import '../../invoices/presentation/widgets/invoice_command_bar.dart';
import '../../invoices/presentation/widgets/invoice_design.dart';
import '../../invoices/presentation/widgets/invoice_sheet.dart';
import '../../invoices/presentation/widgets/invoice_shared_widgets.dart';
import '../domain/contract_detail.dart';
import '../domain/contract_lifecycle_actions.dart';
import '../domain/contract_permissions.dart';
import 'contract_detail_controller.dart';
import 'contract_list_controller.dart';
import 'contract_display_helpers.dart';
import 'widgets/contract_closure_dialog.dart';
import 'widgets/contract_consumable_change_dialog.dart';
import 'widgets/contract_detail_sections.dart';
import 'widgets/contract_trial_extension_dialog.dart';
import 'widgets/contract_trial_return_dialog.dart';

class ContractDetailScreen extends ConsumerWidget {
  const ContractDetailScreen({required this.contractId, super.key});

  final String contractId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final session = ref.watch(authControllerProvider).valueOrNull;
    final provider = contractDetailControllerProvider(contractId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    if (session != null && !canViewContracts(session)) {
      return FinancePlaceholderScreen(
        titleGetter: (l) => l.contractDetailTitle,
        bodyGetter: (l) => l.financeModuleAccessUnavailable,
        canView: (_) => false,
        currentRoute: AppRoutes.contractDetailPath(contractId),
      );
    }

    Widget body;
    if (state.isLoading && state.detail == null) {
      body = Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.loading),
          ],
        ),
      );
    } else if (state.errorCode != null && state.detail == null) {
      body = InvoiceErrorState(
        message: contractErrorMessage(l10n, state.errorCode!),
        onRetry: () => controller.load(contractId),
      );
    } else if (state.isNotFound || state.detail == null) {
      body = Center(child: Text(l10n.financeErrorNotFound));
    } else {
      final detail = state.detail!;
      final showConvert =
          session != null && canShowConvertTrialAction(session, detail);
      final showExtend =
          session != null && canShowExtendTrialAction(session, detail);
      final showReturn =
          session != null && canShowReturnTrialAction(session, detail);
      final showClose =
          session != null && canShowCloseRentalAction(session, detail);
      final showConsumable =
          session != null &&
          canShowScheduleConsumableChangeAction(session, detail);

      body = InvoiceSheet(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InvoiceCommandBar(
              title: detail.contractNumber ?? '—',
              subtitle:
                  '${contractTypeLabel(l10n, detail.type)} · ${contractCustomerName(languageCode: locale.languageCode, nameAr: detail.customerNameAr, nameEn: detail.customerNameEn)}',
              actions: [
                if (showConvert)
                  TextButton(
                    onPressed: () =>
                        context.go(AppRoutes.contractConvertPath(contractId)),
                    child: Text(l10n.contractConvertLink),
                  ),
                if (showExtend)
                  TextButton(
                    onPressed: () => _extendTrial(context, ref, detail),
                    child: Text(l10n.contractExtendTrialAction),
                  ),
                if (showReturn)
                  TextButton(
                    onPressed: () => _returnTrial(context, ref, detail),
                    child: Text(l10n.contractReturnTrialAction),
                  ),
                if (showClose)
                  TextButton(
                    onPressed: () => _closeRental(context, ref, detail),
                    child: Text(l10n.contractCloseRentalAction),
                  ),
                if (showConsumable)
                  TextButton(
                    onPressed: () => _scheduleConsumable(context, ref, detail),
                    child: Text(l10n.contractScheduleConsumableAction),
                  ),
              ],
            ),
            const SizedBox(height: InvoiceDesign.gapLarge),
            ContractDetailHeader(
              detail: detail,
              languageCode: locale.languageCode,
            ),
            const SizedBox(height: 16),
            ContractOverviewSection(detail: detail),
            const SizedBox(height: 12),
            ContractProductsSection(
              detail: detail,
              languageCode: locale.languageCode,
            ),
            const SizedBox(height: 12),
            ContractValueSummarySection(detail: detail, session: session),
            const SizedBox(height: 12),
            ContractUpcomingScheduleSection(detail: detail),
            const SizedBox(height: 12),
            ContractHistorySection(detail: detail),
          ],
        ),
      );
    }

    return AppShell(
      title: l10n.contractDetailTitle,
      currentRoute: AppRoutes.contracts,
      body: body,
    );
  }

  Future<void> _extendTrial(
    BuildContext context,
    WidgetRef ref,
    ContractDetail detail,
  ) async {
    final changed = await showContractTrialExtensionDialog(
      context,
      ref,
      detail: detail,
    );
    if (changed == true) {
      await ref
          .read(contractDetailControllerProvider(contractId).notifier)
          .load(contractId);
      await ref.read(contractListControllerProvider.notifier).refresh();
    }
  }

  Future<void> _returnTrial(
    BuildContext context,
    WidgetRef ref,
    ContractDetail detail,
  ) async {
    final changed = await showContractTrialReturnDialog(
      context,
      ref,
      detail: detail,
    );
    if (changed == true) {
      await ref
          .read(contractDetailControllerProvider(contractId).notifier)
          .load(contractId);
      await ref.read(contractListControllerProvider.notifier).refresh();
    }
  }

  Future<void> _closeRental(
    BuildContext context,
    WidgetRef ref,
    ContractDetail detail,
  ) async {
    final closeDate = await showContractClosureDialog(
      context,
      ref,
      detail: detail,
    );
    if (closeDate != null) {
      await ref
          .read(contractDetailControllerProvider(contractId).notifier)
          .load(contractId);
      await ref.read(contractListControllerProvider.notifier).refresh();
    }
  }

  Future<void> _scheduleConsumable(
    BuildContext context,
    WidgetRef ref,
    ContractDetail detail,
  ) async {
    final changed = await showContractConsumableChangeDialog(
      context,
      ref,
      detail: detail,
    );
    if (changed == true) {
      await ref
          .read(contractDetailControllerProvider(contractId).notifier)
          .load(contractId);
      await ref.read(contractListControllerProvider.notifier).refresh();
    }
  }
}
