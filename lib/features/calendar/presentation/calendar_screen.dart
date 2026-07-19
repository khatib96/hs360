import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/calendar_permissions.dart';
import '../domain/calendar_route_scope.dart';
import 'calendar_controller.dart';
import 'calendar_desktop_layout.dart';
import 'calendar_state.dart';
import 'widgets/calendar_desktop_body.dart';
import 'widgets/calendar_manual_event_dialog.dart';
import 'widgets/calendar_mobile_body.dart';
import 'widgets/calendar_route_scope_banner.dart';

/// Calendar surface: desktop Month+Agenda (M6) or mobile week+agenda (M9).
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({
    this.customerIdQueryParam,
    this.contractIdQueryParam,
    this.dateQueryParam,
    super.key,
  });

  /// Deep-link query parameters (Phase 7 M11); see [CalendarRouteScope].
  final String? customerIdQueryParam;
  final String? contractIdQueryParam;
  final String? dateQueryParam;

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  int? _scheduledWeekStart;
  int? _appliedWeekStart;

  /// Latest AppShell body width; drives AppBar create after first layout.
  /// Defaults to mobile-safe until measured.
  double? _contentWidth;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyRouteScope());
  }

  @override
  void didUpdateWidget(CalendarScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customerIdQueryParam != widget.customerIdQueryParam ||
        oldWidget.contractIdQueryParam != widget.contractIdQueryParam ||
        oldWidget.dateQueryParam != widget.dateQueryParam) {
      _applyRouteScope();
    }
  }

  void _applyRouteScope() {
    if (!mounted) return;
    final scope = CalendarRouteScope.fromQueryParameters({
      if (widget.customerIdQueryParam != null)
        'customerId': widget.customerIdQueryParam!,
      if (widget.contractIdQueryParam != null)
        'contractId': widget.contractIdQueryParam!,
      if (widget.dateQueryParam != null) 'date': widget.dateQueryParam!,
    });
    ref.read(calendarControllerProvider.notifier).applyRouteScope(scope);
  }

  void _clearRouteScope() {
    ref.read(calendarControllerProvider.notifier).clearRouteScope();
    context.replace(AppRoutes.calendar);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final index = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    if (_scheduledWeekStart == index && _appliedWeekStart == index) return;
    _scheduledWeekStart = index;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_appliedWeekStart == index) return;
      _appliedWeekStart = index;
      ref.read(calendarControllerProvider.notifier).ensureWeekStart(index);
    });
  }

  Future<void> _createEvent() async {
    final state = ref.read(calendarControllerProvider);
    final form = await showCalendarManualEventDialog(
      context: context,
      scheduledDate: state.selectedDate,
    );
    if (form == null || !mounted) return;
    await ref
        .read(calendarControllerProvider.notifier)
        .createManualEvent(context, form.data);
  }

  void _syncContentWidth(double width) {
    if (_contentWidth == width) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _contentWidth == width) return;
      setState(() => _contentWidth = width);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(calendarControllerProvider);
    final notifier = ref.read(calendarControllerProvider.notifier);
    final session = ref.watch(authControllerProvider).valueOrNull;
    final canCreate = session != null && canCreateCalendarEvent(session);
    final contentMobile = _contentWidth == null
        ? true
        : CalendarLayout.isMobileWidth(_contentWidth!);

    // Strip deep-link query params on identity switch. Do not clear during
    // initial auth resolution (null/loading → first real session).
    ref.listen(authControllerProvider, (previous, next) {
      final previousSession = previous?.valueOrNull;
      final nextSession = next.valueOrNull;
      if (previousSession == null) return;
      final identityChanged =
          nextSession == null ||
          previousSession.userId != nextSession.userId ||
          previousSession.tenantId != nextSession.tenantId ||
          previousSession.tenantUserId != nextSession.tenantUserId;
      if (!identityChanged || !mounted) return;
      try {
        final uri = GoRouterState.of(context).uri;
        final q = uri.queryParameters;
        if (q.containsKey('customerId') ||
            q.containsKey('contractId') ||
            q.containsKey('date')) {
          context.replace(AppRoutes.calendar);
        }
      } on GoError {
        // Harness without a GoRouter (e.g. MaterialApp home) — skip URL strip.
      }
    });

    return AppShell(
      title: l10n.calendarTitle,
      currentRoute: AppRoutes.calendar,
      // Desktop create only in AppBar. Mobile create lives in the non-scrolling
      // clearance slot below (not Scaffold.floatingActionButton), so it cannot
      // paint over the list viewport.
      actions: [
        if (!contentMobile)
          TextButton.icon(
            key: const Key('calendar-open-route-view'),
            onPressed: () => context.push(
              AppRoutes.calendarRoutePath(date: state.selectedDate),
            ),
            icon: const Icon(Icons.map_outlined),
            label: Text(l10n.calendarRouteViewButton),
          ),
        if (canCreate && !state.permissionDenied && !contentMobile)
          TextButton.icon(
            key: const Key('calendar-create-event'),
            onPressed: _createEvent,
            icon: const Icon(Icons.add),
            label: Text(l10n.calendarCreateEvent),
          ),
      ],
      body: LayoutBuilder(
        builder: (context, constraints) {
          final contentWidth = constraints.maxWidth;
          _syncContentWidth(contentWidth);
          final mobile = CalendarLayout.isMobileWidth(contentWidth);
          final narrowDesktop = CalendarLayout.isNarrowDesktopWidth(
            contentWidth,
          );

          final body = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (state.routeScope.showsBanner)
                CalendarRouteScopeBanner(
                  scope: state.routeScope,
                  onClear: _clearRouteScope,
                ),
              Expanded(
                child: _buildBody(
                  context,
                  l10n,
                  state,
                  notifier,
                  mobile: mobile,
                  narrowDesktop: narrowDesktop,
                ),
              ),
            ],
          );

          if (mobile && canCreate && !state.permissionDenied) {
            final clearanceColor = Theme.of(context).scaffoldBackgroundColor;
            return Column(
              key: const Key('calendar-layout-body'),
              children: [
                Expanded(child: ClipRect(child: body)),
                Material(
                  color: clearanceColor,
                  child: SizedBox(
                    key: const Key('calendar-mobile-fab-clearance'),
                    height: CalendarLayout.mobileFabClearance,
                    width: double.infinity,
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(
                          0,
                          8,
                          16,
                          8,
                        ),
                        child: FloatingActionButton(
                          key: const Key('calendar-create-event'),
                          onPressed: _createEvent,
                          tooltip: l10n.calendarCreateEvent,
                          child: const Icon(Icons.add),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          }

          return KeyedSubtree(
            key: const Key('calendar-layout-body'),
            child: body,
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    CalendarState state,
    CalendarController notifier, {
    required bool mobile,
    required bool narrowDesktop,
  }) {
    if (state.permissionDenied) {
      return Center(
        key: const Key('calendar-permission-denied'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.calendarPermissionDenied),
        ),
      );
    }

    if (state.firstDayOfWeekIndex == null ||
        (state.isLoadingSummary &&
            state.isLoadingAgenda &&
            !state.isSummaryQueryAligned &&
            state.agendaEvents.isEmpty)) {
      return Center(
        key: const Key('calendar-loading'),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(l10n.calendarLoading),
          ],
        ),
      );
    }

    if (mobile) {
      return CalendarMobileBody(state: state, notifier: notifier);
    }

    return CalendarDesktopBody(
      state: state,
      notifier: notifier,
      narrow: narrowDesktop,
    );
  }
}
