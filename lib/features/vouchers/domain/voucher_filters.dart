import '../../finance_shared/domain/date_range.dart';
import 'voucher_status.dart';
import 'voucher_type.dart';

class VoucherFilters {
  const VoucherFilters({
    this.partyId,
    this.type,
    this.status,
    this.dateRange = const DateRange(),
    this.search,
  });

  final String? partyId;
  final VoucherType? type;
  final VoucherStatus? status;
  final DateRange dateRange;
  final String? search;

  bool get hasActiveFilters =>
      partyId?.trim().isNotEmpty == true ||
      type != null ||
      status != null ||
      !dateRange.isEmpty ||
      search?.trim().isNotEmpty == true;
}
