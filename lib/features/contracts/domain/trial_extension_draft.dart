/// Trial extension draft for `extend_trial_contract`.
class TrialExtensionDraft {
  const TrialExtensionDraft({
    required this.trialContractId,
    required this.newTrialEndDate,
    required this.reason,
  });

  final String trialContractId;
  final DateTime newTrialEndDate;
  final String reason;

  Map<String, dynamic> toPayload() {
    return {
      'trial_contract_id': trialContractId,
      'new_trial_end_date': _isoDate(newTrialEndDate),
      'reason': reason.trim(),
    };
  }
}

String _isoDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
