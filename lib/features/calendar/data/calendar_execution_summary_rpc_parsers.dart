import '../domain/calendar_execution_summary.dart';
import 'calendar_read_rpc_primitives.dart';

/// Maps an execution summary. Null remains null.
///
/// When present (migrations 094/097), required non-null fields are:
/// `actual_completion_date`, `actual_quantity_delivered`, `quantity_unit`,
/// `contracted_quantity_per_cycle`, `calculated_next_due_date`,
/// `confirmed_next_due_date`, `next_due_overridden`, and exactly one of
/// `coverage_months` / `coverage_days` with a positive value.
CalendarExecutionSummary? mapExecutionSummary(dynamic value) {
  if (value == null) return null;
  final map = requireMap(value, 'execution_summary');

  final quantityUnit = optionalString(map['quantity_unit']);
  if (quantityUnit == null || quantityUnit.isEmpty) {
    return malformedCalendarResponse(
      'execution_summary.quantity_unit required',
    );
  }

  final coverageMonths = parseNullableInt(
    map['coverage_months'],
    'execution_summary.coverage_months',
  );
  final coverageDays = parseNullableInt(
    map['coverage_days'],
    'execution_summary.coverage_days',
  );

  final hasMonths = coverageMonths != null;
  final hasDays = coverageDays != null;
  if (hasMonths == hasDays) {
    return malformedCalendarResponse(
      'execution_summary: exactly one of coverage_months or coverage_days',
    );
  }
  if (hasMonths && coverageMonths <= 0) {
    return malformedCalendarResponse(
      'execution_summary.coverage_months must be > 0',
    );
  }
  if (hasDays && coverageDays <= 0) {
    return malformedCalendarResponse(
      'execution_summary.coverage_days must be > 0',
    );
  }

  return CalendarExecutionSummary(
    actualCompletionDate: parseRequiredCalendarDate(
      map['actual_completion_date'],
    ),
    actualQuantityDelivered: requireDecimal(
      map['actual_quantity_delivered'],
      'execution_summary.actual_quantity_delivered',
    ),
    quantityUnit: quantityUnit,
    contractedQuantityPerCycle: requireDecimal(
      map['contracted_quantity_per_cycle'],
      'execution_summary.contracted_quantity_per_cycle',
    ),
    coverageMonths: coverageMonths,
    coverageDays: coverageDays,
    calculatedNextDueDate: parseRequiredCalendarDate(
      map['calculated_next_due_date'],
    ),
    confirmedNextDueDate: parseRequiredCalendarDate(
      map['confirmed_next_due_date'],
    ),
    nextDueOverridden: requireBool(
      map['next_due_overridden'],
      'execution_summary.next_due_overridden',
    ),
  );
}
