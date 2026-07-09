import '../../auth/domain/app_session.dart';
import '../../finance_shared/domain/finance_permissions.dart' as finance;

bool _can(AppSession session, String permissionId) =>
    session.isManager || session.permissions.can(permissionId);

bool canViewContracts(AppSession session) => _can(session, 'contracts.view');

bool canCreateContract(AppSession session) => _can(session, 'contracts.create');

bool canConvertTrial(AppSession session) =>
    _can(session, 'contracts.convert_trial');

bool canExtendTrial(AppSession session) =>
    _can(session, 'contracts.extend_trial');

bool canReturnTrial(AppSession session) =>
    _can(session, 'contracts.return_trial');

bool canCloseContract(AppSession session) => _can(session, 'contracts.close');

bool canApproveContractOverride(AppSession session) =>
    _can(session, 'contracts.approve_override');

bool canPrintContract(AppSession session) => _can(session, 'contracts.print');

bool canViewContractDeviceCost(AppSession session) =>
    _can(session, 'contracts.field.snapshot_device_cost');

bool canViewContractOilCost(AppSession session) =>
    _can(session, 'contracts.field.snapshot_oil_cost');

bool canViewContractTotalCost(AppSession session) =>
    _can(session, 'contracts.field.snapshot_total_cost');

bool canViewContractProfit(AppSession session) =>
    _can(session, 'contracts.field.snapshot_profit');

/// Matches migration `081` preview gate (OR).
bool canPreviewRentalCollection(AppSession session) =>
    session.isManager ||
    session.permissions.can('vouchers.create_receipt') ||
    session.permissions.can('invoices.create_sales') ||
    session.permissions.can('invoices.view_sales');

/// Matches migration `081` collect gate (AND).
bool canCollectRentalPayment(AppSession session) =>
    session.isManager ||
    (finance.canCreateReceiptVoucher(session) &&
        finance.canCreateSalesInvoice(session));
