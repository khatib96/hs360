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

  VoucherFilters copyWith({
    VoucherType? type,
    VoucherStatus? status,
    String? partyId,
    DateRange? dateRange,
    String? search,
    bool clearType = false,
    bool clearStatus = false,
    bool clearPartyId = false,
    bool clearSearch = false,
  }) {
    return VoucherFilters(
      type: clearType ? null : (type ?? this.type),
      status: clearStatus ? null : (status ?? this.status),
      partyId: clearPartyId ? null : (partyId ?? this.partyId),
      dateRange: dateRange ?? this.dateRange,
      search: clearSearch ? null : (search ?? this.search),
    );
  }
}
