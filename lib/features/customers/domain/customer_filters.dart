import 'customer_type.dart';

/// Query filters for customer list (repository applies to Supabase).
class CustomerFilters {
  const CustomerFilters({
    this.search,
    this.isActive,
    this.isVip,
    this.customerType,
    this.area,
    this.city,
  });

  final String? search;
  final bool? isActive;
  final bool? isVip;
  final CustomerType? customerType;
  final String? area;
  final String? city;

  bool get hasActiveFilters =>
      search?.trim().isNotEmpty == true ||
      isActive != null ||
      isVip != null ||
      customerType != null ||
      area?.trim().isNotEmpty == true ||
      city?.trim().isNotEmpty == true;

  /// True when the user has changed filters away from the M5 default view.
  ///
  /// M5 defaults customer lists to active-only, so `isActive == true` is not a
  /// user-applied filter for empty-state copy.
  bool get hasNonDefaultFilters =>
      search?.trim().isNotEmpty == true ||
      isActive != true ||
      isVip != null ||
      customerType != null ||
      area?.trim().isNotEmpty == true ||
      city?.trim().isNotEmpty == true;
}
