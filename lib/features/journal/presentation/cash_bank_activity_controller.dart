import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/finance_exception.dart';
import '../../../domain/validators/cash_bank_account_validator.dart';
import '../../accounting/data/chart_account_repository.dart';
import '../../accounting/domain/chart_account.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/domain/cash_bank_posting_accounts.dart';
import '../../finance_shared/domain/date_range.dart';
import '../../finance_shared/domain/finance_permissions.dart';
import '../../finance_shared/domain/pagination_cursor.dart';
import '../data/cash_bank_repository.dart';
import '../domain/cash_bank_activity_row.dart';
import 'cash_bank_activity_state.dart';

part 'cash_bank_activity_controller.g.dart';

@Riverpod(keepAlive: true)
class CashBankActivityController extends _$CashBankActivityController {
  static const pageSize = 50;

  CashBankActivityPage _trimPage(CashBankActivityPage page) {
    return CashBankActivityPage(
      accountId: page.accountId,
      accountCode: page.accountCode,
      accountNameAr: page.accountNameAr,
      accountNameEn: page.accountNameEn,
      dateFrom: page.dateFrom,
      dateTo: page.dateTo,
      openingBalance: page.openingBalance,
      limit: pageSize,
      offset: page.offset,
      rows: page.rows.take(pageSize).toList(),
    );
  }

  int _refreshSerial = 0;

  @override
  CashBankActivityState build() {
    ref.listen(authControllerProvider, (previous, next) {
      final previousSession = previous?.valueOrNull;
      final nextSession = next.valueOrNull;
      if (nextSession == null) {
        state = const CashBankActivityState();
        return;
      }
      if (_shouldReloadForSession(previousSession, nextSession)) {
        loadCashBankAccounts();
        refresh();
      }
    });
    Future.microtask(loadCashBankAccounts);
    return const CashBankActivityState();
  }

  AppSession? get _session => ref.read(authControllerProvider).valueOrNull;

  bool _shouldReloadForSession(AppSession? previous, AppSession next) {
    if (previous == null) return true;
    return previous.userId != next.userId ||
        previous.tenantId != next.tenantId ||
        previous.isManager != next.isManager ||
        previous.permissions != next.permissions;
  }

  void setAccountId(String? accountId) {
    state = state.copyWith(
      accountId: accountId?.trim().isEmpty == true ? null : accountId?.trim(),
      clearError: true,
    );
    refresh();
  }

  void setDateRange(DateRange dateRange) {
    state = state.copyWith(dateRange: dateRange, clearError: true);
    refresh();
  }

  void setDateFrom(DateTime? from) {
    setDateRange(state.dateRange.copyWith(from: from));
  }

  void setDateTo(DateTime? to) {
    setDateRange(state.dateRange.copyWith(to: to));
  }

  Future<void> loadCashBankAccounts() async {
    final session = _session;
    if (session == null || !canViewCashBank(session)) {
      state = state.copyWith(
        cashBankAccounts: const [],
        canLoadCashAccounts: false,
        isLoadingMeta: false,
      );
      return;
    }

    final canLoad = canLoadCashBankPostingAccounts(session);
    state = state.copyWith(
      isLoadingMeta: true,
      canLoadCashAccounts: canLoad,
    );

    try {
      var accounts = const <ChartAccount>[];
      if (canLoad) {
        final all = await ref
            .read(chartAccountRepositoryProvider)
            .fetchChartAccounts(session, isActive: true);
        accounts = filterCashBankPostingAccounts(all);
      }
      state = state.copyWith(
        isLoadingMeta: false,
        cashBankAccounts: accounts,
      );
    } on FinanceException catch (e) {
      state = state.copyWith(isLoadingMeta: false, errorCode: e.code);
    } catch (_) {
      state = state.copyWith(
        isLoadingMeta: false,
        errorCode: FinanceException.unknown,
      );
    }
  }

  Future<void> refresh() async {
    final session = _session;
    if (session == null || !canViewCashBank(session)) {
      state = const CashBankActivityState();
      return;
    }

    final accountValidation = const CashBankAccountValidator().validate(
      state.accountId,
    );
    if (!accountValidation.isValid) {
      state = state.copyWith(
        isLoading: false,
        errorCode: accountValidation.codes.first,
      );
      return;
    }

    final refreshId = ++_refreshSerial;
    state = state.copyWith(
      isLoading: true,
      isLoadingMore: false,
      clearError: true,
      clearLoadMoreError: true,
    );

    try {
      final page = await ref
          .read(cashBankRepositoryProvider)
          .getCashBankActivity(
            session,
            accountId: state.accountId!,
            dateRange: state.dateRange,
            page: const PaginationCursor(limit: pageSize + 1),
          );
      if (refreshId != _refreshSerial) return;

      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        page: _trimPage(page),
        hasMore: page.rows.length > pageSize,
        clearError: true,
      );
    } on FinanceException catch (e) {
      if (refreshId != _refreshSerial) return;
      state = state.copyWith(isLoading: false, errorCode: e.code);
    } catch (_) {
      if (refreshId != _refreshSerial) return;
      state = state.copyWith(
        isLoading: false,
        errorCode: FinanceException.unknown,
      );
    }
  }

  Future<void> loadMore() async {
    final current = state.page;
    if (state.isLoading ||
        state.isLoadingMore ||
        current == null ||
        !state.hasMore) {
      return;
    }

    final session = _session;
    if (session == null || !canViewCashBank(session)) return;

    final refreshId = ++_refreshSerial;
    state = state.copyWith(
      isLoadingMore: true,
      clearError: true,
      clearLoadMoreError: true,
    );

    try {
      final nextPage = await ref
          .read(cashBankRepositoryProvider)
          .getCashBankActivity(
            session,
            accountId: state.accountId!,
            dateRange: state.dateRange,
            page: PaginationCursor(
              offset: current.offset + current.rows.length,
              limit: pageSize + 1,
            ),
          );
      if (refreshId != _refreshSerial) return;

      final mergedRows = [
        ...current.rows,
        ...nextPage.rows.take(pageSize),
      ];

      state = state.copyWith(
        isLoadingMore: false,
        page: CashBankActivityPage(
          accountId: nextPage.accountId,
          accountCode: nextPage.accountCode,
          accountNameAr: nextPage.accountNameAr,
          accountNameEn: nextPage.accountNameEn,
          dateFrom: nextPage.dateFrom,
          dateTo: nextPage.dateTo,
          openingBalance: nextPage.openingBalance,
          limit: pageSize,
          offset: current.offset,
          rows: mergedRows,
        ),
        hasMore: nextPage.rows.length > pageSize,
        clearLoadMoreError: true,
      );
    } on FinanceException catch (e) {
      if (refreshId != _refreshSerial) return;
      state = state.copyWith(isLoadingMore: false, loadMoreErrorCode: e.code);
    } catch (_) {
      if (refreshId != _refreshSerial) return;
      state = state.copyWith(
        isLoadingMore: false,
        loadMoreErrorCode: FinanceException.unknown,
      );
    }
  }
}
