import '../../auth/domain/app_session.dart';

bool canViewSuppliers(AppSession session) =>
    session.isManager || session.permissions.can('suppliers.view');

bool canCreateSupplier(AppSession session) =>
    session.isManager || session.permissions.can('suppliers.create');

bool canEditSupplier(AppSession session) =>
    session.isManager || session.permissions.can('suppliers.edit');

bool canDeactivateSupplier(AppSession session) =>
    session.isManager || session.permissions.can('suppliers.delete');
