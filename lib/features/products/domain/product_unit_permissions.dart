import '../../auth/domain/app_session.dart';

bool canViewProductUnits(AppSession session) =>
    session.isManager || session.permissions.can('product_units.view');

bool canCreateProductUnits(AppSession session) =>
    session.isManager || session.permissions.can('product_units.create');

bool canEditProductUnits(AppSession session) =>
    session.isManager || session.permissions.can('product_units.edit');
