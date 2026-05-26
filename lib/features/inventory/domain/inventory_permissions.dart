import '../../auth/domain/app_session.dart';

bool canViewInventoryBalances(AppSession session) =>
    session.isManager || session.permissions.can('inventory.view');
