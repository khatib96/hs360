import '../../../core/routing/app_routes.dart';
import '../../../core/routing/route_guards.dart';
import '../../finance_shared/presentation/finance_placeholder_screen.dart';

class InvoiceDetailPlaceholderScreen extends FinancePlaceholderScreen {
  InvoiceDetailPlaceholderScreen({required this.invoiceId, super.key})
    : super(
        titleGetter: (l10n) => l10n.invoiceDetailTitle,
        bodyGetter: (l10n) => l10n.financePlaceholderM9Body,
        canView: canViewAnyInvoices,
        currentRoute: AppRoutes.invoices,
        showBackButton: true,
        fallbackRoute: AppRoutes.invoices,
        referenceId: invoiceId,
      );

  final String invoiceId;
}
