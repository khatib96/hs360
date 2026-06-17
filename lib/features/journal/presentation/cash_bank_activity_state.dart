import '../../finance_shared/domain/date_range.dart';
import '../domain/cash_bank_activity_row.dart';

class CashBankActivityState {
  const CashBankActivityState({
    this.accountId,
    this.dateRange = const DateRange(),
    this.isLoading = false,
    this.isLoadingMore = false,
    this.page,
    this.errorCode,
    this.loadMoreErrorCode,
  });

  final String? accountId;
  final DateRange dateRange;
  final bool isLoading;
  final bool isLoadingMore;
  final CashBankActivityPage? page;
  final String? errorCode;
  final String? loadMoreErrorCode;

  bool get hasMore {
    final current = page;
    if (current == null) return false;
    return current.rows.length >= current.limit;
  }

  bool get hasError => errorCode != null;

  CashBankActivityState copyWith({
    String? accountId,
    DateRange? dateRange,
    bool? isLoading,
    bool? isLoadingMore,
    CashBankActivityPage? page,
    String? errorCode,
    String? loadMoreErrorCode,
    bool clearError = false,
    bool clearLoadMoreError = false,
  }) {
    return CashBankActivityState(
      accountId: accountId ?? this.accountId,
      dateRange: dateRange ?? this.dateRange,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      page: page ?? this.page,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      loadMoreErrorCode: clearLoadMoreError
          ? null
          : (loadMoreErrorCode ?? this.loadMoreErrorCode),
    );
  }
}
