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
import '../domain/contract_type.dart';
import 'contract_display_helpers.dart';
import 'contract_form_controller.dart';
import 'contract_form_state.dart';
import 'contract_list_controller.dart';
import 'widgets/contract_customer_block.dart';
import 'widgets/contract_form_header.dart';
import 'widgets/contract_pricing_summary.dart';
import 'widgets/contract_rental_line_editor.dart';

class ContractCreateScreen extends ConsumerStatefulWidget {
  const ContractCreateScreen({super.key});

  @override
  ConsumerState<ContractCreateScreen> createState() =>
      _ContractCreateScreenState();
}

class _ContractCreateScreenState extends ConsumerState<ContractCreateScreen> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final session = ref.watch(authControllerProvider).valueOrNull;
    final state = ref.watch(contractFormControllerProvider);
    final controller = ref.read(contractFormControllerProvider.notifier);

    if (session != null && !canCreateContract(session)) {
      return FinancePlaceholderScreen(
        titleGetter: (l) => l.contractCreateTitle,
        bodyGetter: (l) => l.financeModuleAccessUnavailable,
        canView: (_) => false,
        currentRoute: AppRoutes.contractsNew,
        showBackButton: true,
        fallbackRoute: AppRoutes.contracts,
      );
    }

    ref.listen(contractFormControllerProvider, (previous, next) {
      final id = next.lastCreatedContractId;
      if (id != null && id != previous?.lastCreatedContractId) {
        unawaited(ref.read(contractListControllerProvider.notifier).refresh());
        context.go(AppRoutes.contractDetailPath(id));
      }
    });

    final banner = _banner(l10n, state);
    final createLabel = state.type == ContractType.trial
        ? l10n.contractCreateTrial
        : l10n.contractCreateRental;

    final body = InvoiceSheet(
      banner: banner,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InvoiceCommandBar(
            title: l10n.contractCreateTitle,
            subtitle: contractTypeLabel(l10n, state.type),
            progress: state.isSubmitting || state.isLoadingPreview,
            actions: [
              TextButton(
                onPressed: state.isSubmitting
                    ? null
                    : () => context.go(AppRoutes.contracts),
                child: Text(l10n.invoiceFormDiscard),
              ),
              FilledButton(
                key: const Key('contract-create-submit'),
                onPressed: state.isSubmitting
                    ? null
                    : () => _confirmSubmit(context, controller, l10n),
                child: state.isSubmitting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(createLabel),
              ),
            ],
          ),
          const SizedBox(height: InvoiceDesign.gapLarge),
          const ContractFormHeader(),
          const SizedBox(height: 12),
          ContractCustomerBlock(languageCode: locale.languageCode),
          const SizedBox(height: 12),
          ContractRentalLineEditor(languageCode: locale.languageCode),
          const SizedBox(height: 12),
          const ContractPricingSummary(),
        ],
      ),
    );

    return AppShell(
      title: l10n.contractCreateTitle,
      currentRoute: AppRoutes.contracts,
      body: body,
    );
  }

  Widget? _banner(AppLocalizations l10n, ContractFormUiState state) {
    if (state.validationCodes.isNotEmpty) {
      final messages = contractValidationMessages(l10n, state.validationCodes);
      return MessageBanner(
        message: messages.join('\n'),
        variant: MessageBannerVariant.error,
      );
    }
    if (state.errorCode != null) {
      return MessageBanner(
        message: contractErrorMessage(l10n, state.errorCode!),
        variant: MessageBannerVariant.error,
      );
    }
    return null;
  }

  Future<void> _confirmSubmit(
    BuildContext context,
    ContractFormController controller,
    AppLocalizations l10n,
  ) async {
    final state = ref.read(contractFormControllerProvider);
    final createLabel = state.type == ContractType.trial
        ? l10n.contractCreateTrial
        : l10n.contractCreateRental;
    final material = MaterialLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.contractCreateConfirmTitle),
        content: Text(l10n.contractCreateConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(material.cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(createLabel),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await controller.submit();
  }
}
