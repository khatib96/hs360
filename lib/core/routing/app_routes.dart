import '../../features/invoices/domain/invoice_type.dart';

/// Phase 2 route paths and GoRoute names.
abstract final class AppRoutes {
  static const login = '/login';
  static const forgotPassword = '/forgot-password';
  static const dashboard = '/dashboard';
  static const fieldToday = '/field/today';
  static const blocked = '/blocked';
  static const products = '/products';
  static const productsNew = '/products/new';
  static const productsEdit = '/products/:id/edit';
  static const productsDetail = '/products/:id';
  static const productUnitsDetail = '/product-units/:id';
  static const warehouses = '/warehouses';
  static const inventory = '/inventory';
  static const inventoryMovements = '/inventory/movements';
  static const inventoryTransfers = '/inventory/transfers';
  static const customers = '/customers';
  static const customersEdit = '/customers/:id/edit';
  static const customersDetail = '/customers/:id';
  static const suppliers = '/suppliers';
  static const suppliersDetail = '/suppliers/:id';
  static const accounts = '/accounts';
  static const templateSettings = '/settings/templates';
  static const taxSettings = '/settings/tax';
  static const documentPreview = '/documents/preview';
  static const invoices = '/invoices';
  static const invoicesNewSales = '/invoices/new/sales';
  static const invoicesNewPurchase = '/invoices/new/purchase';
  static const invoicesNewSalesReturn = '/invoices/new/sales-return';
  static const invoicesNewPurchaseReturn = '/invoices/new/purchase-return';
  static const invoicesDetail = '/invoices/:id';
  static const invoiceReturn = '/invoices/:id/return';
  static const vouchers = '/vouchers';
  static const vouchersNewReceipt = '/vouchers/new/receipt';
  static const vouchersNewPayment = '/vouchers/new/payment';
  static const vouchersDetail = '/vouchers/:id';
  static const journal = '/journal';
  static const journalDetail = '/journal/:id';
  static const cashBank = '/cash-bank';
  static const inventoryDocuments = '/inventory/documents';
  static const inventoryDocumentsOpeningStock =
      '/inventory/documents/opening-stock';
  static const inventoryDocumentsStockIn = '/inventory/documents/stock-in';
  static const inventoryDocumentsStockOut = '/inventory/documents/stock-out';
  static const inventoryDocumentsStockCount =
      '/inventory/documents/stock-count';
  static const inventoryDocumentsDetail = '/inventory/documents/:id';

  static const loginName = 'login';
  static const forgotPasswordName = 'forgotPassword';
  static const dashboardName = 'dashboard';
  static const fieldTodayName = 'fieldToday';
  static const blockedName = 'blocked';
  static const productsName = 'products';
  static const productsNewName = 'productsNew';
  static const productsEditName = 'productsEdit';
  static const productsDetailName = 'productsDetail';
  static const productUnitsDetailName = 'productUnitsDetail';
  static const warehousesName = 'warehouses';
  static const inventoryName = 'inventory';
  static const inventoryMovementsName = 'inventoryMovements';
  static const inventoryTransfersName = 'inventoryTransfers';
  static const customersName = 'customers';
  static const customersEditName = 'customersEdit';
  static const customersDetailName = 'customersDetail';
  static const suppliersName = 'suppliers';
  static const suppliersDetailName = 'suppliersDetail';
  static const accountsName = 'accounts';
  static const templateSettingsName = 'templateSettings';
  static const taxSettingsName = 'taxSettings';
  static const documentPreviewName = 'documentPreview';
  static const invoicesName = 'invoices';
  static const invoicesNewSalesName = 'invoicesNewSales';
  static const invoicesNewPurchaseName = 'invoicesNewPurchase';
  static const invoicesNewSalesReturnName = 'invoicesNewSalesReturn';
  static const invoicesNewPurchaseReturnName = 'invoicesNewPurchaseReturn';
  static const invoicesDetailName = 'invoicesDetail';
  static const invoiceReturnName = 'invoiceReturn';
  static const vouchersName = 'vouchers';
  static const vouchersNewReceiptName = 'vouchersNewReceipt';
  static const vouchersNewPaymentName = 'vouchersNewPayment';
  static const vouchersDetailName = 'vouchersDetail';
  static const journalName = 'journal';
  static const journalDetailName = 'journalDetail';
  static const cashBankName = 'cashBank';
  static const inventoryDocumentsName = 'inventoryDocuments';
  static const inventoryDocumentsOpeningStockName =
      'inventoryDocumentsOpeningStock';
  static const inventoryDocumentsStockInName = 'inventoryDocumentsStockIn';
  static const inventoryDocumentsStockOutName = 'inventoryDocumentsStockOut';
  static const inventoryDocumentsStockCountName =
      'inventoryDocumentsStockCount';
  static const inventoryDocumentsDetailName = 'inventoryDocumentsDetail';

  static String customerDetailPath(String id) =>
      '/customers/${Uri.encodeComponent(id)}';

  static String customerEditPath(String id) =>
      '/customers/${Uri.encodeComponent(id)}/edit';

  static String supplierDetailPath(String id) =>
      '/suppliers/${Uri.encodeComponent(id)}';

  static String productUnitDetailPath(String id) =>
      '/product-units/${Uri.encodeComponent(id)}';

  static String invoiceDetailPath(String id, {InvoiceType? type}) {
    final params = type != null ? {'type': type.dbValue} : null;
    return Uri(
      path: '/invoices/${Uri.encodeComponent(id)}',
      queryParameters: params,
    ).toString();
  }

  static String invoiceReturnPath(String id) =>
      '/invoices/${Uri.encodeComponent(id)}/return';

  static String voucherDetailPath(String id) =>
      '/vouchers/${Uri.encodeComponent(id)}';

  static String journalDetailPath(String id) =>
      '/journal/${Uri.encodeComponent(id)}';

  static String inventoryDocumentDetailPath(String id) =>
      '/inventory/documents/${Uri.encodeComponent(id)}';

  static String documentPreviewPath({
    required String kind,
    required String entityId,
    DateTime? from,
    DateTime? to,
    InvoiceType? invoiceType,
  }) {
    final params = <String, String>{'kind': kind, 'entityId': entityId};
    if (from != null) params['from'] = _dateOnly(from);
    if (to != null) params['to'] = _dateOnly(to);
    if (invoiceType != null) params['invoiceType'] = invoiceType.toDb();
    return Uri(path: documentPreview, queryParameters: params).toString();
  }

  static String _dateOnly(DateTime date) {
    final y = date.year.toString().padLeft(4, '0');
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
