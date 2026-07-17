// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar_assignment_lookup_controller.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

String _$calendarAssignmentLookupControllerHash() =>
    r'0507f202ae455a850deed10739eb1cccb756975b';

/// Debounced active-employee lookup for the M8 assignment dialog.
///
/// Auto-disposes with the dialog; any auth identity change invalidates
/// in-flight requests and resets the state so no cross-tenant candidates
/// can leak into a still-open dialog.
///
/// Copied from [CalendarAssignmentLookupController].
@ProviderFor(CalendarAssignmentLookupController)
final calendarAssignmentLookupControllerProvider =
    AutoDisposeNotifierProvider<
      CalendarAssignmentLookupController,
      CalendarAssignmentLookupState
    >.internal(
      CalendarAssignmentLookupController.new,
      name: r'calendarAssignmentLookupControllerProvider',
      debugGetCreateSourceHash: const bool.fromEnvironment('dart.vm.product')
          ? null
          : _$calendarAssignmentLookupControllerHash,
      dependencies: null,
      allTransitiveDependencies: null,
    );

typedef _$CalendarAssignmentLookupController =
    AutoDisposeNotifier<CalendarAssignmentLookupState>;
// ignore_for_file: type=lint
// ignore_for_file: subtype_of_sealed_class, invalid_use_of_internal_member, invalid_use_of_visible_for_testing_member, deprecated_member_use_from_same_package
