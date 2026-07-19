import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/calendar_route_scope.dart';

/// Translated scoped-filter banner for Calendar deep links.
///
/// Shows generic Customer/Contract labels only — never entity names from
/// untrusted query parameters.
class CalendarRouteScopeBanner extends StatelessWidget {
  const CalendarRouteScopeBanner({
    required this.scope,
    required this.onClear,
    super.key,
  });

  final CalendarRouteScope scope;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    if (!scope.showsBanner) return const SizedBox.shrink();

    if (scope.isInvalid) {
      return Material(
        key: const Key('calendar-route-scope-banner'),
        color: theme.colorScheme.errorContainer,
        child: Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  l10n.calendarRouteScopeInvalid,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onErrorContainer,
                  ),
                ),
              ),
              TextButton(
                key: const Key('calendar-route-scope-clear'),
                onPressed: onClear,
                child: Text(l10n.calendarRouteScopeClear),
              ),
            ],
          ),
        ),
      );
    }

    return Material(
      key: const Key('calendar-route-scope-banner'),
      color: theme.colorScheme.secondaryContainer,
      child: Padding(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  if (scope.hasCustomer)
                    Chip(
                      key: const Key('calendar-route-scope-customer-chip'),
                      label: Text(l10n.calendarRouteScopeCustomer),
                      visualDensity: VisualDensity.compact,
                    ),
                  if (scope.hasContract)
                    Chip(
                      key: const Key('calendar-route-scope-contract-chip'),
                      label: Text(l10n.calendarRouteScopeContract),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            ),
            TextButton(
              key: const Key('calendar-route-scope-clear'),
              onPressed: onClear,
              child: Text(l10n.calendarRouteScopeClear),
            ),
          ],
        ),
      ),
    );
  }
}
