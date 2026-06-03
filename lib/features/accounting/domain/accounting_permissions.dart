import '../../auth/domain/app_session.dart';

bool canViewChartOfAccounts(AppSession session) =>
    session.isManager || session.permissions.can('chart_of_accounts.view');

bool canCreateChartAccount(AppSession session) =>
    session.isManager || session.permissions.can('chart_of_accounts.create');

bool canEditChartAccount(AppSession session) =>
    session.isManager || session.permissions.can('chart_of_accounts.edit');

bool canDeactivateChartAccount(AppSession session) =>
    session.isManager || session.permissions.can('chart_of_accounts.delete');
