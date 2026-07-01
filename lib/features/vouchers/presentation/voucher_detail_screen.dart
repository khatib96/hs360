import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/documents/domain/document_kind.dart';
import '../../../core/localization/locale_controller.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/message_banner.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/domain/finance_permissions.dart';
import '../../finance_shared/presentation/finance_placeholder_screen.dart';
import '../../invoices/presentation/widgets/invoice_command_bar.dart';
import '../../invoices/presentation/widgets/invoice_design.dart';
import '../../invoices/presentation/widgets/invoice_sheet.dart';
import '../domain/voucher_detail.dart';
import '../domain/voucher_print_support.dart';
import '../domain/voucher_status.dart';
import 'voucher_detail_controller.dart';
import 'voucher_display_helpers.dart';
import 'widgets/voucher_detail_sections.dart';
import 'widgets/voucher_shared_widgets.dart';

class VoucherDetailScreen extends ConsumerWidget {
  const VoucherDetailScreen({required this.voucherId, super.key});

  final String voucherId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final locale = ref.watch(localeProvider);
    final session = ref.watch(authControllerProvider).valueOrNull;
    final provider = voucherDetailControllerProvider(voucherId);
    final state = ref.watch(provider);
    final controller = ref.read(provider.notifier);

    if (session != null && !canViewVouchers(session)) {
      return FinancePlaceholderScreen(
        titleGetter: (l) => l.voucherDetailTitle,
        bodyGetter: (l) => l.financeModuleAccessUnavailable,
        canView: (_) => false,
        currentRoute: AppRoutes.voucherDetailPath(voucherId),
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
      body = VoucherErrorState(
        message: voucherErrorMessage(l10n, state.errorCode!),
        onRetry: () => controller.load(voucherId),
      );
    } else if (state.detail == null) {
      body = Center(child: Text(l10n.financeErrorNotFound));
    } else {
      final detail = state.detail!;
      final isWide = InvoiceDesign.isDesktop(context);
      final canCancel =
          session != null &&
          canCancelVoucher(session) &&
          detail.status == VoucherStatus.confirmed;
      final canPreview =
          session != null &&
          canPrintVoucher(session) &&
          isVoucherPrintable(detail);

      body = InvoiceSheet(
        banner: _buildBanner(l10n, state.errorCode, state.validationCodes),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InvoiceCommandBar(
              title: detail.voucherNumber ?? '—',
              subtitle: _subtitle(context, l10n, detail),
              statusBadge: voucherStatusChip(
                context,
                voucherStatusLabel(l10n, detail.status),
                cancelled: detail.status.isCancelled,
              ),
              progress: state.isSubmitting,
              actions: [
                if (canPreview)
                  OutlinedButton.icon(
                    key: const Key('voucher-detail-preview'),
                    onPressed: state.isSubmitting
                        ? null
                        : () {
                            context.push(
                              AppRoutes.documentPreviewPath(
                                kind: DocumentKind.receiptVoucher.documentType,
                                entityId: detail.id,
                              ),
                            );
                          },
                    icon: const Icon(Icons.picture_as_pdf_outlined, size: 18),
                    label: Text(l10n.documentPreviewAction),
                  ),
                if (canCancel)
                  OutlinedButton(
                    onPressed: state.isSubmitting
                        ? null
                        : () => _showCancelDialog(context, controller),
                    child: Text(l10n.voucherCancelAction),
                  ),
              ],
            ),
            const SizedBox(height: InvoiceDesign.gapLarge),
            if (_hasParty(detail)) ...[
              InvoiceSectionCard(
                child: VoucherPartySection(
                  detail: detail,
                  languageCode: locale.languageCode,
                ),
              ),
              const SizedBox(height: InvoiceDesign.gap),
            ],
            InvoiceSectionCard(
              title: l10n.voucherFormCashAccount,
              child: VoucherCashAccountSection(
                detail: detail,
                languageCode: locale.languageCode,
              ),
            ),
            const SizedBox(height: InvoiceDesign.gap),
            InvoiceSectionCard(child: VoucherPaymentSummary(detail: detail)),
            if (detail.allocations.isNotEmpty) ...[
              const SizedBox(height: InvoiceDesign.gap),
              InvoiceSectionCard(
                title: l10n.voucherAllocationsTitle,
                child: VoucherAllocationsTable(detail: detail, isWide: isWide),
              ),
            ],
            if (session != null && canViewJournal(session)) ...[
              const SizedBox(height: InvoiceDesign.gap),
              InvoiceSectionCard(
                title: l10n.voucherJournalEntry,
                child: VoucherJournalLinks(detail: detail),
              ),
            ],
          ],
        ),
      );
    }

    return AppShell(
      title: l10n.voucherDetailTitle,
      currentRoute: AppRoutes.vouchers,
      body: body,
    );
  }

  String _subtitle(
    BuildContext context,
    AppLocalizations l10n,
    VoucherDetail detail,
  ) {
    final date = MaterialLocalizations.of(
      context,
    ).formatMediumDate(detail.date);
    return '${voucherTypeLabel(l10n, detail.type)} · $date';
  }

  bool _hasParty(VoucherDetail detail) {
    return detail.customer != null || detail.supplier != null;
  }

  Widget? _buildBanner(
    AppLocalizations l10n,
    String? errorCode,
    List<String> validationCodes,
  ) {
    final banners = <Widget>[];
    if (errorCode != null) {
      banners.add(
        MessageBanner(
          variant: MessageBannerVariant.error,
          message: voucherErrorMessage(l10n, errorCode),
        ),
      );
    }
    if (validationCodes.isNotEmpty) {
      banners.add(
        MessageBanner(
          variant: MessageBannerVariant.error,
          message: voucherValidationMessages(l10n, validationCodes),
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
    VoucherDetailController controller,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final material = MaterialLocalizations.of(context);
    final reasonController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            final hasReason = reasonController.text.trim().isNotEmpty;
            return AlertDialog(
              title: Text(l10n.voucherConfirmCancel),
              content: TextField(
                controller: reasonController,
                decoration: InputDecoration(
                  labelText: l10n.voucherCancelReason,
                  helperText: l10n.financeValidationCancellationReasonRequired,
                ),
                maxLength: 500,
                maxLines: 3,
                onChanged: (_) => setState(() {}),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(material.cancelButtonLabel),
                ),
                FilledButton(
                  onPressed: hasReason
                      ? () => Navigator.pop(context, true)
                      : null,
                  child: Text(l10n.voucherCancelAction),
                ),
              ],
            );
          },
        );
      },
    );
    if (confirmed != true || !context.mounted) return;
    await controller.cancel(reasonController.text);
  }
}
