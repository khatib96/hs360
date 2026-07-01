import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';

class JournalErrorState extends StatelessWidget {
  const JournalErrorState({
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

Widget journalPostedBadge(BuildContext context, AppLocalizations l10n) {
  return _journalBadge(
    context,
    l10n.journalPostedBadge,
    bg: AppColors.goldSoft,
    fg: AppColors.charcoal,
  );
}

Widget journalReversalBadge(BuildContext context, AppLocalizations l10n) {
  return _journalBadge(
    context,
    l10n.journalReversalBadge,
    bg: AppColors.warning.withValues(alpha: 0.15),
    fg: AppColors.warning,
  );
}

Widget _journalBadge(
  BuildContext context,
  String label, {
  required Color bg,
  required Color fg,
}) {
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
