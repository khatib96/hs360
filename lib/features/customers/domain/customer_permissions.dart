import '../../auth/domain/app_session.dart';
import '../../finance_shared/domain/finance_permissions.dart' as finance;

bool canViewCustomers(AppSession session) =>
    session.isManager || session.permissions.can('customers.view');

bool canViewCustomersArea(AppSession session) =>
    session.isManager ||
    session.permissions.can('customers.view') ||
    session.permissions.can('suppliers.view');

bool canAccessCustomerEdit(AppSession session) =>
    canViewCustomers(session) &&
    (session.isManager || session.permissions.can('customers.edit'));

bool canCreateCustomer(AppSession session) =>
    session.isManager || session.permissions.can('customers.create');

bool canEditCustomer(AppSession session) =>
    session.isManager || session.permissions.can('customers.edit');

bool canDeactivateCustomer(AppSession session) =>
    session.isManager || session.permissions.can('customers.delete');

bool canViewCustomerLedger(AppSession session) =>
    session.isManager || session.permissions.can('customers.view_ledger');

bool canViewContracts(AppSession session) =>
    session.isManager || session.permissions.can('contracts.view');

bool canViewCustomerSalesInvoices(AppSession session) =>
    finance.canViewSalesInvoices(session);

bool canViewVouchers(AppSession session) => finance.canViewVouchers(session);
