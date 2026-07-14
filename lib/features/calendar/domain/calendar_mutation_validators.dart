import 'calendar_date.dart';

/// Outcome of calendar mutation foundation validators (M7/M8).
class CalendarMutationValidationResult {
  const CalendarMutationValidationResult({this.codes = const []});

  const CalendarMutationValidationResult.valid() : codes = const [];

  final List<String> codes;

  bool get isValid => codes.isEmpty;
}

/// Minimal mutation validators — foundations only (no RPC contracts).
class CalendarMutationValidators {
  static const dateRequired = 'date_required';
  static const dateInvalid = 'date_invalid';
  static const agentIdInvalid = 'agent_id_invalid';

  static final _uuidPattern = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );

  /// Validates a date-only string for manual event create.
  static CalendarMutationValidationResult validateManualEventDate(
    String? value,
  ) {
    return _validateDateOnly(value);
  }

  /// Validates a date-only string for reschedule target date.
  static CalendarMutationValidationResult validateRescheduleTargetDate(
    String? value,
  ) {
    return _validateDateOnly(value);
  }

  /// When [agentId] is provided, requires a non-empty UUID-shaped string.
  static CalendarMutationValidationResult validateAssignmentAgentId(
    String? agentId,
  ) {
    if (agentId == null) {
      return const CalendarMutationValidationResult.valid();
    }
    final trimmed = agentId.trim();
    if (trimmed.isEmpty || !_uuidPattern.hasMatch(trimmed)) {
      return const CalendarMutationValidationResult(codes: [agentIdInvalid]);
    }
    return const CalendarMutationValidationResult.valid();
  }

  static CalendarMutationValidationResult _validateDateOnly(String? value) {
    if (value == null || value.trim().isEmpty) {
      return const CalendarMutationValidationResult(codes: [dateRequired]);
    }
    try {
      parseCalendarDateOnly(value.trim());
      return const CalendarMutationValidationResult.valid();
    } on FormatException {
      return const CalendarMutationValidationResult(codes: [dateInvalid]);
    }
  }
}
