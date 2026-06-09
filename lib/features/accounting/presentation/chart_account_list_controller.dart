import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/accounting_exception.dart';
import '../../../domain/validators/chart_account_validator.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/chart_account_repository.dart';
import '../domain/account_type.dart';
import '../domain/accounting_permissions.dart';
import '../domain/chart_account.dart';
import '../domain/chart_account_filters.dart';
import '../domain/chart_account_form_state.dart';
import '../domain/chart_account_setup.dart';
import 'chart_account_list_state.dart';
import 'chart_account_submit_result.dart';

part 'chart_account_list_controller.g.dart';

@Riverpod(keepAlive: true)
class ChartAccountListController extends _$ChartAccountListController {
  static const _validator = ChartAccountValidator();

  int _refreshSerial = 0;
  bool _hasStartedInitialLoad = false;
  bool _hasSeededDefaultExpansion = false;

  static const _categoryRootCodes = {'1000', '2000', '3000', '4000', '5000'};

  @override
  ChartAccountListState build() {
    ref.listen(authControllerProvider, (previous, next) {
      final previousSession = previous?.valueOrNull;
      final nextSession = next.valueOrNull;
      if (nextSession == null) {
        state = const ChartAccountListState();
        return;
      }
      if (_shouldReloadForSession(previousSession, nextSession)) {
        refresh();
      }
    });
    Future.microtask(() {
      if (!_hasStartedInitialLoad) refresh();
    });
    return const ChartAccountListState(isLoading: true);
  }

  AppSession? get _session => ref.read(authControllerProvider).valueOrNull;

  bool _shouldReloadForSession(AppSession? previous, AppSession next) {
    if (previous == null) return true;
    return previous.userId != next.userId ||
        previous.tenantId != next.tenantId ||
        previous.isManager != next.isManager ||
        previous.permissions != next.permissions;
  }

