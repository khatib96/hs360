import '../../../domain/finance/tax_rate.dart';
import '../../../domain/finance/tax_settings.dart';

class TaxSettingsState {
  const TaxSettingsState({
    this.isLoading = false,
    this.isSaving = false,
    this.canEdit = false,
    this.rates = const [],
    this.settings,
    this.errorCode,
    this.saveSuccess = false,
  });

  final bool isLoading;
  final bool isSaving;
  final bool canEdit;
  final List<TaxRateVersion> rates;
  final TaxSettings? settings;
  final String? errorCode;
  final bool saveSuccess;

  bool get hasError => errorCode != null;

  TaxSettingsState copyWith({
    bool? isLoading,
    bool? isSaving,
    bool? canEdit,
    List<TaxRateVersion>? rates,
    TaxSettings? settings,
    String? errorCode,
    bool? saveSuccess,
    bool clearError = false,
  }) {
    return TaxSettingsState(
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      canEdit: canEdit ?? this.canEdit,
      rates: rates ?? this.rates,
      settings: settings ?? this.settings,
      errorCode: clearError ? null : (errorCode ?? this.errorCode),
      saveSuccess: saveSuccess ?? this.saveSuccess,
    );
  }
}
