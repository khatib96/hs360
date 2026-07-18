import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../auth/presentation/auth_controller.dart';
import '../domain/calendar_permissions.dart';
import 'calendar_controller.dart';
import 'calendar_desktop_layout.dart';
import 'calendar_state.dart';
import 'widgets/calendar_desktop_body.dart';
import 'widgets/calendar_manual_event_dialog.dart';
import 'widgets/calendar_mobile_body.dart';

/// Calendar surface: desktop Month+Agenda (M6) or mobile week+agenda (M9).
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

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

    return AppShell(
      title: l10n.calendarTitle,
      currentRoute: AppRoutes.calendar,
      // Desktop create only in AppBar. Mobile create lives in the non-scrolling
      // clearance slot below (not Scaffold.floatingActionButton), so it cannot
      // paint over the list viewport.
      actions: [
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

          final body = _buildBody(
            context,
            l10n,
            state,
            notifier,
            mobile: mobile,
            narrowDesktop: narrowDesktop,
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
