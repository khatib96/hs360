import '../../auth/domain/app_session.dart';

bool canViewProductStock(AppSession session) =>
    session.isManager || session.permissions.can('inventory.view');

bool canViewProductGroups(AppSession session) =>
    session.isManager || session.permissions.can('product_groups.view');

bool canCreateProduct(AppSession session) =>
    session.isManager || session.permissions.can('products.create');

bool canCreateProductGroup(AppSession session) =>
    session.isManager || session.permissions.can('product_groups.create');

bool canEditProductGroup(AppSession session) =>
    session.isManager || session.permissions.can('product_groups.edit');
