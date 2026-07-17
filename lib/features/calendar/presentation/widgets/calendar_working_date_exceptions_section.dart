import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../shared/widgets/message_banner.dart';
import '../../domain/calendar_working_date_exception.dart';
import '../calendar_labels.dart';
import '../calendar_working_date_exceptions_controller.dart';
import '../calendar_working_date_exceptions_state.dart';
import 'calendar_working_date_exception_cancel_dialog.dart';
import 'calendar_working_date_exception_dialog.dart';
import 'calendar_working_date_exception_list_tile.dart';

/// Settings-screen card: holiday/company-closure/exceptional-working-day
/// list with a status filter and add/edit/cancel actions.
class CalendarWorkingDateExceptionsSection extends ConsumerWidget {
  const CalendarWorkingDateExceptionsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(calendarWorkingDateExceptionsControllerProvider);
    final notifier = ref.read(
      calendarWorkingDateExceptionsControllerProvider.notifier,
    );

    if (state.permissionDenied) {
      return MessageBanner(
        variant: MessageBannerVariant.info,
        message: l10n.calendarWorkingDateExceptionsPermissionDenied,
      );
    }

    return Card(
      key: const Key('calendar-wde-section'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.calendarWorkingDateExceptionsSectionTitle,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (state.canEdit)
                  FilledButton.icon(
                    key: const Key('calendar-wde-add'),
                    onPressed: () => _openCreateDialog(context),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.calendarWorkingDateExceptionsAdd),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _YearFilterRow(
              value: state.selectedYear,
              onChanged: notifier.setYear,
            ),
            const SizedBox(height: 12),
            _StatusFilterRow(
              value: state.statusFilter,
              onChanged: notifier.setStatusFilter,
            ),
            const SizedBox(height: 12),
            if (state.mutationErrorCode != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: MessageBanner(
                  key: const Key('calendar-wde-mutation-error-banner'),
                  variant: MessageBannerVariant.error,
                  message: calendarErrorMessage(l10n, state.mutationErrorCode!),
                ),
              ),
            _buildBody(context, l10n, state, notifier),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    CalendarWorkingDateExceptionsState state,
    CalendarWorkingDateExceptionsController notifier,
  ) {
    if (state.isLoading && state.items.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (state.errorCode != null && state.items.isEmpty) {
      return Column(
        children: [
          MessageBanner(
            variant: MessageBannerVariant.error,
            message: calendarErrorMessage(l10n, state.errorCode!),
          ),
          const SizedBox(height: 8),
          TextButton(
            key: const Key('calendar-wde-retry'),
            onPressed: notifier.retry,
            child: Text(l10n.retry),
          ),
        ],
      );
    }

    if (state.isEmpty) {
      return Padding(
        key: const Key('calendar-wde-empty'),
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Center(child: Text(l10n.calendarWorkingDateExceptionsEmpty)),
      );
    }

    return Column(
      key: const Key('calendar-wde-list'),
      children: [
        for (final item in state.items)
          CalendarWorkingDateExceptionListTile(
            exception: item,
            canEdit: state.canEdit,
            onEdit: () => _openEditDialog(context, item),
            onCancel: () => _openCancelDialog(context, item),
          ),
        if (state.loadMoreErrorCode != null) ...[
          const SizedBox(height: 8),
          MessageBanner(
            key: const Key('calendar-wde-load-more-error'),
            variant: MessageBannerVariant.error,
            message: calendarErrorMessage(l10n, state.loadMoreErrorCode!),
          ),
          TextButton(
            key: const Key('calendar-wde-load-more-retry'),
            onPressed: state.isLoadingMore ? null : notifier.loadMore,
            child: Text(l10n.retry),
          ),
        ],
        if (state.hasMore)
          TextButton(
            key: const Key('calendar-wde-load-more'),
            onPressed: state.isLoadingMore ? null : notifier.loadMore,
            child: Text(l10n.calendarLoadMore),
          ),
      ],
    );
  }

  Future<void> _openCreateDialog(BuildContext context) async {
    await showCalendarWorkingDateExceptionDialog(context: context);
  }

  Future<void> _openEditDialog(
    BuildContext context,
    WorkingDateException existing,
  ) async {
    await showCalendarWorkingDateExceptionDialog(
      context: context,
      existing: existing,
    );
  }

  Future<void> _openCancelDialog(
    BuildContext context,
    WorkingDateException existing,
  ) async {
    await showCalendarWorkingDateExceptionCancelDialog(
      context: context,
      exception: existing,
    );
  }
}

class _YearFilterRow extends StatelessWidget {
  const _YearFilterRow({required this.value, required this.onChanged});

  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final years = [for (var year = value - 5; year <= value + 5; year++) year];
    return Row(
      children: [
        Text(
          l10n.calendarSelectYear,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        const SizedBox(width: 12),
        DropdownButton<int>(
          key: const Key('calendar-wde-year-filter'),
          value: value,
          items: years
              .map(
                (year) => DropdownMenuItem(value: year, child: Text('$year')),
              )
              .toList(),
          onChanged: (year) {
            if (year != null) onChanged(year);
          },
        ),
      ],
    );
  }
}

class _StatusFilterRow extends StatelessWidget {
  const _StatusFilterRow({required this.value, required this.onChanged});

  final CalendarWorkingDateExceptionStatusFilter value;
  final ValueChanged<CalendarWorkingDateExceptionStatusFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 12,
      runSpacing: 8,
      children: [
        Text(
          l10n.calendarWorkingDateExceptionsFilterStatusLabel,
          style: Theme.of(context).textTheme.labelLarge,
        ),
        SegmentedButton<CalendarWorkingDateExceptionStatusFilter>(
          key: const Key('calendar-wde-status-filter'),
          segments: CalendarWorkingDateExceptionStatusFilter.values
              .map(
                (filter) => ButtonSegment(
                  value: filter,
                  label: Text(
                    calendarWorkingDateExceptionStatusFilterLabel(l10n, filter),
                  ),
                ),
              )
              .toList(),
          selected: {value},
          onSelectionChanged: (selection) => onChanged(selection.first),
        ),
      ],
    );
  }
}
