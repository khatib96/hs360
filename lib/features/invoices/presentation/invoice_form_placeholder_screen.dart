import '../../../core/routing/app_routes.dart';
import '../../../core/routing/route_guards.dart';
import '../../finance_shared/presentation/finance_placeholder_screen.dart';

enum InvoiceFormMode { sales, purchase }

class InvoiceFormPlaceholderScreen extends FinancePlaceholderScreen {
  InvoiceFormPlaceholderScreen({required this.mode, super.key})
    : super(
        titleGetter: (l10n) => mode == InvoiceFormMode.sales
            ? l10n.invoiceNewSales
            : l10n.invoiceNewPurchase,
        bodyGetter: (l10n) => l10n.financePlaceholderM9Body,
        canView: mode == InvoiceFormMode.sales
            ? canCreateSalesInvoice
            : canCreatePurchaseInvoice,
        currentRoute: mode == InvoiceFormMode.sales
            ? AppRoutes.invoicesNewSales
            : AppRoutes.invoicesNewPurchase,
        showBackButton: true,
        fallbackRoute: AppRoutes.invoices,
      );

  final InvoiceFormMode mode;
}
