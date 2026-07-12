import '../../../features/auth/domain/app_session.dart';
import 'document_kind.dart';

bool canPreviewDocument(AppSession session, DocumentKind kind) {
  if (kind == DocumentKind.paymentVoucher) return false;
  if (session.isManager) return true;
  return switch (kind) {
    DocumentKind.salesInvoice =>
      (session.permissions.can('invoices.view_sales') ||
              session.permissions.can('invoices.view')) &&
          session.permissions.can('invoices.print'),
    DocumentKind.purchaseInvoice =>
      (session.permissions.can('invoices.view_purchase') ||
              session.permissions.can('invoices.view')) &&
          session.permissions.can('invoices.print'),
    DocumentKind.receiptVoucher =>
      session.permissions.can('vouchers.view') &&
          session.permissions.can('vouchers.print'),
    DocumentKind.customerStatement => session.permissions.can(
      'customers.view_ledger',
    ),
    DocumentKind.assetTagLabel => session.permissions.can('product_units.view'),
    DocumentKind.contract =>
      session.permissions.can('contracts.view') &&
          session.permissions.can('contracts.print'),
    DocumentKind.paymentVoucher => false,
  };
}

bool canExportDocument(AppSession session, DocumentKind kind) {
  if (kind == DocumentKind.paymentVoucher) return false;
  if (session.isManager) return true;
  if (!canPreviewDocument(session, kind)) return false;
  return switch (kind) {
    DocumentKind.salesInvoice ||
    DocumentKind.purchaseInvoice ||
    DocumentKind.receiptVoucher => true,
    DocumentKind.customerStatement => true,
    DocumentKind.assetTagLabel => session.permissions.can(
      'product_units.print_label',
    ),
    DocumentKind.contract => true,
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
