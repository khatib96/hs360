import '../../../core/routing/app_routes.dart';
import '../../../core/routing/route_guards.dart';
import '../../finance_shared/presentation/finance_placeholder_screen.dart';

class CashBankPlaceholderScreen extends FinancePlaceholderScreen {
  CashBankPlaceholderScreen({super.key})
    : super(
        titleGetter: (l10n) => l10n.cashBankTitle,
        bodyGetter: (l10n) => l10n.financePlaceholderM9Body,
        canView: canViewCashBank,
        currentRoute: AppRoutes.cashBank,
      );
}
