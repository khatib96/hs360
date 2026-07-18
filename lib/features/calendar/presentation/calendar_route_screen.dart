import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../domain/calendar_date.dart';
import 'calendar_desktop_layout.dart';
import 'calendar_route_controller.dart';
import 'calendar_route_state.dart';
import 'widgets/calendar_route_date_bar.dart';
import 'widgets/calendar_route_employee_picker.dart';
import 'widgets/calendar_route_map_panel.dart';
import 'widgets/calendar_route_point_list.dart';

/// Phase 7 M10 Route View: map + list of a single day's events.
class CalendarRouteScreen extends ConsumerStatefulWidget {
  const CalendarRouteScreen({
    this.dateQueryParam,
    this.mapSurfaceBuilder = defaultCalendarRouteMapSurfaceBuilder,
    super.key,
  });

  final String? dateQueryParam;
  final CalendarRouteMapSurfaceBuilder mapSurfaceBuilder;

  @override
  ConsumerState<CalendarRouteScreen> createState() =>
      _CalendarRouteScreenState();
}

class _CalendarRouteScreenState extends ConsumerState<CalendarRouteScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _applyQueryDate());
  }

  @override
  void didUpdateWidget(CalendarRouteScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.dateQueryParam != widget.dateQueryParam) {
      _applyQueryDate();
    }
  }

  void _applyQueryDate() {
    final raw = widget.dateQueryParam;
    final notifier = ref.read(calendarRouteControllerProvider.notifier);
    if (raw == null || raw.isEmpty) {
      notifier.ensureInitialized();
      return;
    }
    try {
      final parsed = parseCalendarDateOnly(raw);
      notifier.ensureInitialized(date: parsed);
    } on FormatException {
      notifier.reportInvalidDate();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(calendarRouteControllerProvider);
    final notifier = ref.read(calendarRouteControllerProvider.notifier);

    return AppShell(
      title: l10n.calendarRouteTitle,
      currentRoute: AppRoutes.calendar,
      body: _buildBody(context, l10n, state, notifier),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    CalendarRouteState state,
    CalendarRouteController notifier,
  ) {
    if (state.dateInvalid) {
      return Center(
        key: const Key('calendar-route-invalid-date'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.calendarRouteInvalidDate, textAlign: TextAlign.center),
        ),
      );
    }

    if (state.permissionDenied && state.dayErrorCode == null) {
      return Center(
        key: const Key('calendar-route-permission-denied'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(l10n.calendarPermissionDenied),
        ),
      );
    }

    return Column(
      key: const Key('calendar-route-layout-body'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: CalendarRouteDateBar(
            selectedDate: state.selectedDate,
            onSelectDate: notifier.selectDate,
          ),
        ),
        if (state.isTenantWide)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: CalendarRouteEmployeePicker(
              employees: state.employees,
              selectedEmployeeId: state.selectedEmployeeId,
              hasMore: state.employeesHasMore,
              isLoading: state.isLoadingEmployees,
              errorMessage: state.employeesErrorCode == null
                  ? null
                  : l10n.calendarRouteEmployeesLoadFailed,
              onRetry: () => notifier.loadEmployees(search: state.employeeSearch),
              onSearchChanged: (search) =>
                  notifier.loadEmployees(search: search),
              onSelect: notifier.selectEmployee,
            ),
          ),
        if (state.hasMore)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _WarningBanner(text: l10n.calendarRouteTruncatedWarning),
          ),
        if (state.dayErrorCode != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _ErrorRetryBanner(
              keyName: 'calendar-route-day-error',
              text: l10n.calendarRouteDayLoadFailed,
              retryLabel: l10n.calendarRouteRetry,
              onRetry: notifier.refresh,
            ),
          ),
        Expanded(child: _buildContent(context, l10n, state, notifier)),
      ],
    );
  }

  Widget _buildContent(
    BuildContext context,
    AppLocalizations l10n,
    CalendarRouteState state,
    CalendarRouteController notifier,
  ) {
    if (state.awaitingEmployeeSelection) {
      return Center(
        key: const Key('calendar-route-select-employee-prompt'),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            l10n.calendarRouteSelectEmployeePrompt,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (state.isLoadingDay && !state.hasLoadedDayOnce) {
      return const Center(
        key: Key('calendar-route-loading'),
        child: CircularProgressIndicator(),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final mapStack = Stack(
          key: const Key('calendar-route-map'),
          fit: StackFit.expand,
          children: [
            widget.mapSurfaceBuilder(
              points: state.points,
              selectedEventId: state.selectedEventId,
              onSelectEvent: notifier.selectPoint,
              onTileFailure: notifier.reportTileFailure,
              tileSessionId: state.tileSessionId,
            ),
            if (state.mapSurfaceState ==
                CalendarRouteMapSurfaceState.tileFailure)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: CalendarRouteTileFailureBanner(
                  message: l10n.calendarRouteMapTilesUnavailable,
                  retryLabel: l10n.calendarRouteRetry,
                  onRetry: notifier.retryTiles,
                ),
              ),
          ],
        );
        final list = CalendarRoutePointList(
          points: state.points,
          selectedEventId: state.selectedEventId,
          onSelectEvent: notifier.selectEvent,
          onEventChanged: notifier.refresh,
        );

        if (CalendarLayout.isMobileWidth(constraints.maxWidth)) {
          return Column(
            children: [
              SizedBox(height: 260, child: mapStack),
              Expanded(child: list),
            ],
          );
        }

        return Row(
          children: [
            Expanded(flex: 3, child: mapStack),
            const VerticalDivider(width: 1),
            Expanded(flex: 2, child: list),
          ],
        );
      },
    );
  }
}

class _WarningBanner extends StatelessWidget {
  const _WarningBanner({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text, style: TextStyle(color: scheme.onErrorContainer)),
    );
  }
}

class _ErrorRetryBanner extends StatelessWidget {
  const _ErrorRetryBanner({
    required this.keyName,
    required this.text,
    required this.retryLabel,
    required this.onRetry,
  });

  final String keyName;
  final String text;
  final String retryLabel;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: Key(keyName),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.errorContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(text, style: TextStyle(color: scheme.onErrorContainer)),
          ),
          TextButton(
            key: Key('$keyName-retry'),
            onPressed: onRetry,
            child: Text(retryLabel),
          ),
        ],
      ),
    );
  }
}
