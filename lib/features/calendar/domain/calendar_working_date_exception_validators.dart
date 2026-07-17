import 'calendar_date.dart';
import 'calendar_mutation_validators.dart';
import 'calendar_settings.dart';
import 'calendar_working_date_exception.dart';

/// Client-side validators mirroring the migration `100` matrix
/// (`validate_working_date_exception_business_payload` and the table check
/// constraints on `tenant_working_date_exceptions`).
class CalendarWorkingDateExceptionValidators {
  static const kindRequired = 'kind_required';
  static const dateFromRequired = 'date_from_required';
  static const dateToRequired = 'date_to_required';
  static const dateInvalid = 'date_invalid';
  static const dateRangeInvalid = 'date_range_invalid';
  static const dateRangeTooLong = 'date_range_too_long';
  static const titleRequired = 'title_required';
  static const titleArTooLong = 'title_ar_too_long';
  static const titleEnTooLong = 'title_en_too_long';
  static const notesTooLong = 'notes_too_long';
  static const dayModeRequired = 'day_mode_required';
  static const dayModeNotAllowed = 'day_mode_not_allowed';
  static const workWindowRequired = 'work_window_required';
  static const workWindowNotAllowed = 'work_window_not_allowed';
  static const workWindowInvalid = 'work_window_invalid';
  static const workWindowEndNotAfterStart = 'work_window_end_not_after_start';

  /// `chk_twde_title_ar_len` / `chk_twde_title_en_len`.
  static const maxTitleLength = 200;

  /// True insert-enforced bound (`chk_twde_notes_len`). The business-payload
  /// validator in migration `100` only rejects above 4000 chars, but the
  /// table constraint caps at 2000; the client uses the stricter, actually
  /// enforced bound so a save never fails with an unmapped constraint error.
  static const maxNotesLength = 2000;

  /// `chk_twde_max_span`: inclusive day span may not exceed 366 days
  /// (`end_date - start_date <= 365`).
  static const maxInclusiveSpanDays = 366;

  static const defaultPageLimit = 50;
  static const maxPageLimit = 100;

  /// `(v_date_to - v_date_from) > 1095` in `list_working_date_exceptions`.
  static const maxListRangeDays = 1095;

  static final _hhmmPattern = RegExp(r'^([01]\d|2[0-3]):([0-5]\d)$');

  /// Full create/update business-matrix validation.
  ///
  /// [kind] is required for both create and update.
  static CalendarMutationValidationResult validate({
    required CalendarWorkingDateExceptionKind? kind,
    required DateTime? startDate,
    required DateTime? endDate,
    String? titleAr,
    String? titleEn,
    String? notes,
    TenantWorkingDayMode? dayMode,
    String? workStart,
    String? workEnd,
  }) {
    final codes = <String>[
      ..._validateKind(kind).codes,
      ..._validateDateRange(startDate, endDate).codes,
      ..._validateTitles(titleAr, titleEn).codes,
      ..._validateNotes(notes).codes,
    ];

    if (kind != null) {
      codes.addAll(
        _validateMatrix(
          kind: kind,
          dayMode: dayMode,
          workStart: workStart,
          workEnd: workEnd,
        ).codes,
      );
    }

    return CalendarMutationValidationResult(codes: codes);
  }

  static CalendarMutationValidationResult _validateKind(
    CalendarWorkingDateExceptionKind? kind,
  ) {
    if (kind == null) {
      return const CalendarMutationValidationResult(codes: [kindRequired]);
    }
    return const CalendarMutationValidationResult.valid();
  }

  static CalendarMutationValidationResult _validateDateRange(
    DateTime? startDate,
    DateTime? endDate,
  ) {
    final codes = <String>[];
    if (startDate == null) codes.add(dateFromRequired);
    if (endDate == null) codes.add(dateToRequired);
    if (startDate != null && endDate != null) {
      if (endDate.isBefore(startDate)) {
        codes.add(dateRangeInvalid);
      } else if (inclusiveDaySpan(startDate, endDate) > maxInclusiveSpanDays) {
        codes.add(dateRangeTooLong);
      }
    }
    return CalendarMutationValidationResult(codes: codes);
  }

  static CalendarMutationValidationResult _validateTitles(
    String? titleAr,
    String? titleEn,
  ) {
    final codes = <String>[];
    final ar = titleAr?.trim() ?? '';
    final en = titleEn?.trim() ?? '';
    if (ar.isEmpty && en.isEmpty) codes.add(titleRequired);
    if (ar.length > maxTitleLength) codes.add(titleArTooLong);
    if (en.length > maxTitleLength) codes.add(titleEnTooLong);
    return CalendarMutationValidationResult(codes: codes);
  }

  static CalendarMutationValidationResult _validateNotes(String? notes) {
    final trimmed = notes?.trim() ?? '';
    if (trimmed.length > maxNotesLength) {
      return const CalendarMutationValidationResult(codes: [notesTooLong]);
    }
    return const CalendarMutationValidationResult.valid();
  }

  static CalendarMutationValidationResult _validateMatrix({
    required CalendarWorkingDateExceptionKind kind,
    required TenantWorkingDayMode? dayMode,
    required String? workStart,
    required String? workEnd,
  }) {
    final codes = <String>[];
    final start = workStart?.trim() ?? '';
    final end = workEnd?.trim() ?? '';

    if (!kind.allowsWorkingHoursOverride) {
      if (dayMode != null) codes.add(dayModeNotAllowed);
      if (start.isNotEmpty || end.isNotEmpty) codes.add(workWindowNotAllowed);
      return CalendarMutationValidationResult(codes: codes);
    }

    switch (dayMode) {
      case null:
      case TenantWorkingDayMode.dayOff:
      case TenantWorkingDayMode.unreviewed:
        codes.add(dayModeRequired);
      case TenantWorkingDayMode.hours24:
        if (start.isNotEmpty || end.isNotEmpty) {
          codes.add(workWindowNotAllowed);
        }
      case TenantWorkingDayMode.workingHours:
        if (start.isEmpty || end.isEmpty) {
          codes.add(workWindowRequired);
        } else if (!_hhmmPattern.hasMatch(start) ||
            !_hhmmPattern.hasMatch(end)) {
          codes.add(workWindowInvalid);
        } else if (!_isEndAfterStart(start, end)) {
          codes.add(workWindowEndNotAfterStart);
        }
    }

    return CalendarMutationValidationResult(codes: codes);
  }

  /// `chk_twde_cancel_consistency`: reused unchanged from
  /// [CalendarMutationValidators.validateCancelReason] (1-1000 chars).
  static CalendarMutationValidationResult validateCancelReason(
    String? reason,
  ) => CalendarMutationValidators.validateCancelReason(reason);

  static bool _isEndAfterStart(String start, String end) {
    final startParts = start.split(':');
    final endParts = end.split(':');
    final startMinutes =
        int.parse(startParts[0]) * 60 + int.parse(startParts[1]);
    final endMinutes = int.parse(endParts[0]) * 60 + int.parse(endParts[1]);
    return endMinutes > startMinutes;
  }
}
