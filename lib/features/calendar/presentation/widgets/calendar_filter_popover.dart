import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/calendar_enums.dart';
import '../../domain/calendar_filter_validator.dart';
import '../../domain/calendar_filters.dart';
import '../calendar_labels.dart';
import '../calendar_lookup_helpers.dart';
import '../../../auth/domain/app_session.dart';

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
                  child: _CalendarFilterPopoverBody(
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

class _CalendarFilterPopoverBody extends StatefulWidget {
  const _CalendarFilterPopoverBody({
    required this.appliedFacets,
    required this.dateFrom,
    required this.dateTo,
    required this.session,
  });

  final CalendarFilters appliedFacets;
  final DateTime dateFrom;
  final DateTime dateTo;
  final AppSession session;

  @override
  State<_CalendarFilterPopoverBody> createState() =>
      _CalendarFilterPopoverBodyState();
}

class _CalendarFilterPopoverBodyState
    extends State<_CalendarFilterPopoverBody> {
  late CalendarFilters _draft;
  List<String> _codes = const [];

  @override
  void initState() {
    super.initState();
    _draft = widget.appliedFacets.withoutExactIdFilters();
  }

  bool get _tenantWide => calendarShowsTenantWideFilters(widget.session);

  void _reset() {
    setState(() {
      _draft = CalendarFilters.empty;
      _codes = const [];
    });
  }

  void _apply() {
    final candidate = _draft.withoutExactIdFilters();
    final result = CalendarFilterValidator.validate(
      dateFrom: widget.dateFrom,
      dateTo: widget.dateTo,
      filters: candidate,
      pageLimit: CalendarFilters.defaultPageLimit,
      session: widget.session,
    );
    if (!result.isValid) {
      setState(() => _codes = result.codes);
      return;
    }
    Navigator.of(context).pop(candidate);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Shortcuts(
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.escape): DismissIntent(),
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
      },
      child: Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              Navigator.of(context).pop();
              return null;
            },
          ),
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              _apply();
              return null;
            },
          ),
        },
        child: Focus(
          autofocus: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Text(
                  l10n.calendarFilterOpenFilters,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    _sectionTitle(l10n.calendarFilterTypes),
                    for (final type in CalendarEventType.values)
                      CheckboxListTile(
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(calendarEventTypeLabel(l10n, type)),
                        value: _draft.eventTypes?.contains(type) ?? false,
                        onChanged: (selected) {
                          final current = [...?_draft.eventTypes];
                          if (selected == true) {
                            current.add(type);
                          } else {
                            current.remove(type);
                          }
                          setState(() {
                            _draft = _draft.copyWith(
                              eventTypes: current,
                              clearEventTypes: current.isEmpty,
                            );
                            _codes = const [];
                          });
                        },
                      ),
                    _sectionTitle(l10n.calendarFilterStatuses),
                    for (final status in CalendarEventStatus.values)
                      CheckboxListTile(
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(calendarEventStatusLabel(l10n, status)),
                        value: _draft.statuses?.contains(status) ?? false,
                        onChanged: (selected) {
                          final current = [...?_draft.statuses];
                          if (selected == true) {
                            current.add(status);
                          } else {
                            current.remove(status);
                          }
                          setState(() {
                            _draft = _draft.copyWith(
                              statuses: current,
                              clearStatuses: current.isEmpty,
                            );
                            _codes = const [];
                          });
                        },
                      ),
                    _sectionTitle(l10n.calendarFilterSourceKind),
                    for (final kind in CalendarEventSourceKind.values)
                      CheckboxListTile(
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(calendarSourceKindLabel(l10n, kind)),
                        value: _draft.sourceKind == kind,
                        onChanged: (selected) {
                          setState(() {
                            if (selected == true) {
                              _draft = _draft.copyWith(sourceKind: kind);
                            } else if (_draft.sourceKind == kind) {
                              _draft = _draft.copyWith(clearSourceKind: true);
                            }
                            _codes = const [];
                          });
                        },
                      ),
                    CheckboxListTile(
                      key: const Key('calendar-filter-overdue'),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(l10n.calendarFilterOverdueOnly),
                      value: _draft.overdueOnly,
                      onChanged: (v) {
                        setState(() {
                          _draft = _draft.copyWith(overdueOnly: v ?? false);
                          _codes = const [];
                        });
                      },
                    ),
                    CheckboxListTile(
                      key: const Key('calendar-filter-working-conflict'),
                      dense: true,
                      controlAffinity: ListTileControlAffinity.leading,
                      title: Text(l10n.calendarFilterWorkingDayConflict),
                      value: _draft.workingDayConflict,
                      onChanged: (v) {
                        setState(() {
                          _draft = _draft.copyWith(
                            workingDayConflict: v ?? false,
                          );
                          _codes = const [];
                        });
                      },
                    ),
                    if (_tenantWide)
                      CheckboxListTile(
                        key: const Key('calendar-filter-unassigned'),
                        dense: true,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(l10n.calendarFilterUnassigned),
                        value: _draft.unassignedOnly,
                        onChanged: (v) {
                          setState(() {
                            _draft = _draft.copyWith(
                              unassignedOnly: v ?? false,
                            );
                            _codes = const [];
                          });
                        },
                      ),
                    if (_codes.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          _codes.map((c) => _msg(l10n, c)).join('\n'),
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    TextButton(
                      key: const Key('calendar-filter-reset'),
                      onPressed: _reset,
                      child: Text(l10n.calendarFilterReset),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton(
                        key: const Key('calendar-filter-apply'),
                        onPressed: _apply,
                        child: Text(
                          l10n.calendarFilterApply,
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: Text(title, style: Theme.of(context).textTheme.labelLarge),
    );
  }

  String _msg(AppLocalizations l10n, String code) {
    return switch (code) {
      CalendarFilterValidator.overdueRequiresPending =>
        l10n.calendarValidationOverdueRequiresPending,
      CalendarFilterValidator.assignedOnlyUnassignedForbidden =>
        l10n.calendarValidationAssignedOnlyUnassigned,
      _ => l10n.calendarErrorValidation,
    };
  }
}
