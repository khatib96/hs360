import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/localization/locale_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/message_banner.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/domain/finance_permissions.dart';
import '../../finance_shared/presentation/finance_placeholder_screen.dart';
import '../domain/invoice_print_support.dart';
import '../domain/invoice_type.dart';
import 'invoice_detail_controller.dart';
import 'invoice_detail_state.dart';
import 'invoice_display_helpers.dart';
import 'widgets/invoice_command_bar.dart';
import 'widgets/invoice_design.dart';
import 'widgets/invoice_detail_sections.dart';
import 'widgets/invoice_shared_widgets.dart';
import 'widgets/invoice_sheet.dart';

class InvoiceDetailScreen extends ConsumerWidget {
  const InvoiceDetailScreen({
    required this.invoiceId,
    this.invoiceType,
    super.key,
  });

  final String invoiceId;
  final InvoiceType? invoiceType;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final session = ref.watch(authControllerProvider).valueOrNull;
    final provider = invoiceDetailControllerProvider(
      invoiceId,
      type: invoiceType,
    );
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    if (session != null && !canViewAnyInvoices(session)) {
      return FinancePlaceholderScreen(
        titleGetter: (l) => l.invoiceDetailTitle,
        bodyGetter: (l) => l.financeModuleAccessUnavailable,
        canView: (_) => false,
        currentRoute: AppRoutes.invoiceDetailPath(invoiceId, type: invoiceType),
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
        message: invoiceErrorMessage(l10n, state.errorCode!),
        onRetry: controller.load,
      );
    } else if (state.detail == null) {
      body = Center(child: Text(l10n.financeErrorNotFound));
    } else {
      final detail = state.detail!;
      final isWide = InvoiceDesign.isDesktop(context);

      final actions = <Widget>[];
      if (session != null) {
        actions.add(
          InvoiceDetailActions(
            canEditDraft: controller.canEditDraft(session),
            canConfirmDraft: controller.canConfirmDraft(session),
            canCancel: controller.canShowCancel(session),
            canReturn: controller.canCreateReturn(session),
            canPreview:
                canPrintInvoice(session) && isInvoicePrintable(detail),
            isSubmitting: state.isSubmitting,
            onEditDraft: () {
              final route = controller.confirmDraftRoute();
              if (route != null) context.go(route);
            },
            onConfirmDraft: () {
              final route = controller.confirmDraftRoute();
              if (route != null) context.go(route);
            },
            onCancel: () => _showCancelDialog(context, controller),
            onReturn: () => context.go(AppRoutes.invoiceReturnPath(invoiceId)),
            onPreview: () {
              context.push(
                AppRoutes.documentPreviewPath(
                  kind: documentKindForInvoiceType(detail.type).documentType,
                  entityId: detail.id,
                  invoiceType: detail.type,
                ),
              );
            },
          ),
        );
      }

      final sheetChild = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InvoiceCommandBar(
            title: detail.invoiceNumber ?? l10n.invoiceDetailTitle,
            subtitle: invoiceTypeLabel(l10n, detail.type),
            statusBadge: invoiceStatusChip(
              context,
              invoiceStatusLabel(l10n, detail.status),
              cancelled: detail.status.isCancelled,
            ),
            progress: state.isSubmitting,
            actions: actions,
          ),
          const SizedBox(height: 20),
          InvoiceDetailSummary(
            detail: detail,
            languageCode: locale.languageCode,
          ),
          const SizedBox(height: 16),
          InvoiceDetailLinesTable(lines: detail.lines, isWide: isWide),
          const SizedBox(height: 16),
          InvoiceDetailTotals(detail: detail),
          if (detail.creditAllocations.isNotEmpty) ...[
            const SizedBox(height: 16),
            InvoiceCreditAllocations(detail: detail),
          ],
          if (session != null && canViewJournal(session)) ...[
            const SizedBox(height: 16),
            InvoiceJournalLinks(detail: detail),
          ],
        ],
      );

      body = InvoiceSheet(
        banner: _banner(l10n, state),
        child: sheetChild,
      );
    }

    return AppShell(
      title: l10n.invoiceDetailTitle,
      currentRoute: AppRoutes.invoices,
      body: body,
    );
  }

  Widget? _banner(AppLocalizations l10n, InvoiceDetailState state) {
    final banners = <Widget>[];
    if (state.errorCode != null) {
      banners.add(
        MessageBanner(
          variant: MessageBannerVariant.error,
          message: invoiceErrorMessage(l10n, state.errorCode!),
        ),
      );
    }
    if (state.validationCodes.isNotEmpty) {
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

  Future<void> _showCancelDialog(
    BuildContext context,
    InvoiceDetailController controller,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final material = MaterialLocalizations.of(context);
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.invoiceConfirmCancel),
        content: TextField(
          controller: reasonController,
          decoration: InputDecoration(labelText: l10n.invoiceCancelReason),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(material.cancelButtonLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.invoiceActionCancel),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await controller.cancel(reasonController.text);
  }
}
