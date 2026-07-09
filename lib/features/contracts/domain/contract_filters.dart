import '../../finance_shared/domain/date_range.dart';
import 'contract_status.dart';
import 'contract_type.dart';

/// Query filters for future bounded contract list RPCs.
class ContractFilters {
  const ContractFilters({
    this.type,
    this.status,
    this.customerId,
    this.dateRange = const DateRange(),
    this.search,
    this.lowProfitOverrideOnly = false,
  });

  final ContractType? type;
  final ContractStatus? status;
  final String? customerId;
  final DateRange dateRange;
  final String? search;
  final bool lowProfitOverrideOnly;

  bool get hasActiveFilters =>
      type != null ||
      status != null ||
      customerId?.trim().isNotEmpty == true ||
      !dateRange.isEmpty ||
      search?.trim().isNotEmpty == true ||
      lowProfitOverrideOnly;

  ContractFilters copyWith({
    ContractType? type,
    ContractStatus? status,
    String? customerId,
    DateRange? dateRange,
    String? search,
    bool? lowProfitOverrideOnly,
    bool clearType = false,
    bool clearStatus = false,
    bool clearCustomerId = false,
    bool clearSearch = false,
  }) {
    return ContractFilters(
      type: clearType ? null : (type ?? this.type),
      status: clearStatus ? null : (status ?? this.status),
      customerId: clearCustomerId ? null : (customerId ?? this.customerId),
      dateRange: dateRange ?? this.dateRange,
      search: clearSearch ? null : (search ?? this.search),
      lowProfitOverrideOnly:
          lowProfitOverrideOnly ?? this.lowProfitOverrideOnly,
    );
  }
}
