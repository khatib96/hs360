import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_lucide/flutter_lucide.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../domain/calendar_enums.dart';
import '../../domain/calendar_filters.dart';
import 'calendar_filter_popover.dart';

/// Compact search + funnel-filter toolbar for desktop calendar.
class CalendarFilterBar extends ConsumerStatefulWidget {
  const CalendarFilterBar({
    required this.applied,
    required this.scope,
    required this.dateFrom,
    required this.dateTo,
    required this.onApply,
    required this.onClear,
    this.collapsed = false,
    this.useSheet = false,
    super.key,
  });

  final CalendarFilters applied;
  final CalendarReadScope? scope;
  final DateTime dateFrom;
  final DateTime dateTo;
  final ValueChanged<CalendarFilters> onApply;
  final VoidCallback onClear;

  /// Unused; kept for call-site compatibility. Toolbar is always compact.
  final bool collapsed;

  /// When true, opens filters in a bottom sheet instead of a popover.
  final bool useSheet;

  @override
  ConsumerState<CalendarFilterBar> createState() => _CalendarFilterBarState();
}

class _CalendarFilterBarState extends ConsumerState<CalendarFilterBar> {
  static const _debounce = Duration(milliseconds: 450);

  final _searchController = TextEditingController();
  final _filterButtonKey = GlobalKey();
  Timer? _debounceTimer;
  int _searchGeneration = 0;
  String? _sessionIdentity;

  @override
  void initState() {
    super.initState();
    _searchController.text = widget.applied.search ?? '';
  }

  @override
  void didUpdateWidget(covariant CalendarFilterBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    final appliedSearch = widget.applied.search ?? '';
    if (widget.applied != oldWidget.applied &&
        _searchController.text != appliedSearch) {
      _searchController.text = appliedSearch;
    }
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _cancelDebounce() {
    _debounceTimer?.cancel();
    _searchGeneration++;
  }

  void _resetIdentity() {
    _cancelDebounce();
    _searchController.clear();
  }

  CalendarFilters _mergeSearch(String raw) {
    final trimmed = raw.trim();
    return widget.applied.withoutExactIdFilters().copyWith(
      search: trimmed.isEmpty ? null : trimmed,
      clearSearch: trimmed.isEmpty,
    );
  }

  CalendarFilters _withSearchPreserved(CalendarFilters facets) {
    final search = _searchController.text.trim();
    return facets.withoutExactIdFilters().copyWith(
      search: search.isEmpty ? null : search,
      clearSearch: search.isEmpty,
    );
  }

  void _applySearchNow() {
    _cancelDebounce();
    final text = _searchController.text.trim();
    if (text.isNotEmpty && text.length < 2) return;
    final next = _mergeSearch(_searchController.text);
    if (next == widget.applied.withoutExactIdFilters()) return;
    widget.onApply(next);
  }

  void _scheduleSearch(String value) {
    _debounceTimer?.cancel();
    final gen = ++_searchGeneration;
    final identity = _sessionIdentity;
    _debounceTimer = Timer(_debounce, () {
      if (!mounted) return;
      if (gen != _searchGeneration) return;
      if (identity != _sessionIdentity) return;
      final text = value.trim();
      if (text.isNotEmpty && text.length < 2) return;
      final next = _mergeSearch(value);
      if (next == widget.applied.withoutExactIdFilters()) return;
      widget.onApply(next);
    });
  }

  Future<void> _openFilters() async {
    final session = ref.read(authControllerProvider).valueOrNull;
    if (session == null) return;
    final facets = widget.applied.popoverFacetFilters;
    final result = widget.useSheet
        ? await showCalendarFilterSheet(
            context: context,
            appliedFacets: facets,
            dateFrom: widget.dateFrom,
            dateTo: widget.dateTo,
            session: session,
          )
        : await showCalendarFilterPopover(
            context: context,
            anchorKey: _filterButtonKey,
            appliedFacets: facets,
            dateFrom: widget.dateFrom,
            dateTo: widget.dateTo,
            session: session,
          );
    if (!mounted || result == null) return;
    widget.onApply(_withSearchPreserved(result));
  }

  void _clearAll() {
    _cancelDebounce();
    _searchController.clear();
    widget.onClear();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final session = ref.watch(authControllerProvider).valueOrNull;
    final sessionKey =
        '${session?.tenantId}|${session?.userId}|'
        '${session?.permissions.permissions}';
    if (_sessionIdentity != null && _sessionIdentity != sessionKey) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _resetIdentity();
        setState(() {});
      });
    }
    _sessionIdentity = sessionKey;

    final badgeCount = widget.applied.activePopoverGroupCount;
    final hasAnything =
        widget.applied != CalendarFilters.empty ||
        _searchController.text.trim().isNotEmpty;

    return Semantics(
      container: true,
      label: l10n.calendarFilterOpenFilters,
      child: Wrap(
        key: const Key('calendar-filter-toolbar'),
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          SizedBox(
            width: MediaQuery.sizeOf(context).width < 400
                ? MediaQuery.sizeOf(context).width - 32
                : null,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minWidth: 160, maxWidth: 480),
              child: TextField(
                key: const Key('calendar-filter-search'),
                controller: _searchController,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: l10n.calendarFilterSearchHint,
                  isDense: true,
                  prefixIcon: const Icon(LucideIcons.search, size: 18),
                  border: const OutlineInputBorder(),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
                onChanged: _scheduleSearch,
                onSubmitted: (_) => _applySearchNow(),
              ),
            ),
          ),
          Badge(
            isLabelVisible: badgeCount > 0,
            label: Text('$badgeCount'),
            backgroundColor: AppColors.gold,
            child: IconButton(
              key: _filterButtonKey,
              tooltip: l10n.calendarFilterOpenFilters,
              onPressed: _openFilters,
              icon: Icon(
                LucideIcons.list_filter,
                key: const Key('calendar-filter-funnel'),
              ),
            ),
          ),
          TextButton(
            key: const Key('calendar-filter-clear'),
            onPressed: hasAnything ? _clearAll : null,
            child: Text(l10n.calendarFilterClear),
          ),
        ],
      ),
    );
  }
}
