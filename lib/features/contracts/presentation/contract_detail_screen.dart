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
import '../domain/contract_permissions.dart';
import '../domain/contract_status.dart';
import '../domain/contract_type.dart';
import 'contract_detail_controller.dart';
import 'contract_display_helpers.dart';
import 'widgets/contract_detail_sections.dart';

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
      final canConvert =
          session != null &&
          canConvertTrial(session) &&
          detail.type == ContractType.trial &&
          detail.status == ContractStatus.active;

      body = InvoiceSheet(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InvoiceCommandBar(
              title: detail.contractNumber ?? '—',
              subtitle:
                  '${contractTypeLabel(l10n, detail.type)} · ${contractCustomerName(languageCode: locale.languageCode, nameAr: detail.customerNameAr, nameEn: detail.customerNameEn)}',
              actions: [
                if (canConvert)
                  TextButton(
                    onPressed: () =>
                        context.go(AppRoutes.contractConvertPath(contractId)),
                    child: Text(l10n.contractConvertLink),
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
            ContractValueSummarySection(detail: detail),
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
}
