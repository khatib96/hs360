import '../../auth/domain/app_session.dart';

bool _can(AppSession session, String permissionId) =>
    session.isManager || session.permissions.can(permissionId);

bool canViewAnyInvoices(AppSession session) =>
    session.isManager ||
    session.permissions.can('invoices.view_sales') ||
    session.permissions.can('invoices.view_purchase') ||
    session.permissions.can('invoices.view_returns') ||
    session.permissions.can('invoices.view');

bool canViewSalesInvoices(AppSession session) =>
    session.isManager ||
    session.permissions.can('invoices.view_sales') ||
    session.permissions.can('invoices.view');

bool canViewPurchaseInvoices(AppSession session) =>
    session.isManager ||
    session.permissions.can('invoices.view_purchase') ||
    session.permissions.can('invoices.view');

bool canViewReturnInvoices(AppSession session) =>
    session.isManager ||
    session.permissions.can('invoices.view_returns') ||
    session.permissions.can('invoices.view');

bool canCreateSalesInvoice(AppSession session) =>
    _can(session, 'invoices.create_sales');

bool canCreatePurchaseInvoice(AppSession session) =>
    _can(session, 'invoices.create_purchase');

bool canCreateSalesReturn(AppSession session) =>
    _can(session, 'invoices.create_sales_return');

bool canCreatePurchaseReturn(AppSession session) =>
    _can(session, 'invoices.create_purchase_return');

bool canCreateAnyReturn(AppSession session) =>
    canCreateSalesReturn(session) || canCreatePurchaseReturn(session);

bool canEditInvoiceDraft(AppSession session) =>
    _can(session, 'invoices.edit_draft');

bool canCancelInvoice(AppSession session) => _can(session, 'invoices.cancel');

bool canPrintInvoice(AppSession session) => _can(session, 'invoices.print');

bool canViewVouchers(AppSession session) => _can(session, 'vouchers.view');

bool canCreateReceiptVoucher(AppSession session) =>
    _can(session, 'vouchers.create_receipt');

bool canCreatePaymentVoucher(AppSession session) =>
    _can(session, 'vouchers.create_payment');

bool canCancelVoucher(AppSession session) => _can(session, 'vouchers.cancel');

bool canPrintVoucher(AppSession session) => _can(session, 'vouchers.print');

bool canViewJournal(AppSession session) => _can(session, 'journal.view');

bool canViewCashBank(AppSession session) => _can(session, 'cash_bank.view');

bool canViewTaxSettings(AppSession session) =>
    session.isManager ||
    session.permissions.can('settings.tax.view') ||
    session.permissions.can('settings.tax.edit');

bool canEditTaxSettings(AppSession session) =>
    _can(session, 'settings.tax.edit');

bool canViewInventoryDocuments(AppSession session) =>
    _can(session, 'inventory.view');
