import '../../auth/domain/app_session.dart';
import 'accounting_permissions.dart';
import 'chart_account.dart';

enum ChartAccountBadgeKind { system, customer, supplier, manual, inactive }

class ChartAccountFlags {
  const ChartAccountFlags({
    required this.isSystem,
    required this.isCustomerLinked,
    required this.isSupplierLinked,
    required this.isManual,
    required this.isInactive,
  });

  final bool isSystem;
  final bool isCustomerLinked;
  final bool isSupplierLinked;
  final bool isManual;
  final bool isInactive;
}

class ChartAccountAllowedActions {
  const ChartAccountAllowedActions({
    required this.canView,
    required this.canEdit,
    required this.canDeactivate,
  });

  final bool canView;
  final bool canEdit;
  final bool canDeactivate;
}

ChartAccountFlags deriveAccountFlags(ChartAccount account) {
  return ChartAccountFlags(
    isSystem: account.isSystem,
    isCustomerLinked: account.isCustomerSubaccount,
    isSupplierLinked: account.isSupplierSubaccount,
    isManual: account.isManualAccount,
    isInactive: !account.isActive,
  );
}

List<ChartAccountBadgeKind> deriveAccountBadges(ChartAccount account) {
  final badges = <ChartAccountBadgeKind>[];
  if (!account.isSystem && account.isCustomerSubaccount) {
    badges.add(ChartAccountBadgeKind.customer);
  } else if (!account.isSystem && account.isSupplierSubaccount) {
    badges.add(ChartAccountBadgeKind.supplier);
  } else if (!account.isSystem) {
    badges.add(ChartAccountBadgeKind.manual);
  }
  if (!account.isActive) {
    badges.add(ChartAccountBadgeKind.inactive);
  }
  return badges;
}

ChartAccountAllowedActions deriveAllowedActions(
  ChartAccount account,
  AppSession session,
) {
  final manual = account.isManualAccount;
  return ChartAccountAllowedActions(
    canView: canViewChartOfAccounts(session),
    canEdit: manual && canEditChartAccount(session),
    canDeactivate:
        manual && account.isActive && canDeactivateChartAccount(session),
  );
}
