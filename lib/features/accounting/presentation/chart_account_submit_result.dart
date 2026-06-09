import '../domain/chart_account_form_state.dart';

sealed class ChartAccountSubmitResult {
  const ChartAccountSubmitResult();
}

class ChartAccountSubmitSuccess extends ChartAccountSubmitResult {
  const ChartAccountSubmitSuccess();
}

class ChartAccountSubmitFailure extends ChartAccountSubmitResult {
  const ChartAccountSubmitFailure(this.errorCodes);

  /// Validator may return multiple codes; mutation typically one.
  final List<String> errorCodes;
}

typedef ChartAccountFormSubmitHandler =
    Future<ChartAccountSubmitResult> Function(ChartAccountFormState state);
