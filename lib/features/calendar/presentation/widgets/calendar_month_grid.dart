import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/calendar_date.dart';
import '../../domain/calendar_month_grid.dart';
import '../../domain/calendar_range_summary.dart';
import '../calendar_labels.dart';
import 'calendar_month_day_cell.dart';

class CalendarMonthGrid extends StatefulWidget {
  const CalendarMonthGrid({
    required this.focusedMonth,
    required this.firstDayOfWeekIndex,
    required this.dateFrom,
    required this.dateTo,
    required this.selectedDate,
    required this.tenantLocalToday,
    required this.daysByDate,
    required this.isAligned,
    required this.isLoading,
    required this.onSelectDate,
    super.key,
  });

  final DateTime focusedMonth;
  final int firstDayOfWeekIndex;
  final DateTime dateFrom;
  final DateTime dateTo;
  final DateTime selectedDate;
  final DateTime? tenantLocalToday;
  final Map<DateTime, CalendarDaySummary> daysByDate;
  final bool isAligned;
  final bool isLoading;
  final ValueChanged<DateTime> onSelectDate;

  @override
  State<CalendarMonthGrid> createState() => _CalendarMonthGridState();
}

class _CalendarMonthGridState extends State<CalendarMonthGrid> {
  late DateTime _focusedDate;
  final FocusNode _gridFocus = FocusNode(debugLabel: 'calendar-month-grid');

  @override
  void initState() {
    super.initState();
    _focusedDate = calendarDateOnly(widget.selectedDate);
    _gridFocus.addListener(() {
      if (mounted) setState(() {});
    });
  }

  @override
  void didUpdateWidget(covariant CalendarMonthGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedDate != oldWidget.selectedDate) {
      _focusedDate = calendarDateOnly(widget.selectedDate);
    }
    if (widget.dateFrom != oldWidget.dateFrom ||
        widget.dateTo != oldWidget.dateTo) {
      if (_focusedDate.isBefore(widget.dateFrom) ||
          _focusedDate.isAfter(widget.dateTo)) {
        _focusedDate = calendarDateOnly(widget.selectedDate);
      }
    }
  }

  @override
  void dispose() {
    _gridFocus.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    final horizontal = rtl ? -1 : 1;

    if (key == LogicalKeyboardKey.arrowLeft) {
      _moveFocus(-horizontal);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowRight) {
      _moveFocus(horizontal);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowUp) {
      _moveFocus(-7);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.arrowDown) {
      _moveFocus(7);
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.space) {
      widget.onSelectDate(_focusedDate);
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _moveFocus(int deltaDays) {
    final next = addCalendarDays(_focusedDate, deltaDays);
    if (next.isBefore(calendarDateOnly(widget.dateFrom)) ||
        next.isAfter(calendarDateOnly(widget.dateTo))) {
      return;
    }
    setState(() => _focusedDate = next);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (!widget.isAligned) {
      return SizedBox(
        height: 280,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isLoading) const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(l10n.calendarMonthSkeleton),
            ],
          ),
        ),
      );
    }

    final cells = buildCalendarGridCells(
      focusedMonth: widget.focusedMonth,
      dateFrom: widget.dateFrom,
      dateTo: widget.dateTo,
    );
    final headers = List.generate(7, (i) {
      final index = (widget.firstDayOfWeekIndex + i) % 7;
      return calendarWeekdayShort(l10n, index);
    });

    return Focus(
      focusNode: _gridFocus,
      onKeyEvent: _onKey,
      child: Semantics(
        container: true,
        label: l10n.calendarTitle,
        child: Column(
          children: [
            Row(
              children: [
                for (final label in headers)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        label,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ),
              ],
            ),
            for (var row = 0; row < cells.length / 7; row++)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var col = 0; col < 7; col++)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 2),
                          child: _buildCell(
                            context,
                            l10n,
                            cells[row * 7 + col],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCell(
    BuildContext context,
    AppLocalizations l10n,
    CalendarGridCell cell,
  ) {
    final date = calendarDateOnly(cell.date);
    final summary = widget.daysByDate[date];
    final isToday =
        widget.tenantLocalToday != null && date == widget.tenantLocalToday;
    final isSelected = date == widget.selectedDate;
    final isFocused = date == _focusedDate && _gridFocus.hasFocus;
    final isDayOff = summary?.workingDay.isDayOff ?? false;
    final eventCount = summary?.eventCount ?? 0;
    final hasConflict = isDayOff && eventCount > 0;
    final overdue = summary?.overdueCount ?? 0;
    final unassigned = summary?.unassignedCount;
    final dateException = summary?.workingDay.dateException;

    String? eventLabel;
    if (eventCount > 0) {
      final capped = CalendarCappedCount.fromRaw(eventCount);
      eventLabel = calendarFormatCappedCount(l10n, capped);
    }
    String? overdueLabel;
    if (overdue > 0) {
      final capped = CalendarCappedCount.fromRaw(overdue);
      overdueLabel = calendarFormatCappedCount(l10n, capped);
    }
    String? unassignedLabel;
    if (unassigned != null && unassigned > 0) {
      final capped = CalendarCappedCount.fromRaw(unassigned);
      unassignedLabel = calendarFormatCappedCount(l10n, capped);
    }

    final semanticsParts = <String>[
      calendarLocalizedDate(l10n, date),
      if (isSelected) l10n.calendarSemanticsSelected,
      if (isToday) l10n.calendarSemanticsToday,
      if (dateException != null)
        l10n.calendarMonthExceptionMarkerSemantics(
          calendarDateExceptionKindTitleText(
            l10n,
            kind: dateException.kind,
            title: dateException.titleFallback(l10n.localeName),
          ),
        )
      else if (isDayOff)
        l10n.calendarSemanticsDayOff,
      if (hasConflict) l10n.calendarSemanticsConflict,
      if (eventCount > 0) l10n.calendarDayEventCount(eventCount),
      if (overdue > 0) l10n.calendarDayOverdueCount(overdue),
      if (unassigned != null && unassigned > 0)
        l10n.calendarDayUnassignedCount(unassigned),
    ];

    return CalendarMonthDayCell(
      date: date,
      isOutsideMonth: cell.isOutsideMonth,
      isToday: isToday,
      isSelected: isSelected,
      isKeyboardFocused: isFocused,
      isDayOff: isDayOff,
      hasConflict: hasConflict,
      dateExceptionKind: dateException?.kind,
      eventCountLabel: eventLabel,
      overdueCountLabel: overdueLabel,
      unassignedCountLabel: unassignedLabel,
      semanticsLabel: semanticsParts.join(', '),
      onTap: () {
        setState(() => _focusedDate = date);
        _gridFocus.requestFocus();
        widget.onSelectDate(date);
      },
    );
  }
}
