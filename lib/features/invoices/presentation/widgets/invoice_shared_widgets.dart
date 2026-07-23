import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../shared/widgets/app_state_view.dart';
import '../../../../shared/widgets/app_status_badge.dart';
import '../../../finance_shared/presentation/finance_error_messages.dart';

class InvoiceErrorState extends StatelessWidget {
  const InvoiceErrorState({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AppStateView.error(
      message: message,
      action: FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
    );
  }
}

String invoiceErrorMessage(
  AppLocalizations l10n,
  String code, {
  String? technicalDetail,
}) {
  return financeErrorMessage(l10n, code, technicalDetail: technicalDetail);
}

String invoiceValidationMessages(AppLocalizations l10n, List<String> codes) {
  return financeErrorMessages(l10n, codes);
}

Widget invoiceStatusChip(
  BuildContext context,
  String label, {
  bool cancelled = false,
  bool overdue = false,
}) {
  return AppStatusBadge(
    label: label,
    tone: cancelled
        ? AppStatusTone.error
        : overdue
        ? AppStatusTone.warning
        : AppStatusTone.brand,
  );
}
