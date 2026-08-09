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
import '../../../shared/widgets/app_table_frame.dart';
import '../../auth/domain/app_session.dart';
import '../../auth/presentation/auth_controller.dart';
import '../data/dashboard_repository.dart';
import '../domain/activity_feed.dart';
import 'activity_feed_list.dart';

class DailyActivityScreen extends ConsumerStatefulWidget {
  const DailyActivityScreen({this.dateQueryParam, super.key});

  final String? dateQueryParam;

  @override
  ConsumerState<DailyActivityScreen> createState() =>
      _DailyActivityScreenState();
}

class _DailyActivityScreenState extends ConsumerState<DailyActivityScreen> {
  ActivityFeedPage? _page;
  DateTime? _selectedDate;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  int _requestSerial = 0;

  @override
  void initState() {
    super.initState();
    _selectedDate = _parseDate(widget.dateQueryParam);
    ref.listenManual(authControllerProvider, (previous, next) {
      final before = previous?.valueOrNull;
      final after = next.valueOrNull;
      if (after != null && _identityChanged(before, after)) _refresh();
    });
    Future.microtask(_refresh);
  }

  @override
  void didUpdateWidget(covariant DailyActivityScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dateQueryParam != widget.dateQueryParam) {
      _selectedDate = _parseDate(widget.dateQueryParam);
      _refresh();
    }
  }

  bool _identityChanged(AppSession? before, AppSession after) {
    return before == null ||
        before.userId != after.userId ||
        before.tenantId != after.tenantId ||
        before.permissions != after.permissions;
  }

  Future<void> _refresh({DateTime? date, bool serverToday = false}) async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return;
    final serial = ++_requestSerial;
    final requested = serverToday ? null : (date ?? _selectedDate);
    setState(() {
      _loading = true;
      _loadingMore = false;
      _error = null;
      if (date != null) _selectedDate = date;
    });
    try {
      final page = await ref
          .read(dashboardRepositoryProvider)
          .listDailyActivity(session, businessDate: requested);
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _page = page;
        _selectedDate = page.businessDate;
        _loading = false;
      });
      _replaceDateInUrl(page.businessDate);
    } on DashboardException catch (error) {
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _loading = false;
        _error = error.code;
      });
    } catch (_) {
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _loading = false;
        _error = DashboardException.unavailable;
      });
    }
  }

  Future<void> _loadMore() async {
    final session = ref.read(authControllerProvider).valueOrNull;
    final current = _page;
    if (session == null ||
        current == null ||
        !current.hasMore ||
        _loadingMore) {
      return;
    }
    final serial = _requestSerial;
    setState(() => _loadingMore = true);
    try {
      final next = await ref
          .read(dashboardRepositoryProvider)
          .listDailyActivity(
            session,
            businessDate: current.businessDate,
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
        );
        _loadingMore = false;
      });
    } catch (_) {
      if (mounted && serial == _requestSerial) {
        setState(() => _loadingMore = false);
      }
    }
  }

  void _replaceDateInUrl(DateTime date) {
    final target = AppRoutes.dailyActivityPath(date: date);
    try {
      if (GoRouterState.of(context).uri.toString() != target) {
        context.replace(target);
      }
    } on GoError {
      // Widget tests may not install a GoRouter.
    }
  }

  Future<void> _pickDate() async {
    final initial = _selectedDate ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) _refresh(date: picked);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final date = _selectedDate;
    return AppShell(
      title: l10n.dailyActivityTitle,
      currentRoute: AppRoutes.dailyActivity,
      moduleActions: [
        IconButton(
          key: const Key('daily-activity-refresh'),
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
                  title: l10n.dailyActivityTitle,
                  subtitle: l10n.dailyActivitySubtitle,
                  eyebrow: date == null
                      ? null
                      : DateFormat.yMMMMEEEEd(
                          Localizations.localeOf(context).toLanguageTag(),
                        ).format(date),
                ),
                const SizedBox(height: AppSpacing.md),
                _DateToolbar(
                  date: date,
                  onPrevious: date == null
                      ? null
                      : () => _refresh(
                          date: date.subtract(const Duration(days: 1)),
                        ),
                  onNext: date == null
                      ? null
                      : () => _refresh(date: date.add(const Duration(days: 1))),
                  onToday: () => _refresh(serverToday: true),
                  onPick: _pickDate,
                ),
                if (_page?.timezoneName.isNotEmpty == true) ...[
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    l10n.dailyActivityTimezone(_page!.timezoneName),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
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
        message: l10n.dailyActivityLoadError,
        action: FilledButton(onPressed: _refresh, child: Text(l10n.retry)),
      );
    }
    final page = _page;
    if (page == null || page.items.isEmpty) {
      return AppStateView.empty(
        message: l10n.dailyActivityEmpty,
        icon: Icons.history_toggle_off_rounded,
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
            key: const Key('daily-activity-load-more'),
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

class _DateToolbar extends StatelessWidget {
  const _DateToolbar({
    required this.date,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onPick,
  });

  final DateTime? date;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback onToday;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      spacing: AppSpacing.xs,
      runSpacing: AppSpacing.xs,
      children: [
        IconButton.outlined(
          key: const Key('daily-activity-previous'),
          tooltip: l10n.dailyActivityPreviousDay,
          onPressed: onPrevious,
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        OutlinedButton.icon(
          key: const Key('daily-activity-date-picker'),
          onPressed: onPick,
          icon: const Icon(Icons.calendar_month_outlined),
          label: Text(
            date == null
                ? l10n.dailyActivitySelectDate
                : DateFormat.yMMMd(
                    Localizations.localeOf(context).toLanguageTag(),
                  ).format(date!),
          ),
        ),
        IconButton.outlined(
          key: const Key('daily-activity-next'),
          tooltip: l10n.dailyActivityNextDay,
          onPressed: onNext,
          icon: const Icon(Icons.chevron_right_rounded),
        ),
        TextButton(onPressed: onToday, child: Text(l10n.dailyActivityToday)),
      ],
    );
  }
}

DateTime? _parseDate(String? raw) {
  final parsed = DateTime.tryParse(raw ?? '');
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}
