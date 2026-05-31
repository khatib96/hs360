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
}
