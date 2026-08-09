import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/routing/app_routes.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_page_header.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/app_state_view.dart';
import '../../../shared/widgets/app_table_frame.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/dashboard_repository.dart';
import '../domain/activity_feed.dart';
import 'activity_feed_list.dart';

class DashboardDrilldownScreen extends ConsumerStatefulWidget {
  const DashboardDrilldownScreen({
    required this.kind,
    required this.dateQueryParam,
    super.key,
  });

  final String kind;
  final String? dateQueryParam;

  @override
  ConsumerState<DashboardDrilldownScreen> createState() =>
      _DashboardDrilldownScreenState();
}

class _DashboardDrilldownScreenState
    extends ConsumerState<DashboardDrilldownScreen> {
  ActivityFeedPage? _page;
  bool _loading = true;
  bool _loadingMore = false;
  Object? _error;
  int _requestSerial = 0;

  DateTime? get _date {
    final raw = widget.dateQueryParam ?? '';
    if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(raw)) return null;
    final parsed = DateTime.tryParse(raw);
    if (parsed == null || _formatDate(parsed) != raw) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  @override
  void initState() {
    super.initState();
    ref.listenManual(authControllerProvider, (previous, next) {
      final before = previous?.valueOrNull;
      final after = next.valueOrNull;
      if (after != null && _identityChanged(before, after)) _refresh();
    });
    Future.microtask(_refresh);
  }

  bool _identityChanged(AppSession? before, AppSession after) {
    return before == null ||
        before.userId != after.userId ||
        before.tenantId != after.tenantId ||
        before.permissions != after.permissions;
  }

  @override
  void didUpdateWidget(covariant DashboardDrilldownScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.kind != widget.kind ||
        oldWidget.dateQueryParam != widget.dateQueryParam) {
      _refresh();
    }
  }

  Future<void> _refresh() async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return;
    final date = _date;
    final serial = ++_requestSerial;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
    });
    if (date == null) {
      setState(() {
        _loading = false;
        _error = const DashboardException(DashboardException.validationFailed);
      });
      return;
    }
    try {
      final page = await ref
          .read(dashboardRepositoryProvider)
          .listDashboardDrilldown(
            session,
            kind: widget.kind,
            businessDate: date,
          );
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _page = page;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  Future<void> _loadMore() async {
    final session = ref.read(authControllerProvider).valueOrNull;
    final current = _page;
    final date = _date;
    if (session == null || current == null || date == null || _loadingMore) {
      return;
    }
    final serial = _requestSerial;
    setState(() => _loadingMore = true);
    try {
      final next = await ref
          .read(dashboardRepositoryProvider)
          .listDashboardDrilldown(
            session,
            kind: widget.kind,
            businessDate: date,
            offset: current.items.length,
          );
      if (!mounted || serial != _requestSerial || _page != current) return;
      setState(() {
        _page = ActivityFeedPage(
          businessDate: next.businessDate,
          timezoneName: next.timezoneName,
          currencyCode: next.currencyCode,
          items: [...current.items, ...next.items],
          totalCount: next.totalCount,
          hasMore: next.hasMore,
          kind: next.kind,
        );
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted && serial == _requestSerial) {
        setState(() => _loadingMore = false);
      }
    }
  }

  static String _formatDate(DateTime value) {
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '${value.year}-$month-$day';
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final title = _kindTitle(l10n, widget.kind);
    return AppShell(
      title: title,
      currentRoute: AppRoutes.dashboard,
      moduleActions: [
        IconButton(
          tooltip: l10n.dashboardRefresh,
          onPressed: _loading ? null : _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      body: Padding(
        padding: AppSpacing.pageWide,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 980),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppPageHeader(
                  title: title,
                  subtitle: _page == null
                      ? null
                      : l10n.dashboardRecordCount(_page!.totalCount),
                  leading: IconButton.outlined(
                    tooltip: MaterialLocalizations.of(
                      context,
                    ).backButtonTooltip,
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                  ),
                ),
                const SizedBox(height: AppSpacing.md),
                Expanded(child: _buildBody(l10n)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody(AppLocalizations l10n) {
    if (_loading && _page == null) {
      return AppStateView.loading(message: l10n.loading);
    }
    if (_error != null && _page == null) {
      return AppStateView.error(
        message: l10n.dashboardLoadError,
        action: FilledButton(onPressed: _refresh, child: Text(l10n.retry)),
      );
    }
    final page = _page;
    if (page == null || page.items.isEmpty) {
      return AppStateView.empty(
        message: l10n.dailyActivityEmpty,
        icon: Icons.inbox_outlined,
      );
    }
    return Column(
      children: [
        Expanded(
          child: AppTableFrame(
            child: ActivityFeedList(
              items: page.items,
              currencyCode: page.currencyCode,
              onOpen: (route) => context.push(route),
            ),
          ),
        ),
        if (page.hasMore) ...[
          const SizedBox(height: AppSpacing.md),
          OutlinedButton.icon(
            onPressed: _loadingMore ? null : _loadMore,
            icon: _loadingMore
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.expand_more_rounded),
            label: Text(l10n.loadMore),
          ),
        ],
      ],
    );
  }
}

String _kindTitle(AppLocalizations l10n, String kind) => switch (kind) {
  'today_schedule' => l10n.dashboardTodaySchedule,
  'today_completed' => l10n.dashboardMetricCompleted,
  'today_remaining' => l10n.dashboardMetricRemaining,
  'overdue' => l10n.dashboardOverdue,
  'active_contracts' => l10n.dashboardMetricActiveContracts,
  'active_trials' => l10n.dashboardMetricActiveTrials,
  'active_rentals' => l10n.dashboardMetricActiveRentals,
  'assets_rented' => l10n.dashboardMetricRentedAssets,
  'assets_trial' => l10n.dashboardMetricTrialAssets,
  'assets_attention' => l10n.dashboardMetricAssetsAttention,
  'collections' => l10n.dashboardMetricCollections,
  'outstanding' => l10n.dashboardMetricOutstanding,
  _ => l10n.dashboard,
};
