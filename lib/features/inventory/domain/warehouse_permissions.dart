import '../../auth/domain/app_session.dart';

bool canViewWarehouses(AppSession session) =>
    session.isManager || session.permissions.can('warehouses.view');

bool canCreateWarehouse(AppSession session) =>
    session.isManager || session.permissions.can('warehouses.create');

bool canEditWarehouse(AppSession session) =>
    session.isManager || session.permissions.can('warehouses.edit');

bool canDeactivateWarehouse(AppSession session) => canEditWarehouse(session);
