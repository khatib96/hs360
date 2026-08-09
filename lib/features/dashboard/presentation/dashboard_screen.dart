import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/app_state_view.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/dashboard_summary.dart';
import 'dashboard_providers.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  static const routePath = AppRoutes.dashboard;
  static const routeName = AppRoutes.dashboardName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(authControllerProvider).valueOrNull;

    if (session == null) {
      return AppShell(
        title: l10n.dashboard,
        currentRoute: AppRoutes.dashboard,
        body: AppStateView.loading(message: l10n.loading),
      );
    }

    final summary = ref.watch(dashboardSummaryProvider(session));
    return AppShell(
      title: l10n.dashboard,
      currentRoute: AppRoutes.dashboard,
      moduleActions: [
        IconButton(
          key: const Key('dashboard-refresh'),
          tooltip: l10n.dashboardRefresh,
          onPressed: () => ref.invalidate(dashboardSummaryProvider(session)),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: summary.when(
        loading: () => AppStateView.loading(message: l10n.loading),
        error: (_, _) => AppStateView.error(
          message: l10n.dashboardLoadError,
          action: FilledButton.icon(
            onPressed: () => ref.invalidate(dashboardSummaryProvider(session)),
            icon: const Icon(Icons.refresh_rounded),
            label: Text(l10n.retry),
          ),
        ),
        data: (data) => _DashboardContent(summary: data),
      ),
    );
  }
}

class _DashboardContent extends StatelessWidget {
  const _DashboardContent({required this.summary});

  final DashboardSummary summary;

  void _open(BuildContext context, String kind) {
    context.push(
      AppRoutes.dashboardDrilldownPath(kind, date: summary.businessDate),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat.yMMMMEEEEd(locale).format(summary.businessDate);

    return SingleChildScrollView(
      padding: AppSpacing.pageWide,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.contentMaxWidth),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppPageHeader(
                title: l10n.dashboard,
                subtitle: l10n.dashboardM5Subtitle,
                eyebrow: '${l10n.dashboardBusinessDate} · $date',
              ),
              const SizedBox(height: AppSpacing.lg),
              LayoutBuilder(
                builder: (context, constraints) {
                  final gap = AppSpacing.md;
                  final columns = constraints.maxWidth >= 1040
                      ? 2
                      : constraints.maxWidth >= 620
                      ? 2
                      : 1;
                  final width =
                      (constraints.maxWidth - (columns - 1) * gap) / columns;
                  return Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      SizedBox(
                        width: width,
                        child: _DashboardCard(
                          key: const Key('dashboard-schedule-card'),
                          title: l10n.dashboardTodaySchedule,
                          icon: Icons.event_available_outlined,
                          available: summary.todaySchedule.visible,
                          metrics: [
                            _DashboardMetric(
                              label: l10n.dashboardMetricTotal,
                              value: '${summary.todaySchedule.total}',
                              onTap: () => _open(context, 'today_schedule'),
                            ),
                            _DashboardMetric(
                              label: l10n.dashboardMetricCompleted,
                              value: '${summary.todaySchedule.completed}',
                              onTap: () => _open(context, 'today_completed'),
                            ),
                            _DashboardMetric(
                              label: l10n.dashboardMetricRemaining,
                              value: '${summary.todaySchedule.remaining}',
                              onTap: () => _open(context, 'today_remaining'),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _DashboardCard(
                          key: const Key('dashboard-overdue-card'),
                          title: l10n.dashboardOverdue,
                          icon: Icons.notification_important_outlined,
                          tone: summary.overdue.count > 0
                              ? Theme.of(context).colorScheme.error
                              : Theme.of(context).colorScheme.primary,
                          available: summary.overdue.visible,
                          metrics: [
                            _DashboardMetric(
                              label: l10n.dashboardMetricOverdue,
                              value: '${summary.overdue.count}',
                              onTap: () => _open(context, 'overdue'),
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _DashboardCard(
                          key: const Key('dashboard-contracts-card'),
                          title: l10n.dashboardContractsAssets,
                          icon: Icons.assignment_outlined,
                          available: summary.contracts.visible,
                          metrics: [
                            _DashboardMetric(
                              label: l10n.dashboardMetricActiveContracts,
                              value: '${summary.contracts.active}',
                              onTap: () => _open(context, 'active_contracts'),
                            ),
                            _DashboardMetric(
                              label: l10n.dashboardMetricActiveTrials,
                              value: '${summary.contracts.trials}',
                              onTap: () => _open(context, 'active_trials'),
                            ),
                            _DashboardMetric(
                              label: l10n.dashboardMetricActiveRentals,
                              value: '${summary.contracts.rentals}',
                              onTap: () => _open(context, 'active_rentals'),
                            ),
                            if (summary.contracts.assetConditionVisible) ...[
                              _DashboardMetric(
                                label: l10n.dashboardMetricRentedAssets,
                                value: '${summary.contracts.assetsRented}',
                                onTap: () => _open(context, 'assets_rented'),
                              ),
                              _DashboardMetric(
                                label: l10n.dashboardMetricTrialAssets,
                                value: '${summary.contracts.assetsTrial}',
                                onTap: () => _open(context, 'assets_trial'),
                              ),
                              _DashboardMetric(
                                label: l10n.dashboardMetricAssetsAttention,
                                value: '${summary.contracts.assetsAttention}',
                                onTap: () => _open(context, 'assets_attention'),
                              ),
                            ],
                          ],
                        ),
                      ),
                      SizedBox(
                        width: width,
                        child: _DashboardCard(
                          key: const Key('dashboard-finance-card'),
                          title: l10n.dashboardFinancial,
                          icon: Icons.account_balance_wallet_outlined,
                          available: summary.financial.visible,
                          metrics: [
                            if (summary.financial.collectionsVisible)
                              _DashboardMetric(
                                label: l10n.dashboardMetricCollections,
                                value:
                                    '${NumberFormat.decimalPattern(locale).format(summary.financial.collections)} ${summary.currencyCode}',
                                onTap: () => _open(context, 'collections'),
                              ),
                            if (summary.financial.outstandingVisible)
                              _DashboardMetric(
                                label: l10n.dashboardMetricOutstanding,
                                value:
                                    '${NumberFormat.decimalPattern(locale).format(summary.financial.outstanding)} ${summary.currencyCode}',
                                onTap: () => _open(context, 'outstanding'),
                              ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashboardMetric {
  const _DashboardMetric({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.title,
    required this.icon,
    required this.available,
    required this.metrics,
    this.tone,
    super.key,
  });

  final String title;
  final IconData icon;
  final bool available;
  final List<_DashboardMetric> metrics;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = AppLocalizations.of(context)!;
    final accent = tone ?? theme.colorScheme.primary;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: AppSpacing.card,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: AppRadii.controlRadius,
                  ),
                  child: Icon(icon, color: accent),
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(title, style: theme.textTheme.titleMedium),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.md),
            if (!available)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                child: Text(
                  l10n.dashboardUnavailable,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              ...metrics.map(
                (metric) => Semantics(
                  button: true,
                  label: '${metric.label}: ${metric.value}',
                  child: InkWell(
                    onTap: metric.onTap,
                    borderRadius: AppRadii.controlRadius,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpacing.sm,
                      ),
                      child: Row(
                        children: [
                          Expanded(child: Text(metric.label)),
                          Text(
                            metric.value,
                            style: theme.textTheme.titleLarge?.copyWith(
                              color: accent,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 14,
                            color: theme.colorScheme.outline,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
