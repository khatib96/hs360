import 'package:flutter/material.dart';

import '../../domain/account_type.dart';
import '../../domain/chart_account.dart';
import '../../domain/chart_account_form_state.dart';
import '../chart_account_submit_result.dart';
import 'chart_account_form.dart';

class ChartAccountFormDialog extends StatefulWidget {
  const ChartAccountFormDialog({
    required this.onSubmit,
    required this.title,
    required this.submitLabel,
    this.initialAccount,
    this.parentOptions = const [],
    super.key,
  });

  final ChartAccountFormSubmitHandler onSubmit;
  final String title;
  final String submitLabel;
  final ChartAccount? initialAccount;
  final List<ChartAccount> parentOptions;

  bool get isEdit => initialAccount != null;

  @override
  State<ChartAccountFormDialog> createState() => _ChartAccountFormDialogState();
}

class _ChartAccountFormDialogState extends State<ChartAccountFormDialog> {
  bool _isSubmitting = false;
  List<String> _errorCodes = const [];

  Future<void> _handleSubmit(ChartAccountFormState formState) async {
    setState(() {
      _isSubmitting = true;
      _errorCodes = const [];
    });

    final result = await widget.onSubmit(formState);
    if (!mounted) return;

    switch (result) {
      case ChartAccountSubmitSuccess():
        Navigator.of(context).pop(const ChartAccountSubmitSuccess());
      case ChartAccountSubmitFailure(:final errorCodes):
        setState(() {
          _isSubmitting = false;
          _errorCodes = errorCodes;
        });
    }
  }

  @override
  Widget build(BuildContext context) {
    final account = widget.initialAccount;
    final width = MediaQuery.sizeOf(context).width;
    final dialogWidth = width >= 900 ? 560.0 : width * 0.92;

    return Dialog(
      child: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          padding: const EdgeInsetsDirectional.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 20),
              ChartAccountForm(
                key: ValueKey('chart-account-form-${account?.id ?? 'new'}'),
                isEdit: widget.isEdit,
                isSubmitting: _isSubmitting,
                submitLabel: widget.submitLabel,
                onSubmit: _handleSubmit,
                onCancel: () => Navigator.of(context).pop(),
                initialCode: account?.code,
                initialNameAr: account?.nameAr ?? '',
                initialNameEn: account?.nameEn ?? '',
                initialType: account?.type ?? AccountType.expense,
                parentOptions: widget.parentOptions,
                errorCodes: _errorCodes,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Future<ChartAccountSubmitResult?> showChartAccountFormDialog({
  required BuildContext context,
  required String title,
  required String submitLabel,
  required ChartAccountFormSubmitHandler onSubmit,
  ChartAccount? initialAccount,
  List<ChartAccount> parentOptions = const [],
}) {
  return showDialog<ChartAccountSubmitResult>(
    context: context,
    builder: (_) => ChartAccountFormDialog(
      title: title,
      submitLabel: submitLabel,
      onSubmit: onSubmit,
      initialAccount: initialAccount,
      parentOptions: parentOptions,
    ),
  );
}
