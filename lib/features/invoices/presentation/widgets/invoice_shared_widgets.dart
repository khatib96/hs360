import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
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
    return Center(
      child: Padding(
        padding: const EdgeInsetsDirectional.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: Text(l10n.retry)),
          ],
        ),
      ),
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
  final Color bg;
  final Color fg;
  if (cancelled) {
    bg = AppColors.error.withValues(alpha: 0.12);
    fg = AppColors.error;
  } else if (overdue) {
    bg = AppColors.warning.withValues(alpha: 0.15);
    fg = AppColors.warning;
  } else {
    bg = AppColors.goldSoft;
    fg = AppColors.charcoal;
  }
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: bg,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(color: fg),
    ),
  );
}
