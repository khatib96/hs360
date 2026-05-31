import '../../auth/domain/app_session.dart';

bool canViewChartOfAccounts(AppSession session) =>
    session.isManager || session.permissions.can('chart_of_accounts.view');
