import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../domain/calendar_route_employee.dart';

/// Tenant-wide Route View employee search/select (M10).
///
/// Assigned-only sessions never see this widget — the server resolves the
/// caller's own employee row for `get_calendar_route_day`.
class CalendarRouteEmployeePicker extends StatefulWidget {
  const CalendarRouteEmployeePicker({
    required this.employees,
    required this.selectedEmployeeId,
    required this.hasMore,
    required this.isLoading,
    required this.onSearchChanged,
    required this.onSelect,
    this.errorMessage,
    this.onRetry,
    super.key,
  });

  final List<CalendarRouteEmployee> employees;
  final String? selectedEmployeeId;
  final bool hasMore;
  final bool isLoading;
  final ValueChanged<String> onSearchChanged;
  final ValueChanged<String> onSelect;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  State<CalendarRouteEmployeePicker> createState() =>
      _CalendarRouteEmployeePickerState();
}

class _CalendarRouteEmployeePickerState
    extends State<CalendarRouteEmployeePicker> {
  static const _debounce = Duration(milliseconds: 350);

  final _controller = TextEditingController();
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _scheduleSearch(String value) {
    _timer?.cancel();
    _timer = Timer(_debounce, () {
      if (!mounted) return;
      widget.onSearchChanged(value.trim());
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    return Column(
      key: const Key('calendar-route-employee-picker'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const Key('calendar-route-employee-search'),
          controller: _controller,
          decoration: InputDecoration(
            labelText: l10n.calendarRouteSelectEmployee,
            hintText: l10n.calendarRouteEmployeeSearchHint,
            prefixIcon: const Icon(Icons.search),
            isDense: true,
          ),
          onChanged: _scheduleSearch,
        ),
        const SizedBox(height: 8),
        if (widget.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              key: const Key('calendar-route-employees-error'),
              children: [
                Expanded(
                  child: Text(
                    widget.errorMessage!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
                if (widget.onRetry != null)
                  TextButton(
                    key: const Key('calendar-route-employees-retry'),
                    onPressed: widget.onRetry,
                    child: Text(l10n.calendarRouteRetry),
                  ),
              ],
            ),
          ),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 220),
          child: widget.isLoading && widget.employees.isEmpty
              ? const Center(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: CircularProgressIndicator(),
                  ),
                )
              : ListView.builder(
                  key: const Key('calendar-route-employee-list'),
                  shrinkWrap: true,
                  itemCount: widget.employees.length,
                  itemBuilder: (context, index) {
                    final employee = widget.employees[index];
                    final name = locale == 'ar'
                        ? employee.nameAr
                        : (employee.nameEn ?? employee.nameAr);
                    final selected =
                        employee.employeeId == widget.selectedEmployeeId;
                    return ListTile(
                      key: Key('calendar-route-employee-${employee.employeeId}'),
                      dense: true,
                      selected: selected,
                      leading: Icon(
                        selected
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked,
                      ),
                      title: Text(name),
                      onTap: () => widget.onSelect(employee.employeeId),
                    );
                  },
                ),
        ),
        if (widget.hasMore)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.calendarRouteEmployeesTruncated,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
      ],
    );
  }
}
