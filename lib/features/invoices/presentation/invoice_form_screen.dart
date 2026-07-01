import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/message_banner.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/domain/finance_permissions.dart';
import '../../finance_shared/presentation/finance_placeholder_screen.dart';
import '../domain/invoice_permissions.dart';
import '../domain/invoice_type.dart';
import 'invoice_display_helpers.dart';
import 'invoice_form_controller.dart';
import 'invoice_form_state.dart';
import 'widgets/invoice_command_bar.dart';
import 'widgets/invoice_design.dart';
import 'widgets/invoice_form_header.dart';
import 'widgets/invoice_line_cards.dart';
import 'widgets/invoice_line_table.dart';
import 'widgets/invoice_payment_terms_section.dart';
import 'widgets/invoice_shared_widgets.dart';
import 'widgets/invoice_sheet.dart';
import 'widgets/invoice_totals_panel.dart';

class InvoiceFormScreen extends ConsumerStatefulWidget {
  const InvoiceFormScreen({required this.invoiceType, this.draftId, super.key});

  final InvoiceType invoiceType;
  final String? draftId;

  @override
  ConsumerState<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends ConsumerState<InvoiceFormScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final draftId = widget.draftId;
      if (draftId != null && widget.invoiceType == InvoiceType.purchase) {
        ref
            .read(invoiceFormControllerProvider(widget.invoiceType).notifier)
            .loadPurchaseDraft(draftId);
      }
    });
  }

  bool _canAccessPurchase(AppSession session) {
    final draftId = widget.draftId?.trim();
    if (draftId == null || draftId.isEmpty) {
      return canCreatePurchaseInvoice(session);
    }
    return canEditInvoiceDraft(session);
  }

  bool _canAccess() {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return false;
    return switch (widget.invoiceType) {
      InvoiceType.sales => canCreateSalesInvoice(session),
      InvoiceType.purchase => _canAccessPurchase(session),
      InvoiceType.salesReturn => canCreateSalesReturn(session),
      InvoiceType.purchaseReturn => canCreatePurchaseReturn(session),
    };
  }

  bool _canConfirmPurchase(AppSession session, InvoiceFormUiState state) {
    if (!canCreatePurchaseInvoice(session)) return false;
    final editingExistingDraft =
        widget.draftId?.trim().isNotEmpty == true || state.invoiceId != null;
    if (editingExistingDraft) {
      return canEditInvoiceDraft(session);
    }
    return true;
  }

  bool _canConfirm(AppSession session, InvoiceFormUiState state) {
    return switch (widget.invoiceType) {
      InvoiceType.sales => canCreateSalesInvoice(session),
      InvoiceType.purchase => _canConfirmPurchase(session, state),
      InvoiceType.salesReturn => canCreateSalesReturn(session),
      InvoiceType.purchaseReturn => canCreatePurchaseReturn(session),
    };
  }

  String get _route => switch (widget.invoiceType) {
    InvoiceType.sales => AppRoutes.invoicesNewSales,
    InvoiceType.purchase =>
      widget.draftId == null
          ? AppRoutes.invoicesNewPurchase
          : '${AppRoutes.invoicesNewPurchase}?draftId=${Uri.encodeComponent(widget.draftId!)}',
    InvoiceType.salesReturn => AppRoutes.invoicesNewSalesReturn,
    InvoiceType.purchaseReturn => AppRoutes.invoicesNewPurchaseReturn,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final state = ref.watch(invoiceFormControllerProvider(widget.invoiceType));
    final controller = ref.read(
      invoiceFormControllerProvider(widget.invoiceType).notifier,
    );

    if (!_canAccess()) {
      return FinancePlaceholderScreen(
        titleGetter: (l) => _title(l),
        bodyGetter: (l) => l.financeModuleAccessUnavailable,
        canView: (_) => false,
        currentRoute: _route,
        showBackButton: true,
        fallbackRoute: AppRoutes.invoices,
      );
    }

    final title = _title(l10n);

    final session = ref.watch(authControllerProvider).valueOrNull;
    final showDraftActions =
        widget.invoiceType == InvoiceType.purchase &&
        session != null &&
        canEditInvoiceDraft(session);
    final showConfirm = session != null && _canConfirm(session, state);
    final isDesktop = InvoiceDesign.isDesktop(context);

    final banner = _banner(l10n, state);

    final sheetChild = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        InvoiceCommandBar(
          title: title,
          subtitle: l10n.invoiceFormNumberAuto,
          statusBadge: invoiceStatusChip(context, l10n.invoiceStatusDraft),
          progress:
              state.isLoadingMeta ||
              state.isLoadingDraft ||
              state.isSubmitting ||
              state.isSavingDraft,
          actions: _actions(
            context,
            l10n,
            state,
            controller,
            showDraftActions: showDraftActions,
            showConfirm: showConfirm,
          ),
        ),
        const SizedBox(height: 20),
        InvoiceSectionCard(
          child: InvoiceFormHeader(
            invoiceType: widget.invoiceType,
            languageCode: locale.languageCode,
            warehouses: state.warehouses,
            warehouseId: state.warehouseId,
            date: state.date,
            notes: state.notes,
            onWarehouseChanged: controller.setWarehouseId,
            onDateChanged: controller.setDate,
            onNotesChanged: controller.setNotes,
          ),
        ),
        if (!widget.invoiceType.isReturn ||
            state.returnDraft?.originalInvoiceId.trim().isEmpty == true) ...[
          const SizedBox(height: 16),
          InvoiceSectionCard(
            child: InvoicePaymentTermsSection(
              invoiceType: widget.invoiceType,
              paymentTerms: state.paymentTerms,
              dueDate: state.dueDate,
              cashBankAccounts: state.cashBankAccounts,
              cashAccountId: state.cashAccountId,
              languageCode: locale.languageCode,
              onTermsChanged: controller.setPaymentTerms,
              onDueDateChanged: controller.setDueDate,
              onCashAccountChanged: controller.setCashAccountId,
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (isDesktop)
          InvoiceLineTable(
            invoiceType: widget.invoiceType,
            lines: state.lines,
            languageCode: locale.languageCode,
            decimalPlaces: state.decimalPlaces,
          )
        else
          InvoiceLineCards(
            invoiceType: widget.invoiceType,
            lines: state.lines,
            languageCode: locale.languageCode,
            decimalPlaces: state.decimalPlaces,
          ),
        const SizedBox(height: 16),
        InvoiceTotalsPanel(
          estimate: state.computedEstimateTotals,
          taxEstimateAvailable: state.taxEstimateAvailable,
        ),
      ],
    );

    return AppShell(
      title: title,
      currentRoute: _route,
      body: InvoiceSheet(banner: banner, child: sheetChild),
    );
  }

  String _title(AppLocalizations l10n) {
    return switch (widget.invoiceType) {
      InvoiceType.sales => l10n.invoiceNewSales,
      InvoiceType.purchase => l10n.invoiceNewPurchase,
      InvoiceType.salesReturn => invoiceTypeLabel(
        l10n,
        InvoiceType.salesReturn,
      ),
      InvoiceType.purchaseReturn => invoiceTypeLabel(
        l10n,
        InvoiceType.purchaseReturn,
      ),
    };
  }

  Widget? _banner(AppLocalizations l10n, InvoiceFormUiState state) {
    final banners = <Widget>[];
    if (state.errorCode != null) {
      banners.add(
        MessageBanner(
          variant: MessageBannerVariant.error,
          message: invoiceErrorMessage(
            l10n,
            state.errorCode!,
            technicalDetail: state.errorDetail,
          ),
        ),
      );
    }
    if (state.hasValidationErrors) {
      banners.add(
        MessageBanner(
          variant: MessageBannerVariant.error,
          message: invoiceValidationMessages(l10n, state.validationCodes),
        ),
      );
    }
    if (banners.isEmpty) return null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < banners.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          banners[i],
        ],
      ],
    );
  }

  List<Widget> _actions(
    BuildContext context,
    AppLocalizations l10n,
    InvoiceFormUiState state,
    InvoiceFormController controller, {
    required bool showDraftActions,
    required bool showConfirm,
  }) {
    final actions = <Widget>[
      TextButton(
        onPressed: () => context.go(AppRoutes.invoices),
        child: Text(l10n.invoiceFormDiscard),
      ),
    ];

    if (showDraftActions) {
      actions.add(
        OutlinedButton(
          onPressed: state.isSavingDraft ? null : controller.saveDraft,
          child: state.isSavingDraft
              ? const _BtnSpinner()
              : Text(l10n.invoiceFormSaveDraft),
        ),
      );
      if (state.invoiceId != null) {
        actions.add(
          TextButton(
            onPressed: state.isSavingDraft ? null : controller.discardDraft,
            child: Text(l10n.invoiceFormDiscardDraft),
          ),
        );
      }
    }

    if (showConfirm) {
      actions.add(
        FilledButton(
          onPressed: state.isSubmitting
              ? null
              : () => _confirmSubmit(context, controller),
          child: state.isSubmitting
              ? const _BtnSpinner()
              : Text(l10n.invoiceFormConfirm),
        ),
      );
    }
    return actions;
  }

  Future<void> _confirmSubmit(
    BuildContext context,
    InvoiceFormController controller,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final material = MaterialLocalizations.of(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.invoiceFormConfirm),
        content: Text(l10n.invoiceFormConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(material.cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.invoiceFormConfirm),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    final code = await controller.submit();
    if (!context.mounted) return;
    if (code != null) return;

    final invoiceId = ref
        .read(invoiceFormControllerProvider(widget.invoiceType))
        .lastSavedInvoiceId;
    if (invoiceId != null) {
      context.go(
        AppRoutes.invoiceDetailPath(invoiceId, type: widget.invoiceType),
      );
    }
  }
}

class _BtnSpinner extends StatelessWidget {
  const _BtnSpinner();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 18,
      height: 18,
      child: CircularProgressIndicator(strokeWidth: 2),
    );
  }
}
