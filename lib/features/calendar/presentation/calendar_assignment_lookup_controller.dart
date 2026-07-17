import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/calendar_exception.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/calendar_repository.dart';
import '../domain/calendar_event_participant.dart';

part 'calendar_assignment_lookup_controller.g.dart';

/// Snapshot of the assignment candidate lookup (search + results).
class CalendarAssignmentLookupState {
  const CalendarAssignmentLookupState({
    this.query = '',
    this.isLoading = false,
    this.candidates = const [],
    this.errorCode,
  });

  final String query;
  final bool isLoading;
  final List<CalendarParticipantCandidate> candidates;
  final String? errorCode;

  CalendarAssignmentLookupState copyWith({
    String? query,
    bool? isLoading,
    List<CalendarParticipantCandidate>? candidates,
    String? errorCode,
    bool clearError = false,
  }) {
    return CalendarAssignmentLookupState(
      query: query ?? this.query,
      isLoading: isLoading ?? this.isLoading,
      candidates: candidates ?? this.candidates,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
    );
  }
}

/// Debounced active-employee lookup for the M8 assignment dialog.
///
/// Auto-disposes with the dialog; any auth identity change invalidates
/// in-flight requests and resets the state so no cross-tenant candidates
/// can leak into a still-open dialog.
@riverpod
class CalendarAssignmentLookupController
    extends _$CalendarAssignmentLookupController {
  Timer? _debounce;
  var _generation = 0;

  static const debounceDuration = Duration(milliseconds: 300);

  @override
  CalendarAssignmentLookupState build() {
    ref.listen(authControllerProvider, (previous, next) {
      _generation++;
      _debounce?.cancel();
      state = const CalendarAssignmentLookupState();
    });
    ref.onDispose(() => _debounce?.cancel());
    Future.microtask(() => _load(''));
    return const CalendarAssignmentLookupState(isLoading: true);
  }

  /// Debounced search; an empty query lists the first active employees.
  void search(String query) {
    _debounce?.cancel();
    state = state.copyWith(query: query);
    _debounce = Timer(debounceDuration, () => _load(query));
  }

  Future<void> retry() {
    _debounce?.cancel();
    return _load(state.query);
  }

  bool _sameSession(int generation, AppSession captured) {
    if (generation != _generation) return false;
    final current = ref.read(authControllerProvider).valueOrNull;
    return current != null &&
        current.userId == captured.userId &&
        current.tenantId == captured.tenantId &&
        current.accountType == captured.accountType &&
        current.isManager == captured.isManager &&
        current.permissions == captured.permissions;
  }

  Future<void> _load(String query) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) {
      state = state.copyWith(
        isLoading: false,
        candidates: const [],
        errorCode: CalendarException.permissionDenied,
      );
      return;
    }
    final generation = ++_generation;
    state = state.copyWith(isLoading: true, query: query, clearError: true);
    try {
      final trimmed = query.trim();
      final rows = await ref
          .read(calendarRepositoryProvider)
          .listParticipantCandidates(
            session,
            search: trimmed.isEmpty ? null : trimmed,
          );
      if (!_sameSession(generation, session)) return;
      state = state.copyWith(
        isLoading: false,
        candidates: rows,
        clearError: true,
      );
    } on CalendarException catch (e) {
      if (!_sameSession(generation, session)) return;
      state = state.copyWith(isLoading: false, errorCode: e.code);
    } catch (_) {
      if (!_sameSession(generation, session)) return;
      state = state.copyWith(
        isLoading: false,
        errorCode: CalendarException.unknown,
      );
    }
  }
}
