import '../../../core/errors/calendar_exception.dart';
import '../../auth/domain/app_session.dart';
import '../data/calendar_working_date_exception_repository.dart';
import '../domain/calendar_idempotency.dart';
import '../domain/calendar_permissions.dart';
import '../domain/calendar_working_date_exception.dart';

/// Outcome of a single create/update/cancel mutation attempt.
class CalendarWorkingDateExceptionMutationOutcome {
  const CalendarWorkingDateExceptionMutationOutcome._({
    required this.ok,
    this.exception,
    this.errorCode,
  });

  const CalendarWorkingDateExceptionMutationOutcome.ok(
    WorkingDateException exception,
  ) : this._(ok: true, exception: exception);

  const CalendarWorkingDateExceptionMutationOutcome.failed(String errorCode)
    : this._(ok: false, errorCode: errorCode);

  final bool ok;
  final WorkingDateException? exception;
  final String? errorCode;
}

/// Runs M7B create/update/cancel RPCs with a fresh idempotency key per
/// attempt. Mirrors [CalendarManualMutations] but never loops on soft
/// conflicts: overlap/stale-version/permission failures are all terminal
/// for a single attempt and surfaced to the caller as a stable error code.
class CalendarWorkingDateExceptionsMutations {
  CalendarWorkingDateExceptionsMutations({
    required this.readSession,
    required this.readRepo,
  });

  final AppSession? Function() readSession;
  final CalendarWorkingDateExceptionRepository Function() readRepo;

  Future<CalendarWorkingDateExceptionMutationOutcome> create(
    WorkingDateExceptionData data,
  ) {
    return _run((session, key) {
      return readRepo().createException(
        session,
        data: data,
        idempotencyKey: key,
      );
    });
  }

  Future<CalendarWorkingDateExceptionMutationOutcome> update(
    WorkingDateException existing,
    WorkingDateExceptionData data,
  ) {
    return _run((session, key) {
      return readRepo().updateException(
        session,
        exceptionId: existing.id,
        expectedVersion: existing.version,
        data: data,
        idempotencyKey: key,
      );
    });
  }

  Future<CalendarWorkingDateExceptionMutationOutcome> cancel(
    WorkingDateException existing, {
    required String reason,
  }) {
    return _run((session, key) {
      return readRepo().cancelException(
        session,
        exceptionId: existing.id,
        expectedVersion: existing.version,
        reason: reason,
        idempotencyKey: key,
      );
    });
  }

  Future<CalendarWorkingDateExceptionMutationOutcome> _run(
    Future<WorkingDateException> Function(AppSession session, String key)
    invoke,
  ) async {
    final session = readSession();
    if (session == null || !canEditCalendarSettings(session)) {
      return const CalendarWorkingDateExceptionMutationOutcome.failed(
        CalendarException.permissionDenied,
      );
    }
    final idempotency = CalendarIdempotencySession();
    try {
      final result = await invoke(session, idempotency.key);
      return CalendarWorkingDateExceptionMutationOutcome.ok(result);
    } on CalendarException catch (e) {
      return CalendarWorkingDateExceptionMutationOutcome.failed(e.code);
    } catch (_) {
      return const CalendarWorkingDateExceptionMutationOutcome.failed(
        CalendarException.unknown,
      );
    }
  }
}
