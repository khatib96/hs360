import '../../../core/routing/app_routes.dart';
import '../../../core/routing/route_guards.dart';
import '../../finance_shared/presentation/finance_placeholder_screen.dart';

class TaxSettingsPlaceholderScreen extends FinancePlaceholderScreen {
  TaxSettingsPlaceholderScreen({super.key})
    : super(
        titleGetter: (l10n) => l10n.taxSettingsTitle,
        bodyGetter: (l10n) => l10n.financePlaceholderM9Body,
        canView: canViewTaxSettings,
        currentRoute: AppRoutes.taxSettings,
      );
}
