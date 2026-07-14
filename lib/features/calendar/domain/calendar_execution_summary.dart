import 'package:decimal/decimal.dart';

/// Trusted refill execution facts when Phase 8 has supplied them.
///
/// Aligns with `calendar_refill_execution_facts` checks in migration `094`
/// and the read projection in `097`: exactly one of [coverageMonths] /
/// [coverageDays] is set and positive; [calculatedNextDueDate] is required.
class CalendarExecutionSummary {
  const CalendarExecutionSummary({
    required this.actualCompletionDate,
    required this.actualQuantityDelivered,
    required this.quantityUnit,
    required this.contractedQuantityPerCycle,
    this.coverageMonths,
    this.coverageDays,
    required this.calculatedNextDueDate,
    required this.confirmedNextDueDate,
    required this.nextDueOverridden,
  });

  final DateTime actualCompletionDate;
  final Decimal actualQuantityDelivered;
  final String quantityUnit;
  final Decimal contractedQuantityPerCycle;
  final int? coverageMonths;
  final int? coverageDays;
  final DateTime calculatedNextDueDate;
  final DateTime confirmedNextDueDate;
  final bool nextDueOverridden;
}
