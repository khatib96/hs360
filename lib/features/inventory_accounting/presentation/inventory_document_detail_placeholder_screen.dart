import '../../../core/routing/app_routes.dart';
import '../../../core/routing/route_guards.dart';
import '../../finance_shared/presentation/finance_placeholder_screen.dart';

class InventoryDocumentDetailPlaceholderScreen
    extends FinancePlaceholderScreen {
  InventoryDocumentDetailPlaceholderScreen({
    required this.documentId,
    super.key,
  }) : super(
         titleGetter: (l10n) => l10n.inventoryDocumentsTitle,
         bodyGetter: (l10n) => l10n.inventoryDocumentsDeferredBody,
         canView: canViewInventoryDocuments,
         currentRoute: AppRoutes.inventoryDocuments,
         showBackButton: true,
         fallbackRoute: AppRoutes.inventoryDocuments,
         referenceId: documentId,
       );

  final String documentId;
}
