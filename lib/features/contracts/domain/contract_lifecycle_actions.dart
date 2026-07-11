import '../../auth/domain/app_session.dart';
import 'contract_detail.dart';
import 'contract_permissions.dart';
import 'contract_status.dart';
import 'contract_type.dart';

bool canShowConvertTrialAction(AppSession session, ContractDetail detail) =>
    canConvertTrial(session) &&
    detail.type == ContractType.trial &&
    detail.status == ContractStatus.active &&
    detail.convertedToContractId == null;

bool canShowExtendTrialAction(AppSession session, ContractDetail detail) =>
    canExtendTrial(session) &&
    detail.type == ContractType.trial &&
    detail.status == ContractStatus.active &&
    detail.convertedToContractId == null;

bool canShowReturnTrialAction(AppSession session, ContractDetail detail) =>
    canReturnTrial(session) &&
    detail.type == ContractType.trial &&
    detail.status == ContractStatus.active &&
    detail.convertedToContractId == null;

bool canShowCloseRentalAction(AppSession session, ContractDetail detail) =>
    canCloseContract(session) &&
    detail.type == ContractType.rental &&
    (detail.status == ContractStatus.active ||
        detail.status == ContractStatus.suspended) &&
    !detail.status.isClosed;

bool canShowScheduleConsumableChangeAction(
  AppSession session,
  ContractDetail detail,
) {
  if (!canScheduleConsumableChange(session)) return false;
  if (detail.type != ContractType.rental) return false;
  if (detail.status.isClosed) return false;
  return detail.consumableLines.any(
    (line) => line.scheduledEffectiveFrom == null,
  );
}
