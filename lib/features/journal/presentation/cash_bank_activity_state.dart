import '../../accounting/domain/chart_account.dart';
import '../../finance_shared/domain/date_range.dart';
import '../domain/cash_bank_activity_row.dart';

class CashBankActivityState {
  const CashBankActivityState({
    this.accountId,
    this.dateRange = const DateRange(),
    this.cashBankAccounts = const [],
    this.canLoadCashAccounts = false,
    this.isLoadingMeta = false,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.page,
    this.hasMore = false,
    this.errorCode,
    this.loadMoreErrorCode,
  });

  final String? accountId;
  final DateRange dateRange;
  final List<ChartAccount> cashBankAccounts;
  final bool canLoadCashAccounts;
  final bool isLoadingMeta;
  final bool isLoading;
  final bool isLoadingMore;
  final CashBankActivityPage? page;
  final bool hasMore;
  final String? errorCode;
  final String? loadMoreErrorCode;

  bool get hasError => errorCode != null;

  CashBankActivityState copyWith({
    String? accountId,
    DateRange? dateRange,
    List<ChartAccount>? cashBankAccounts,
    bool? canLoadCashAccounts,
    bool? isLoadingMeta,
    bool? isLoading,
    bool? isLoadingMore,
    CashBankActivityPage? page,
    bool? hasMore,
    String? errorCode,
    String? loadMoreErrorCode,
    bool clearError = false,
    bool clearLoadMoreError = false,
  }) {
    return CashBankActivityState(
      accountId: accountId ?? this.accountId,
      dateRange: dateRange ?? this.dateRange,
      cashBankAccounts: cashBankAccounts ?? this.cashBankAccounts,
      canLoadCashAccounts: canLoadCashAccounts ?? this.canLoadCashAccounts,
      isLoadingMeta: isLoadingMeta ?? this.isLoadingMeta,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      loadMoreErrorCode: clearLoadMoreError
          ? null
          : (loadMoreErrorCode ?? this.loadMoreErrorCode),
    );
  }
}
