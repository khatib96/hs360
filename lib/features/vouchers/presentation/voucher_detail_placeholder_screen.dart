import '../../../core/routing/app_routes.dart';
import '../../../core/routing/route_guards.dart';
import '../../finance_shared/presentation/finance_placeholder_screen.dart';

class VoucherDetailPlaceholderScreen extends FinancePlaceholderScreen {
  VoucherDetailPlaceholderScreen({required this.voucherId, super.key})
    : super(
        titleGetter: (l10n) => l10n.voucherDetailTitle,
        bodyGetter: (l10n) => l10n.financePlaceholderM9Body,
        canView: canViewVouchers,
        currentRoute: AppRoutes.vouchers,
        showBackButton: true,
        fallbackRoute: AppRoutes.vouchers,
        referenceId: voucherId,
      );

  final String voucherId;
}
