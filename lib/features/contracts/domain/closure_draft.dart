import 'contract_return_condition.dart';

/// Rental closure draft for `close_contract`.
class ClosureDraft {
  const ClosureDraft({
    required this.contractId,
    required this.closureType,
    required this.closeReason,
    required this.returnCondition,
    this.closeDate,
  });

  final String contractId;
  final ContractClosureType closureType;
  final String closeReason;
  final ContractReturnCondition returnCondition;
  final DateTime? closeDate;

  Map<String, dynamic> toPayload() {
    return {
      'contract_id': contractId,
      'closure_type': closureType.toDb(),
      'close_reason': closeReason.trim(),
      'return_condition': returnCondition.toDb(),
      if (closeDate != null) 'close_date': _isoDate(closeDate!),
    };
  }
}

String _isoDate(DateTime date) {
  final y = date.year.toString().padLeft(4, '0');
  final m = date.month.toString().padLeft(2, '0');
  final d = date.day.toString().padLeft(2, '0');
  return '$y-$m-$d';
}
