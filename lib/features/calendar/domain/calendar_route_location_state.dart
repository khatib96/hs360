/// Route View / directions location resolution state.
///
/// Wired from the RPC strings `mapped` / `url_only` / `invalid` / `missing`
/// returned by `get_calendar_route_day` and `get_calendar_event_directions`.
enum CalendarRouteLocationState {
  /// Valid coordinates on the service location.
  mapped,

  /// No valid coordinates, but an allowlisted Google Maps URL is present.
  urlOnly,

  /// A location value is present but is neither valid coordinates nor an
  /// allowlisted URL.
  invalid,

  /// No location captured on the service location at all.
  missing;

  static CalendarRouteLocationState? fromRpc(String value) {
    return switch (value) {
      'mapped' => CalendarRouteLocationState.mapped,
      'url_only' => CalendarRouteLocationState.urlOnly,
      'invalid' => CalendarRouteLocationState.invalid,
      'missing' => CalendarRouteLocationState.missing,
      _ => null,
    };
  }

  String get rpcValue => switch (this) {
    CalendarRouteLocationState.mapped => 'mapped',
    CalendarRouteLocationState.urlOnly => 'url_only',
    CalendarRouteLocationState.invalid => 'invalid',
    CalendarRouteLocationState.missing => 'missing',
  };

  /// True when a directions target can be resolved for this state
  /// (`mapped` or `url_only`, matching `calendar_directions_available_from_location`).
  bool get supportsDirections =>
      this == CalendarRouteLocationState.mapped ||
      this == CalendarRouteLocationState.urlOnly;
}
