import '../../../features/auth/domain/app_session.dart';
import 'document_kind.dart';

bool canPreviewDocument(AppSession session, DocumentKind kind) {
  if (kind == DocumentKind.paymentVoucher) return false;
  if (session.isManager) return true;
  return switch (kind) {
    DocumentKind.salesInvoice =>
      session.permissions.can('invoices.view_sales') ||
          session.permissions.can('invoices.view'),
    DocumentKind.purchaseInvoice =>
      session.permissions.can('invoices.view_purchase') ||
          session.permissions.can('invoices.view'),
    DocumentKind.receiptVoucher => session.permissions.can('vouchers.view'),
    DocumentKind.customerStatement => session.permissions.can(
      'customers.view_ledger',
    ),
    DocumentKind.assetTagLabel => session.permissions.can('product_units.view'),
    DocumentKind.paymentVoucher => false,
  };
}

bool canExportDocument(AppSession session, DocumentKind kind) {
  if (kind == DocumentKind.paymentVoucher) return false;
  if (!canPreviewDocument(session, kind)) return false;
  if (session.isManager) return true;
  return switch (kind) {
    DocumentKind.salesInvoice ||
    DocumentKind.purchaseInvoice => session.permissions.can('invoices.print'),
    DocumentKind.receiptVoucher => session.permissions.can('vouchers.print'),
    DocumentKind.customerStatement => true,
    DocumentKind.assetTagLabel => session.permissions.can(
      'product_units.print_label',
    ),
    DocumentKind.paymentVoucher => false,
  };
}

bool canViewTemplateSettings(AppSession session) {
  if (session.isManager) return true;
  return session.permissions.can('settings.templates.view') ||
      session.permissions.can('settings.templates.edit');
}

bool canEditTemplateSettings(AppSession session) {
  if (session.isManager) return true;
  return session.permissions.can('settings.templates.edit');
}
