import '../../auth/domain/app_session.dart';

bool canViewCustomers(AppSession session) =>
    session.isManager || session.permissions.can('customers.view');

bool canViewCustomersArea(AppSession session) =>
    session.isManager ||
    session.permissions.can('customers.view') ||
    session.permissions.can('suppliers.view');

bool canAccessCustomerEdit(AppSession session) =>
    canViewCustomers(session) &&
    (session.isManager || session.permissions.can('customers.edit'));
