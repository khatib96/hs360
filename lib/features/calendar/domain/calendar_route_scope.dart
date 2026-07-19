import 'calendar_date.dart';
import 'calendar_filters.dart';

final _routeScopeUuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);

bool _isValidUuid(String value) => _routeScopeUuidPattern.hasMatch(value);

/// Deep-link scope carried by the Calendar route's query parameters
/// (`customerId`, `contractId`, `date`).
///
/// Distinct from [CalendarFilters]: this is a navigation intent parsed from
/// an untrusted URL, not a mutable UI filter selection. It never lives inside
/// [CalendarFilters] and is merged into the repository request only at the
/// load boundary (see `CalendarSectionLoader`) — the popover filters
/// (`CalendarState.filters`) must never contain these IDs.
///
/// When both [customerId] and [contractId] are present, this value object
/// keeps both as-is. It does **not** prove the contract belongs to the
/// customer — that relationship is only established (or safely denied)
/// when the scoped repository read returns rows, at load time in the
/// controller. An untrusted, unrelated pair simply yields empty results.
class CalendarRouteScope {
  const CalendarRouteScope._({
    this.customerId,
    this.contractId,
    this.date,
    this.isInvalid = false,
  });

  /// No scope: plain calendar navigation.
  static const empty = CalendarRouteScope._();

  /// Parses `customerId` / `contractId` / `date` query parameters.
  ///
  /// Any present-but-malformed value (invalid UUID or non `yyyy-MM-dd` date)
  /// rejects the whole scope into the invalid state rather than silently
  /// dropping just that field, so the UI can surface one clear message
  /// instead of guessing which part of the link was tampered with.
  factory CalendarRouteScope.fromQueryParameters(
    Map<String, String> queryParameters,
  ) {
    final rawCustomerId = queryParameters['customerId']?.trim();
    final rawContractId = queryParameters['contractId']?.trim();
    final rawDate = queryParameters['date']?.trim();

    var invalid = false;
    String? customerId;
    String? contractId;
    DateTime? date;

    if (rawCustomerId != null && rawCustomerId.isNotEmpty) {
      if (_isValidUuid(rawCustomerId)) {
        customerId = rawCustomerId;
      } else {
        invalid = true;
      }
    }

    if (rawContractId != null && rawContractId.isNotEmpty) {
      if (_isValidUuid(rawContractId)) {
        contractId = rawContractId;
      } else {
        invalid = true;
      }
    }

    if (rawDate != null && rawDate.isNotEmpty) {
      try {
        date = parseCalendarDateOnly(rawDate);
      } on FormatException {
        invalid = true;
      }
    }

    if (invalid) return const CalendarRouteScope._(isInvalid: true);
    if (customerId == null && contractId == null && date == null) {
      return empty;
    }
    return CalendarRouteScope._(
      customerId: customerId,
      contractId: contractId,
      date: date,
    );
  }

  final String? customerId;
  final String? contractId;
  final DateTime? date;

  /// True when the incoming query parameters could not be parsed safely.
  /// All identity fields are null in this state — nothing untrusted is kept.
  final bool isInvalid;

  bool get hasCustomer => customerId != null;
  bool get hasContract => contractId != null;

  /// True when the deep link scopes the calendar to a customer and/or contract.
  /// Date-only navigation is intentionally excluded — it focuses the day
  /// without showing the scoped-filter banner.
  bool get hasEntityScope => hasCustomer || hasContract;

  /// Banner chrome: entity scope chips, or the invalid-link warning.
  /// Date-only links return false (focus only, no empty banner).
  bool get showsBanner => isInvalid || hasEntityScope;

  /// True for plain calendar navigation: no scope and no parse failure.
  bool get isEmpty =>
      !isInvalid && customerId == null && contractId == null && date == null;

  /// Invalid scopes must not trigger unfiltered range/list/agenda reads.
  bool get blocksRepositoryReads => isInvalid;

  CalendarRouteScope copyWith({
    String? customerId,
    bool clearCustomerId = false,
    String? contractId,
    bool clearContractId = false,
    DateTime? date,
    bool clearDate = false,
  }) {
    return CalendarRouteScope._(
      customerId: clearCustomerId ? null : (customerId ?? this.customerId),
      contractId: clearContractId ? null : (contractId ?? this.contractId),
      date: clearDate ? null : (date ?? this.date),
    );
  }

  /// Query parameters for `context.replace`/`push` (URL round-trip).
  Map<String, String> toQueryParameters() {
    final params = <String, String>{};
    final customer = customerId;
    final contract = contractId;
    final scopedDate = date;
    if (customer != null) params['customerId'] = customer;
    if (contract != null) params['contractId'] = contract;
    if (scopedDate != null) params['date'] = formatCalendarDateOnly(scopedDate);
    return params;
  }

  /// Merges the customer/contract scope into [filters] for the repository
  /// request boundary only. Returns [filters] unchanged when invalid or
  /// empty of IDs — callers must keep the un-merged filters in UI state.
  CalendarFilters mergeIntoFilters(CalendarFilters filters) {
    if (isInvalid || (customerId == null && contractId == null)) {
      return filters;
    }
    return filters.copyWith(customerId: customerId, contractId: contractId);
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CalendarRouteScope &&
        other.customerId == customerId &&
        other.contractId == contractId &&
        other.date == date &&
        other.isInvalid == isInvalid;
  }

  @override
  int get hashCode => Object.hash(customerId, contractId, date, isInvalid);

  @override
  String toString() =>
      'CalendarRouteScope(customerId: $customerId, contractId: $contractId, '
      'date: $date, isInvalid: $isInvalid)';
}
