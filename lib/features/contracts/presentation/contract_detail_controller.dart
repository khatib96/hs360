import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/finance_exception.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/contract_repository.dart';
import '../domain/contract_permissions.dart';
import 'contract_detail_state.dart';

part 'contract_detail_controller.g.dart';

@riverpod
class ContractDetailController extends _$ContractDetailController {
  @override
  ContractDetailState build(String contractId) {
    Future.microtask(() => load(contractId));
    return const ContractDetailState(isLoading: true);
  }

  Future<void> load(String contractId) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null || !canViewContracts(session)) {
      state = const ContractDetailState(
        isLoading: false,
        errorCode: FinanceException.permissionDenied,
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearNotFound: true,
    );
    try {
      final detail = await ref
          .read(contractRepositoryProvider)
          .fetchContractDetail(session, contractId);
      state = ContractDetailState(isLoading: false, detail: detail);
    } on FinanceException catch (e) {
      if (e.code == FinanceException.validationFailed) {
        state = const ContractDetailState(isLoading: false, isNotFound: true);
        return;
      }
      state = ContractDetailState(isLoading: false, errorCode: e.code);
    } catch (_) {
      state = const ContractDetailState(
        isLoading: false,
        errorCode: FinanceException.unknown,
      );
    }
  }
}
