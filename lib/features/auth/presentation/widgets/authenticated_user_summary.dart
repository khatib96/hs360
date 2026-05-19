import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
import '../auth_controller.dart';

class AuthenticatedUserSummary extends ConsumerWidget {
  const AuthenticatedUserSummary({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final authState = ref.watch(authControllerProvider);

    return authState.when(
      loading: () => Text(l10n.loading, style: theme.textTheme.bodyMedium),
      error: (error, stackTrace) => const SizedBox.shrink(),
      data: (session) {
        if (session == null) return const SizedBox.shrink();

        final rows = <Widget>[];

        if (session.displayName.trim().isNotEmpty) {
          rows.add(
            _SummaryRow(
              label: l10n.sessionDisplayNameLabel,
              value: session.displayName,
              valueStyle: theme.textTheme.bodyLarge,
            ),
          );
        }

        rows.addAll([
          _SummaryRow(
            label: l10n.sessionAccountTypeLabel,
            value: _localizedAccountType(l10n, session.accountType),
            valueStyle: theme.textTheme.bodyLarge,
          ),
          _SummaryRow(
            label: l10n.sessionEmailLabel,
            value: session.email,
            valueStyle: theme.textTheme.bodyLarge,
          ),
          _SummaryRow(
            label: l10n.sessionTenantLabel,
            value: session.tenantId,
            valueStyle: theme.textTheme.labelSmall?.copyWith(
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ]);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) const SizedBox(height: 8),
              rows[i],
            ],
          ],
        );
      },
    );
  }
}

String _localizedAccountType(AppLocalizations l10n, String accountType) {
  switch (accountType) {
    case 'manager':
      return l10n.accountTypeManager;
    case 'user':
      return l10n.accountTypeUser;
    default:
      return accountType;
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.valueStyle,
  });

  final String label;
  final String value;
  final TextStyle? valueStyle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: AppColors.neutral600,
          ),
        ),
        const SizedBox(height: 2),
        Text(value, style: valueStyle ?? theme.textTheme.bodyLarge),
      ],
    );
  }
}
