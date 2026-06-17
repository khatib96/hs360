import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/errors/finance_exception.dart';
import '../../../domain/finance/tax_settings.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../finance_shared/domain/finance_permissions.dart';
import '../data/tax_settings_repository.dart';
import 'tax_settings_state.dart';

part 'tax_settings_controller.g.dart';

@riverpod
class TaxSettingsController extends _$TaxSettingsController {
  @override
  TaxSettingsState build() {
    Future.microtask(load);
    return const TaxSettingsState(isLoading: true);
  }

  Future<void> load() async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null || !canViewTaxSettings(session)) {
      state = const TaxSettingsState(
        isLoading: false,
        errorCode: FinanceException.permissionDenied,
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      saveSuccess: false,
    );
    try {
      final rates = await ref
          .read(taxSettingsRepositoryProvider)
          .listTaxRates(session, activeOnly: false);
      state = TaxSettingsState(
        isLoading: false,
        canEdit: canEditTaxSettings(session),
        rates: rates,
        settings: state.settings,
      );
    } on FinanceException catch (e) {
      state = state.copyWith(isLoading: false, errorCode: e.code);
    } catch (_) {
      state = state.copyWith(
        isLoading: false,
        errorCode: FinanceException.unknown,
      );
    }
  }

  Future<String?> saveSettings(TaxSettings settings) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null || !canEditTaxSettings(session)) {
      return FinanceException.permissionDenied;
    }

    state = state.copyWith(
      isSaving: true,
      clearError: true,
      saveSuccess: false,
    );
    try {
      await ref
          .read(taxSettingsRepositoryProvider)
          .updateTaxSettings(session, settings);
      state = state.copyWith(
        isSaving: false,
        settings: settings,
        saveSuccess: true,
      );
      await load();
      return null;
    } on FinanceException catch (e) {
      state = state.copyWith(isSaving: false, errorCode: e.code);
      return e.code;
    } catch (_) {
      state = state.copyWith(
        isSaving: false,
        errorCode: FinanceException.unknown,
      );
      return FinanceException.unknown;
    }
  }
}
