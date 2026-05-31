import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

class ModuleReferenceLine extends StatelessWidget {
  const ModuleReferenceLine({required this.referenceId, super.key});

  final String referenceId;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Text(
      '${l10n.referenceId}: $referenceId',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }
}
