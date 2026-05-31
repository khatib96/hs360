/// Query filters for supplier list (repository applies to Supabase).
class SupplierFilters {
  const SupplierFilters({this.search, this.isActive});

  final String? search;
  final bool? isActive;

  bool get hasActiveFilters =>
      search?.trim().isNotEmpty == true || isActive != null;

  /// True when the user has changed filters away from the M5 default view.
  ///
  /// M5 defaults supplier lists to active-only, so `isActive == true` is not a
  /// user-applied filter for empty-state copy.
  bool get hasNonDefaultFilters =>
      search?.trim().isNotEmpty == true || isActive != true;
}
