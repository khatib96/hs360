import '../../finance_shared/domain/date_range.dart';
import 'invoice_status.dart';
import 'invoice_type.dart';

/// Query filters for bounded invoice list RPCs.
class InvoiceFilters {
  const InvoiceFilters({
    this.type,
    this.status,
    this.partyId,
    this.dateRange = const DateRange(),
    this.search,
  });

  final InvoiceType? type;
  final InvoiceStatus? status;
  final String? partyId;
  final DateRange dateRange;
  final String? search;

  bool get hasActiveFilters =>
      type != null ||
      status != null ||
      partyId?.trim().isNotEmpty == true ||
      !dateRange.isEmpty ||
      search?.trim().isNotEmpty == true;
}
