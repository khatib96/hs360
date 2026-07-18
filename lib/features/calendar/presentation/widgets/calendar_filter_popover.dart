import 'package:flutter/material.dart';

import '../../../auth/domain/app_session.dart';
import '../../domain/calendar_filters.dart';
import 'calendar_filter_form.dart';

/// Compact multi-select filter popover. Closing without Apply discards draft.
Future<CalendarFilters?> showCalendarFilterPopover({
  required BuildContext context,
  required GlobalKey anchorKey,
  required CalendarFilters appliedFacets,
  required DateTime dateFrom,
  required DateTime dateTo,
  required AppSession session,
}) {
  final overlay = Overlay.of(context).context.findRenderObject()! as RenderBox;
  final anchorContext = anchorKey.currentContext;
  if (anchorContext == null) {
    return Future.value(null);
  }
  final anchor = anchorContext.findRenderObject()! as RenderBox;
  final offset = anchor.localToGlobal(Offset.zero, ancestor: overlay);
  final size = anchor.size;
  const panelWidth = 340.0;
  const maxHeight = 440.0;

  var left = offset.dx + size.width - panelWidth;
  left = left.clamp(8.0, overlay.size.width - panelWidth - 8);
  final top = (offset.dy + size.height + 6).clamp(
    8.0,
    overlay.size.height - 120,
  );

  return showGeneralDialog<CalendarFilters>(
    context: context,
    barrierDismissible: true,
    barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
    barrierColor: Colors.black26,
    transitionDuration: const Duration(milliseconds: 120),
    pageBuilder: (dialogContext, animation, secondaryAnimation) {
      return Stack(
        children: [
          Positioned(
            top: top,
            left: left,
            child: FadeTransition(
              opacity: animation,
              child: Material(
                key: const Key('calendar-filter-popover'),
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: panelWidth,
                    minWidth: panelWidth,
                    maxHeight: maxHeight,
                  ),
                  child: CalendarFilterForm(
                    appliedFacets: appliedFacets,
                    dateFrom: dateFrom,
                    dateTo: dateTo,
                    session: session,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// Mobile filter sheet with safe area and keyboard inset handling.
Future<CalendarFilters?> showCalendarFilterSheet({
  required BuildContext context,
  required CalendarFilters appliedFacets,
  required DateTime dateFrom,
  required DateTime dateTo,
  required AppSession session,
}) {
  return showModalBottomSheet<CalendarFilters>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final bottomInset = MediaQuery.viewInsetsOf(sheetContext).bottom;
      final maxHeight = MediaQuery.sizeOf(sheetContext).height * 0.92;
      return Padding(
        padding: EdgeInsets.only(bottom: bottomInset),
        child: SizedBox(
          key: const Key('calendar-filter-sheet'),
          height: maxHeight,
          child: CalendarFilterForm(
            appliedFacets: appliedFacets,
            dateFrom: dateFrom,
            dateTo: dateTo,
            session: session,
            autofocus: false,
          ),
        ),
      );
    },
  );
}
