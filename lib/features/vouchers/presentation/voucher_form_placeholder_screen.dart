import '../../../core/routing/app_routes.dart';
import '../../../core/routing/route_guards.dart';
import '../../finance_shared/presentation/finance_placeholder_screen.dart';

enum VoucherFormMode { receipt, payment }

class VoucherFormPlaceholderScreen extends FinancePlaceholderScreen {
  VoucherFormPlaceholderScreen({required this.mode, super.key})
    : super(
        titleGetter: (l10n) => mode == VoucherFormMode.receipt
            ? l10n.voucherNewReceipt
            : l10n.voucherNewPayment,
        bodyGetter: (l10n) => l10n.financePlaceholderM9Body,
        canView: mode == VoucherFormMode.receipt
            ? canCreateReceiptVoucher
            : canCreatePaymentVoucher,
        currentRoute: mode == VoucherFormMode.receipt
            ? AppRoutes.vouchersNewReceipt
            : AppRoutes.vouchersNewPayment,
        showBackButton: true,
        fallbackRoute: AppRoutes.vouchers,
      );

  final VoucherFormMode mode;
}
