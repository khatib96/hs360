import '../../../core/routing/app_routes.dart';
import '../../../core/routing/route_guards.dart';
import '../../finance_shared/presentation/finance_placeholder_screen.dart';

class InvoiceListPlaceholderScreen extends FinancePlaceholderScreen {
  InvoiceListPlaceholderScreen({super.key})
    : super(
        titleGetter: (l10n) => l10n.invoiceTitle,
        bodyGetter: (l10n) => l10n.financePlaceholderM9Body,
        canView: canViewAnyInvoices,
        currentRoute: AppRoutes.invoices,
      );
}
