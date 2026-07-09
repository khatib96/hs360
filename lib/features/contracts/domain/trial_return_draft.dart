import 'contract_return_condition.dart';

/// Trial return draft for `return_trial_contract`.
class TrialReturnDraft {
  const TrialReturnDraft({
    required this.trialContractId,
    required this.returnCondition,
    required this.reason,
  });

  final String trialContractId;
  final ContractReturnCondition returnCondition;
  final String reason;

  Map<String, dynamic> toPayload() {
    return {
      'trial_contract_id': trialContractId,
      'return_condition': returnCondition.toDb(),
      'reason': reason.trim(),
    };
  }
}