  Future<void> refresh() async {
    _hasStartedInitialLoad = true;
    final session = _session;
    if (session == null || !canViewChartOfAccounts(session)) {
      state = const ChartAccountListState();
      return;
    }

    final refreshId = ++_refreshSerial;
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final accounts = await ref
          .read(chartAccountRepositoryProvider)
          .fetchChartAccounts(session);
      if (refreshId != _refreshSerial) return;

      Set<String>? defaultExpanded;
      if (!_hasSeededDefaultExpansion) {
        final rootIds = accounts
            .where(
              (account) =>
                  account.isSystem && _categoryRootCodes.contains(account.code),
            )
            .map((account) => account.id)
            .toSet();
        if (rootIds.isNotEmpty) {
          defaultExpanded = rootIds;
          _hasSeededDefaultExpansion = true;
        }
      }

      state = state.copyWith(
        allAccounts: accounts,
        setupIssues: detectAccountingSetupIssues(accounts),
        isLoading: false,
        expandedIds: defaultExpanded ?? state.expandedIds,
        clearError: true,
      );
    } on AccountingException catch (e) {
      if (refreshId != _refreshSerial) return;
      state = state.copyWith(isLoading: false, errorCode: e.code);
    } catch (_) {
      if (refreshId != _refreshSerial) return;
      state = state.copyWith(
        isLoading: false,
        errorCode: AccountingException.unknown,
      );
    }
  }

  void setSearch(String? search) {
    final trimmed = search?.trim();
    final value = trimmed == null || trimmed.isEmpty ? null : trimmed;
    state = state.copyWith(
      filters: ChartAccountFilters(
        search: value,
        type: state.filters.type,
        isActive: state.filters.isActive,
      ),
    );
  }

  void setType(AccountType? type) {
    state = state.copyWith(
      filters: ChartAccountFilters(
        search: state.filters.search,
        type: type,
        isActive: state.filters.isActive,
      ),
    );
  }

  void setIsActive(bool? isActive) {
    state = state.copyWith(
      filters: ChartAccountFilters(
        search: state.filters.search,
        type: state.filters.type,
        isActive: isActive,
      ),
    );
  }

  void clearFilters() {
    state = state.copyWith(filters: const ChartAccountFilters(isActive: true));
  }

  void toggleExpanded(String id) {
    final next = Set<String>.from(state.expandedIds);
    if (next.contains(id)) {
      next.remove(id);
    } else {
      next.add(id);
    }
    state = state.copyWith(expandedIds: next);
  }

  void expandAll() {
    final ids = state.allAccounts
        .where((a) => state.allAccounts.any((c) => c.parentId == a.id))
        .map((a) => a.id)
        .toSet();
    state = state.copyWith(expandedIds: ids);
  }

  void collapseAll() {
    state = state.copyWith(expandedIds: const {});
  }

  AccountType? _parentType(String? parentId) {
    if (parentId == null) return null;
    for (final account in state.allAccounts) {
      if (account.id == parentId) return account.type;
    }
    return null;
  }

  Future<ChartAccountSubmitResult> submitCreate(
    ChartAccountFormState input,
  ) async {
    final session = _session;
    if (session == null ||
        !canViewChartOfAccounts(session) ||
        !canCreateChartAccount(session)) {
      return const ChartAccountSubmitFailure([
        AccountingException.permissionDenied,
      ]);
    }

    final parentType = _parentType(input.parentId);
    final validation = _validator.validateCreate(input, parentType: parentType);
    if (!validation.isValid) {
      return ChartAccountSubmitFailure(validation.codes);
    }

    try {
      await ref
          .read(chartAccountRepositoryProvider)
          .createChartAccount(session, input);
      await refresh();
      return const ChartAccountSubmitSuccess();
    } on AccountingException catch (e) {
      return ChartAccountSubmitFailure([e.code]);
    } catch (_) {
      return const ChartAccountSubmitFailure([AccountingException.unknown]);
    }
  }

  Future<ChartAccountSubmitResult> submitUpdate(
    String id,
    ChartAccountFormState input,
  ) async {
    final session = _session;
    if (session == null ||
        !canViewChartOfAccounts(session) ||
        !canEditChartAccount(session)) {
      return const ChartAccountSubmitFailure([
        AccountingException.permissionDenied,
      ]);
    }

    ChartAccount? current;
    for (final account in state.allAccounts) {
      if (account.id == id) {
        current = account;
        break;
      }
    }
    if (current == null || !current.canManualEdit) {
      return const ChartAccountSubmitFailure([
        AccountingException.accountProtected,
      ]);
    }

    AccountType? parentType;
    if (input.type != current.type && current.parentId != null) {
      parentType = _parentType(current.parentId);
    }

    final validation = _validator.validateUpdate(
      input,
      currentType: current.type,
      currentParentId: current.parentId,
      parentType: parentType,
    );
    if (!validation.isValid) {
      return ChartAccountSubmitFailure(validation.codes);
    }

    try {
      await ref
          .read(chartAccountRepositoryProvider)
          .updateChartAccount(session, id, input);
      await refresh();
      return const ChartAccountSubmitSuccess();
    } on AccountingException catch (e) {
      return ChartAccountSubmitFailure([e.code]);
    } catch (_) {
      return const ChartAccountSubmitFailure([AccountingException.unknown]);
    }
  }

  Future<String?> deactivateAccount(String id) async {
    final session = _session;
    if (session == null ||
        !canViewChartOfAccounts(session) ||
        !canDeactivateChartAccount(session)) {
      return AccountingException.permissionDenied;
    }

    ChartAccount? current;
    for (final account in state.allAccounts) {
      if (account.id == id) {
        current = account;
        break;
      }
    }
    if (current == null || !current.canManualDeactivate) {
      return AccountingException.accountProtected;
    }

    try {
      await ref
          .read(chartAccountRepositoryProvider)
          .deactivateChartAccount(session, id);
      await refresh();
      return null;
    } on AccountingException catch (e) {
      return e.code;
    } catch (_) {
      return AccountingException.unknown;
    }
  }
}
