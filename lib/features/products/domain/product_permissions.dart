import '../../auth/domain/app_session.dart';

/// Module/action gates use the M3/M4 [session.isManager] convention.
bool canEditProduct(AppSession session) =>
    session.isManager || session.permissions.can('products.edit');

bool canSelectProductGroup(AppSession session) =>
    session.isManager || session.permissions.can('product_groups.view');

bool canCreateProduct(AppSession session) =>
    session.isManager || session.permissions.can('products.create');

bool canViewProductStock(AppSession session) =>
    session.isManager || session.permissions.can('inventory.view');

bool canViewProductGroups(AppSession session) =>
    session.isManager || session.permissions.can('product_groups.view');

bool canCreateProductGroup(AppSession session) =>
    session.isManager || session.permissions.can('product_groups.create');

bool canEditProductGroup(AppSession session) =>
    session.isManager || session.permissions.can('product_groups.edit');

bool canViewProductsList(AppSession session) =>
    session.isManager || session.permissions.can('products.view');
