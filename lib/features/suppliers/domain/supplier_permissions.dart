import '../../auth/domain/app_session.dart';

bool canViewSuppliers(AppSession session) =>
    session.isManager || session.permissions.can('suppliers.view');
