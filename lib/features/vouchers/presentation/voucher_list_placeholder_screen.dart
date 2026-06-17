import '../../../core/routing/app_routes.dart';
import '../../../core/routing/route_guards.dart';
import '../../finance_shared/presentation/finance_placeholder_screen.dart';

class VoucherListPlaceholderScreen extends FinancePlaceholderScreen {
  VoucherListPlaceholderScreen({super.key})
    : super(
        titleGetter: (l10n) => l10n.voucherTitle,
        bodyGetter: (l10n) => l10n.financePlaceholderM9Body,
        canView: canViewVouchers,
        currentRoute: AppRoutes.vouchers,
      );
}
