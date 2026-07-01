import 'package:decimal/decimal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/message_banner.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/presentation/finance_placeholder_screen.dart';
import '../data/invoice_repository.dart';
import '../../finance_shared/domain/finance_permissions.dart';
import '../domain/invoice_permissions.dart';
import '../domain/invoice_type.dart';
import 'invoice_display_helpers.dart';
import 'invoice_form_controller.dart';
import 'widgets/invoice_form_header.dart';
import 'widgets/invoice_return_line_editor.dart';
import 'widgets/invoice_shared_widgets.dart';

class InvoiceReturnScreen extends ConsumerStatefulWidget {
  const InvoiceReturnScreen({required this.invoiceId, super.key});

  final String invoiceId;

  @override
  ConsumerState<InvoiceReturnScreen> createState() =>
      _InvoiceReturnScreenState();
}

class _InvoiceReturnScreenState extends ConsumerState<InvoiceReturnScreen> {
  bool _initialized = false;
  String? _initError;
  InvoiceType? _returnType;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return;

    try {
      final repo = ref.read(invoiceRepositoryProvider);
      final detail = await repo.fetchInvoiceDetail(widget.invoiceId, session);
      if (!isReturnEligibleOriginal(detail)) {
        setState(() => _initError = 'not_eligible');
        return;
      }

      final canReturn = switch (detail.type) {
        InvoiceType.sales => canCreateSalesReturn(session),
        InvoiceType.purchase => canCreatePurchaseReturn(session),
        _ => false,
      };
      if (!canReturn) {
        setState(() => _initError = 'permission');
        return;
      }

      final returnableLines = await repo.listReturnableInvoiceLines(
        session,
        widget.invoiceId,
      );

      final returnType = detail.type == InvoiceType.sales
          ? InvoiceType.salesReturn
          : InvoiceType.purchaseReturn;

      await ref
          .read(invoiceFormControllerProvider(returnType).notifier)
          .initializeReturn(
            originalInvoiceId: widget.invoiceId,
            originalDetail: detail,
            returnableLines: returnableLines,
          );

      final initializedState = ref.read(
        invoiceFormControllerProvider(returnType),
      );
      if (initializedState.returnableLines.isEmpty ||
          initializedState.returnDraft?.lines.isEmpty == true) {
        setState(() => _initError = 'no_lines');
        return;
      }

      if (mounted) {
        setState(() {
          _initialized = true;
          _returnType = returnType;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _initError = 'load_failed');
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(authControllerProvider).valueOrNull;

    if (session != null && !canViewAnyInvoices(session)) {
      return FinancePlaceholderScreen(
        titleGetter: (l) => l.invoiceReturnTitle,
        bodyGetter: (l) => l.financeModuleAccessUnavailable,
        canView: (_) => false,
        currentRoute: AppRoutes.invoiceReturnPath(widget.invoiceId),
        showBackButton: true,
        fallbackRoute: AppRoutes.invoices,
      );
    }

    if (_initError != null) {
      final message = switch (_initError) {
        'not_eligible' => l10n.invoiceReturnNotEligible,
        'permission' => l10n.financeErrorPermissionDenied,
        'no_lines' => l10n.invoiceReturnNotEligible,
        _ => l10n.financeErrorUnknown,
      };
      return AppShell(
        title: l10n.invoiceReturnTitle,
        currentRoute: AppRoutes.invoiceReturnPath(widget.invoiceId),
        body: Center(child: Text(message)),
      );
    }

    if (!_initialized || _returnType == null) {
      return AppShell(
        title: l10n.invoiceReturnTitle,
        currentRoute: AppRoutes.invoiceReturnPath(widget.invoiceId),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final returnType = _returnType!;
    final state = ref.watch(invoiceFormControllerProvider(returnType));
    final controller = ref.read(
      invoiceFormControllerProvider(returnType).notifier,
    );
    if (state.originalDetail != null &&
        (state.returnableLines.isEmpty ||
            state.returnDraft?.lines.isEmpty == true)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(invoiceFormControllerProvider(returnType).notifier)
            .ensureLinkedReturnLinesSelected();
      });
    }
    final draft = state.returnDraft;

    final qtyByLineId = <String, Decimal>{
      for (final line in draft?.lines ?? const [])
        line.originalInvoiceLineId: line.qty,
    };

    return AppShell(
      title: l10n.invoiceReturnTitle,
      currentRoute: AppRoutes.invoiceReturnPath(widget.invoiceId),
      body: SingleChildScrollView(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (state.errorCode != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MessageBanner(
                  variant: MessageBannerVariant.error,
                  message: invoiceErrorMessage(l10n, state.errorCode!),
                ),
              ),
            if (state.hasValidationErrors)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MessageBanner(
                  variant: MessageBannerVariant.error,
                  message: invoiceValidationMessages(
                    l10n,
                    state.validationCodes,
                  ),
                ),
              ),
            InvoiceFormHeader(
              invoiceType: returnType,
              languageCode: Localizations.localeOf(context).languageCode,
              warehouses: state.warehouses,
              warehouseId: state.warehouseId,
              date: state.date,
              notes: state.notes,
              onWarehouseChanged: controller.setWarehouseId,
              onDateChanged: controller.setDate,
              onNotesChanged: controller.setNotes,
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: draft?.reason ?? '',
              decoration: InputDecoration(labelText: l10n.invoiceReturnReason),
              onChanged: controller.setReturnReason,
            ),
            const SizedBox(height: 16),
            for (final line in state.returnableLines)
              InvoiceReturnLineEditor(
                line: line,
                qty: qtyByLineId[line.originalLineId] ?? Decimal.zero,
                onQtyChanged: (qty) =>
                    controller.setReturnLineQty(line.originalLineId, qty),
              ),
            InvoiceReturnCreditPanel(
              lines: state.returnableLines,
              qtyByLineId: qtyByLineId,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: state.isSubmitting
                  ? null
                  : () => _submit(context, controller, returnType),
              child: state.isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(l10n.invoiceReturnSubmit),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(
    BuildContext context,
    InvoiceFormController controller,
    InvoiceType returnType,
  ) async {
    final code = await controller.submit();
    if (!context.mounted || code != null) return;

    final invoiceId = ref
        .read(invoiceFormControllerProvider(returnType))
        .lastSavedInvoiceId;
    if (invoiceId != null) {
      context.go(AppRoutes.invoiceDetailPath(invoiceId, type: returnType));
    }
  }
}
