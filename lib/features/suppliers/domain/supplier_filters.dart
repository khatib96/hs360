/// Query filters for supplier list (repository applies to Supabase).
class SupplierFilters {
  const SupplierFilters({
    this.search,
    this.isActive,
  });

  final String? search;
  final bool? isActive;

  bool get hasActiveFilters =>
      search?.trim().isNotEmpty == true || isActive != null;
}
