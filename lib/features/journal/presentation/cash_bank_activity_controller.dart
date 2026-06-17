import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/finance_exception.dart';
import '../../../domain/validators/cash_bank_account_validator.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
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
        refresh();
      }
    });
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
            page: const PaginationCursor(limit: pageSize),
          );
      if (refreshId != _refreshSerial) return;

      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        page: page,
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
              limit: pageSize,
            ),
          );
      if (refreshId != _refreshSerial) return;

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
          limit: nextPage.limit,
          offset: current.offset,
          rows: [...current.rows, ...nextPage.rows],
        ),
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
