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
import '../domain/voucher_permissions.dart';
import '../domain/voucher_type.dart';
import 'voucher_display_helpers.dart';
import 'voucher_form_controller.dart';
import 'voucher_form_state.dart';
import 'widgets/cash_bank_account_picker.dart';
import 'widgets/voucher_account_picker.dart';
import 'widgets/voucher_form_header.dart';

class VoucherFormScreen extends ConsumerWidget {
  const VoucherFormScreen({required this.voucherType, super.key});

  final VoucherType voucherType;

  bool _canAccess(WidgetRef ref) {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return false;
    return switch (voucherType) {
      VoucherType.receipt => canCreateReceiptVoucher(session),
      VoucherType.payment => canCreatePaymentVoucher(session),
    };
  }

  String get _route => switch (voucherType) {
    VoucherType.receipt => AppRoutes.vouchersNewReceipt,
    VoucherType.payment => AppRoutes.vouchersNewPayment,
  };

  String _title(AppLocalizations l10n) => switch (voucherType) {
    VoucherType.receipt => l10n.voucherNewReceipt,
    VoucherType.payment => l10n.voucherNewPayment,
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    ref.watch(localeProvider);

    if (!_canAccess(ref)) {
      return FinancePlaceholderScreen(
        titleGetter: _title,
        bodyGetter: (l) => l.financeModuleAccessUnavailable,
        canView: (_) => false,
        currentRoute: _route,
        showBackButton: true,
        fallbackRoute: AppRoutes.vouchers,
      );
    }

    final state = ref.watch(voucherFormControllerProvider(voucherType));
    final controller = ref.read(
      voucherFormControllerProvider(voucherType).notifier,
    );

    return AppShell(
      title: _title(l10n),
      currentRoute: _route,
      body: _VoucherWorkspace(
        banner: _buildBanner(l10n, state),
        child: DecoratedBox(
          decoration: InvoiceDesign.panel.copyWith(
            boxShadow: const [
              BoxShadow(
                color: Color(0x0F000000),
                blurRadius: 14,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                InvoiceCommandBar(
                  title: _title(l10n),
                  subtitle: voucherTypeLabel(l10n, voucherType),
                  progress: state.isLoadingMeta || state.isSubmitting,
                  actions: [
                    TextButton(
                      onPressed: state.isSubmitting
                          ? null
                          : () => context.go(AppRoutes.vouchers),
                      child: Text(
                        MaterialLocalizations.of(context).cancelButtonLabel,
                      ),
                    ),
                    FilledButton(
                      onPressed:
                          state.isSubmitting || !state.canLoadCashAccounts
                          ? null
                          : () => _submit(context, ref, controller),
                      child: state.isSubmitting
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(l10n.voucherFormSubmit),
                    ),
                  ],
                ),
                const SizedBox(height: InvoiceDesign.gap),
                _VoucherEntryGrid(voucherType: voucherType),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildBanner(AppLocalizations l10n, VoucherFormUiState state) {
    final banners = <Widget>[];

    if (!state.canLoadCashAccounts) {
      banners.add(
        MessageBanner(
          variant: MessageBannerVariant.info,
          message:
              '${l10n.cashBankChartViewRequiredTitle}\n${l10n.cashBankChartViewRequiredBody}',
        ),
      );
    }
    if (state.errorCode != null) {
      banners.add(
        MessageBanner(
          variant: MessageBannerVariant.error,
          message: voucherErrorMessage(l10n, state.errorCode!),
        ),
      );
    }
    if (state.hasValidationErrors) {
      banners.add(
        MessageBanner(
          variant: MessageBannerVariant.error,
          message: voucherValidationMessages(l10n, state.validationCodes),
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

  Future<void> _submit(
    BuildContext context,
    WidgetRef ref,
    VoucherFormController controller,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final errorCode = await controller.submit();
    if (!context.mounted) return;

    if (errorCode == null) {
      final id = ref
          .read(voucherFormControllerProvider(voucherType))
          .lastSavedVoucherId;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.voucherFormSubmitSuccess)));
      if (id != null) {
        context.go('${AppRoutes.vouchers}/$id');
      } else {
        context.go(AppRoutes.vouchers);
      }
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(voucherErrorMessage(l10n, errorCode))),
    );
  }
}

class _VoucherWorkspace extends StatelessWidget {
  const _VoucherWorkspace({required this.child, this.banner});

  final Widget child;
  final Widget? banner;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: InvoiceDesign.pageFill,
      child: Align(
        alignment: AlignmentDirectional.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1320),
          child: ListView(
            padding: InvoiceDesign.pagePadding,
            children: [
              if (banner != null) ...[banner!, const SizedBox(height: 12)],
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _VoucherEntryGrid extends StatelessWidget {
  const _VoucherEntryGrid({required this.voucherType});

  final VoucherType voucherType;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: InvoiceDesign.headerStrip,
      child: Padding(
        padding: const EdgeInsetsDirectional.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 900;
                if (!isWide) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      CashBankAccountPicker(voucherType: voucherType),
                      const SizedBox(height: InvoiceDesign.gap),
                      VoucherAccountPicker(voucherType: voucherType),
                      const SizedBox(height: InvoiceDesign.gap),
                      VoucherFormHeader(voucherType: voucherType),
                    ],
                  );
                }

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 3,
                          child: CashBankAccountPicker(
                            voucherType: voucherType,
                          ),
                        ),
                        const SizedBox(width: InvoiceDesign.gap),
                        Expanded(
                          flex: 2,
                          child: VoucherAccountPicker(voucherType: voucherType),
                        ),
                      ],
                    ),
                    const SizedBox(height: InvoiceDesign.gap),
                    VoucherFormHeader(voucherType: voucherType),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
