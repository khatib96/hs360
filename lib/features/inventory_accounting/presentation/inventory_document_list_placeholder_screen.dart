import '../../../core/routing/app_routes.dart';
import '../../../core/routing/route_guards.dart';
import '../../finance_shared/presentation/finance_placeholder_screen.dart';

class InventoryDocumentListPlaceholderScreen extends FinancePlaceholderScreen {
  InventoryDocumentListPlaceholderScreen({super.key})
    : super(
        titleGetter: (l10n) => l10n.inventoryDocumentsTitle,
        bodyGetter: (l10n) => l10n.inventoryDocumentsDeferredBody,
        canView: canViewInventoryDocuments,
        currentRoute: AppRoutes.inventoryDocuments,
      );
}
