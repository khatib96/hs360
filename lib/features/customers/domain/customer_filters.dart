import 'customer_type.dart';

/// Query filters for customer list (repository applies to Supabase).
class CustomerFilters {
  const CustomerFilters({
    this.search,
    this.isActive,
    this.isVip,
    this.customerType,
    this.governorate,
    this.area,
  });

  final String? search;
  final bool? isActive;
  final bool? isVip;
  final CustomerType? customerType;
  final String? governorate;
  final String? area;

  bool get hasActiveFilters =>
      search?.trim().isNotEmpty == true ||
      isActive != null ||
      isVip != null ||
      customerType != null ||
      governorate?.trim().isNotEmpty == true ||
      area?.trim().isNotEmpty == true;

  bool get hasNonDefaultFilters =>
      search?.trim().isNotEmpty == true ||
      isActive != true ||
      isVip != null ||
      customerType != null ||
      governorate?.trim().isNotEmpty == true ||
      area?.trim().isNotEmpty == true;
}
