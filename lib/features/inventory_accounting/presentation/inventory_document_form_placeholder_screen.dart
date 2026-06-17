import '../../../core/routing/app_routes.dart';
import '../../../core/routing/route_guards.dart';
import '../../finance_shared/presentation/finance_placeholder_screen.dart';

enum InventoryDocumentFormMode { openingStock, stockIn, stockOut, stockCount }

class InventoryDocumentFormPlaceholderScreen extends FinancePlaceholderScreen {
  InventoryDocumentFormPlaceholderScreen({required this.mode, super.key})
    : super(
        titleGetter: (l10n) => switch (mode) {
          InventoryDocumentFormMode.openingStock =>
            l10n.inventoryDocumentOpeningStock,
          InventoryDocumentFormMode.stockIn => l10n.inventoryDocumentStockIn,
          InventoryDocumentFormMode.stockOut => l10n.inventoryDocumentStockOut,
          InventoryDocumentFormMode.stockCount =>
            l10n.inventoryDocumentStockCount,
        },
        bodyGetter: (l10n) => l10n.inventoryDocumentsDeferredBody,
        canView: canViewInventoryDocuments,
        currentRoute: _routeForMode(mode),
        showBackButton: true,
        fallbackRoute: AppRoutes.inventoryDocuments,
      );

  final InventoryDocumentFormMode mode;

  static String _routeForMode(InventoryDocumentFormMode mode) {
    return switch (mode) {
      InventoryDocumentFormMode.openingStock =>
        AppRoutes.inventoryDocumentsOpeningStock,
      InventoryDocumentFormMode.stockIn => AppRoutes.inventoryDocumentsStockIn,
      InventoryDocumentFormMode.stockOut =>
        AppRoutes.inventoryDocumentsStockOut,
      InventoryDocumentFormMode.stockCount =>
        AppRoutes.inventoryDocumentsStockCount,
    };
  }
}
