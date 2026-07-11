import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/message_banner.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/presentation/finance_placeholder_screen.dart';
import '../../invoices/presentation/widgets/invoice_command_bar.dart';
import '../../invoices/presentation/widgets/invoice_design.dart';
import '../../invoices/presentation/widgets/invoice_sheet.dart';
import '../domain/contract_permissions.dart';
import 'contract_convert_controller.dart';
import 'contract_convert_state.dart';
import 'contract_display_helpers.dart';
import 'contract_list_controller.dart';
import 'widgets/contract_convert_pricing_summary.dart';
import 'widgets/contract_cycle_day_field.dart';
import 'widgets/contract_detail_panel.dart';
import 'widgets/contract_detail_sections.dart';

class ContractConvertScreen extends ConsumerStatefulWidget {
  const ContractConvertScreen({required this.contractId, super.key});

  final String contractId;

  @override
  ConsumerState<ContractConvertScreen> createState() =>
      _ContractConvertScreenState();
}

class _ContractConvertScreenState extends ConsumerState<ContractConvertScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final session = ref.watch(authControllerProvider).valueOrNull;
    final provider = contractConvertControllerProvider(widget.contractId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    if (session != null && !canConvertTrial(session)) {
      return FinancePlaceholderScreen(
        titleGetter: (l) => l.contractConvertTitle,
        bodyGetter: (l) => l.financeModuleAccessUnavailable,
        canView: (_) => false,
        currentRoute: AppRoutes.contractConvertPath(widget.contractId),
        showBackButton: true,
        fallbackRoute: AppRoutes.contracts,
        referenceId: widget.contractId,
      );
    }

    ref.listen(provider, (previous, next) {
      final id = next.lastRentalContractId;
      if (id != null && id != previous?.lastRentalContractId) {
        unawaited(ref.read(contractListControllerProvider.notifier).refresh());
        context.go(AppRoutes.contractDetailPath(id));
      }
    });

    final trial = state.trialDetail;
    final conversionStartDate = state.conversionStartDate;
    Widget body;
    if (state.isLoading && trial == null) {
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
    } else if (state.errorCode != null && trial == null) {
      body = Center(child: Text(contractErrorMessage(l10n, state.errorCode!)));
    } else if (trial == null || conversionStartDate == null) {
      body = Center(child: Text(l10n.financeErrorNotFound));
    } else {
      body = InvoiceSheet(
        banner: _banner(l10n, state),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InvoiceCommandBar(
              title: l10n.contractConvertTitle,
              subtitle: trial.contractNumber ?? '—',
              progress: state.isSubmitting || state.isLoadingPreview,
              actions: [
                TextButton(
                  onPressed: state.isSubmitting
                      ? null
                      : () => context.go(
                          AppRoutes.contractDetailPath(widget.contractId),
                        ),
                  child: Text(l10n.invoiceFormDiscard),
                ),
                FilledButton(
                  key: const Key('contract-convert-submit'),
                  onPressed: state.isSubmitting
                      ? null
                      : () => _confirmSubmit(context, controller, l10n),
                  child: state.isSubmitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(l10n.contractConvertAction),
                ),
              ],
            ),
            const SizedBox(height: InvoiceDesign.gapLarge),
            ContractDetailPanel(
              title: l10n.contractSectionOverview,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ContractLabeledField(
                    label: l10n.contractColumnCustomer,
                    child: Text(
                      contractCustomerName(
                        languageCode: locale.languageCode,
                        nameAr: trial.customerNameAr,
                        nameEn: trial.customerNameEn,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ContractLabeledField(
                    label: l10n.contractFieldConversionStartDate,
                    child: Text(formatContractDate(conversionStartDate)),
                  ),
                  const SizedBox(height: 12),
                  ContractLabeledField(
                    label: l10n.contractFieldEndDate,
                    child: ContractDatePickerField(
                      value: state.endDate,
                      firstDate: conversionStartDate,
                      onPick: controller.setEndDate,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: controller.applyTwelveMonthTerm,
                      child: Text(l10n.contractTermTwelveMonths),
                    ),
                  ),
                  const SizedBox(height: 12),
                  ContractLabeledField(
                    label: l10n.contractFieldBillingDay,
                    child: ContractCycleDayPickerField(
                      startDate: conversionStartDate,
                      day: state.billingDay,
                      onPick: controller.setBillingDate,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ContractLabeledField(
                    label: l10n.contractFieldRefillDay,
                    child: ContractCycleDayPickerField(
                      startDate: conversionStartDate,
                      day: state.refillDay,
                      onPick: controller.setRefillDate,
                    ),
                  ),
                  const SizedBox(height: 12),
                  ContractLabeledField(
                    label: l10n.contractFieldMonthlyRentalValue,
                    child: TextFormField(
                      key: const Key('contract-convert-monthly-rental'),
                      initialValue: state.monthlyRentalValue?.toString() ?? '',
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      decoration: InvoiceDesign.denseField(context),
                      onChanged: controller.setMonthlyRentalValueFromText,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            ContractProductsSection(
              detail: trial,
              languageCode: locale.languageCode,
            ),
            const SizedBox(height: 12),
            ContractConvertPricingSummary(trialContractId: widget.contractId),
          ],
        ),
      );
    }

    return AppShell(
      title: l10n.contractConvertTitle,
      currentRoute: AppRoutes.contracts,
      body: body,
    );
  }

  Widget? _banner(AppLocalizations l10n, ContractConvertUiState state) {
    if (state.validationCodes.isNotEmpty) {
      return MessageBanner(
        message: contractValidationMessages(
          l10n,
          state.validationCodes,
        ).join('\n'),
        variant: MessageBannerVariant.error,
      );
    }
    if (state.errorCode != null) {
      return MessageBanner(
        message: contractErrorMessage(l10n, state.errorCode!),
        variant: MessageBannerVariant.error,
      );
    }
    final preview = state.pricingPreview;
    if (preview != null &&
        preview.requiresOverride == true &&
        !state.requestOverride) {
      return MessageBanner(
        message: l10n.contractLowProfitWarning,
        variant: MessageBannerVariant.info,
      );
    }
    return null;
  }

  Future<void> _confirmSubmit(
    BuildContext context,
    ContractConvertController controller,
    AppLocalizations l10n,
  ) async {
    final material = MaterialLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.contractConvertConfirmTitle),
        content: Text(l10n.contractConvertConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(material.cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.contractConvertAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await controller.submit();
  }
}
