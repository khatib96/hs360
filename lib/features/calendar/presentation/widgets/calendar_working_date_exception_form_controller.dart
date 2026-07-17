import 'package:flutter/material.dart';

import '../../domain/calendar_settings.dart';
import '../../domain/calendar_working_date_exception.dart';
import '../../domain/calendar_working_date_exception_validators.dart';

/// Owns create/edit form field state and client-side validation for a
/// single working-date exception. Mirrors
/// [CalendarManualEventFormController] but has no async lookups.
class CalendarWorkingDateExceptionFormController {
  CalendarWorkingDateExceptionFormController({this.existing});

  final WorkingDateException? existing;

  late CalendarWorkingDateExceptionKind? kind;
  late DateTime? startDate;
  late DateTime? endDate;
  late final TextEditingController titleAr;
  late final TextEditingController titleEn;
  late final TextEditingController notes;
  late final TextEditingController workStart;
  late final TextEditingController workEnd;
  late TenantWorkingDayMode? dayMode;

  String? errorCode;
  var submitting = false;

  bool get isEdit => existing != null;

  void init() {
    final existing = this.existing;
    kind = existing?.kind;
    startDate = existing?.startDate;
    endDate = existing?.endDate;
    titleAr = TextEditingController(text: existing?.titleAr ?? '');
    titleEn = TextEditingController(text: existing?.titleEn ?? '');
    notes = TextEditingController(text: existing?.notes ?? '');
    workStart = TextEditingController(text: existing?.workStart ?? '');
    workEnd = TextEditingController(text: existing?.workEnd ?? '');
    dayMode = existing?.dayMode;
  }

  void dispose() {
    titleAr.dispose();
    titleEn.dispose();
    notes.dispose();
    workStart.dispose();
    workEnd.dispose();
  }

  void onKindChanged(CalendarWorkingDateExceptionKind? next) {
    kind = next;
    if (next == null || !next.allowsWorkingHoursOverride) {
      dayMode = null;
      workStart.clear();
      workEnd.clear();
    }
  }

  void onDayModeChanged(TenantWorkingDayMode? next) {
    dayMode = next;
    if (next != TenantWorkingDayMode.workingHours) {
      workStart.clear();
      workEnd.clear();
    }
  }

  /// Returns validated data, or null after setting [errorCode].
  WorkingDateExceptionData? buildData() {
    final effectiveDayMode = (kind?.allowsWorkingHoursOverride ?? false)
        ? dayMode
        : null;
    final effectiveStart = effectiveDayMode == TenantWorkingDayMode.hours24
        ? null
        : (workStart.text.trim().isEmpty ? null : workStart.text.trim());
    final effectiveEnd = effectiveDayMode == TenantWorkingDayMode.hours24
        ? null
        : (workEnd.text.trim().isEmpty ? null : workEnd.text.trim());

    final validation = CalendarWorkingDateExceptionValidators.validate(
      kind: kind,
      startDate: startDate,
      endDate: endDate,
      titleAr: titleAr.text,
      titleEn: titleEn.text,
      notes: notes.text,
      dayMode: effectiveDayMode,
      workStart: effectiveStart,
      workEnd: effectiveEnd,
    );
    if (!validation.isValid) {
      errorCode = validation.codes.first;
      return null;
    }

    return WorkingDateExceptionData(
      kind: kind!,
      startDate: startDate!,
      endDate: endDate!,
      titleAr: titleAr.text.trim().isEmpty ? null : titleAr.text.trim(),
      titleEn: titleEn.text.trim().isEmpty ? null : titleEn.text.trim(),
      notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
      dayMode: effectiveDayMode,
      workStart: effectiveStart,
      workEnd: effectiveEnd,
    );
  }
}
