import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../core/errors/finance_exception.dart';
import '../../../core/routing/app_routes.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/message_banner.dart';
import '../domain/calendar_settings.dart';
import 'calendar_settings_controller.dart';
import 'calendar_settings_state.dart';
import 'widgets/calendar_setup_banner.dart';
import 'widgets/calendar_working_date_exceptions_section.dart';
import 'widgets/calendar_working_day_editor.dart';

class CalendarSettingsScreen extends ConsumerStatefulWidget {
  const CalendarSettingsScreen({super.key});

  @override
  ConsumerState<CalendarSettingsScreen> createState() =>
      _CalendarSettingsScreenState();
}

class _CalendarSettingsScreenState
    extends ConsumerState<CalendarSettingsScreen> {
  late final TextEditingController _timezoneController;

  @override
  void initState() {
    super.initState();
    _timezoneController = TextEditingController();
    ref.listenManual(calendarSettingsControllerProvider, (previous, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (_timezoneController.text != next.timezoneName) {
          _timezoneController.text = next.timezoneName;
        }
      });
    });
  }

  @override
  void dispose() {
    _timezoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final state = ref.watch(calendarSettingsControllerProvider);
    final notifier = ref.read(calendarSettingsControllerProvider.notifier);

    return PopScope(
      canPop: !state.isDirty,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop || !state.isDirty) return;
        final leave = await _confirmDiscard(context, l10n);
        if (leave && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: AppShell(
        title: l10n.calendarSettingsTitle,
        currentRoute: AppRoutes.calendarSettings,
        body: _buildBody(context, l10n, state, notifier),
      ),
    );
  }

  Future<bool> _confirmDiscard(
    BuildContext context,
    AppLocalizations l10n,
  ) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.calendarSettingsUnsavedTitle),
        content: Text(l10n.calendarSettingsUnsavedBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.financeActionCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.calendarSettingsDiscard),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    CalendarSettingsState state,
    CalendarSettingsController notifier,
  ) {
    if (state.permissionDenied) {
      return Center(
        child: MessageBanner(
          variant: MessageBannerVariant.info,
          message: l10n.calendarSettingsPermissionDenied,
        ),
      );
    }

    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.errorCode != null && state.days.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MessageBanner(
              variant: MessageBannerVariant.error,
              message: _errorMessage(l10n, state.errorCode!),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => notifier.load(force: true),
              child: Text(l10n.retry),
            ),
          ],
        ),
      );
    }

    final days = state.days.length == 7
        ? state.days
        : CalendarSettings.defaultUnreviewedDays();

    return ListView(
      key: const Key('calendar-settings-list'),
      padding: const EdgeInsetsDirectional.all(16),
      children: [
        if (!state.workingScheduleConfigured)
          CalendarSetupBanner(message: l10n.calendarSettingsSetupRequired),
        if (state.saveSuccess)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: MessageBanner(
              variant: MessageBannerVariant.success,
              message: l10n.calendarSettingsSaved,
            ),
          ),
        if (state.errorCode != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: MessageBanner(
              variant: MessageBannerVariant.error,
              message: _errorMessage(l10n, state.errorCode!),
            ),
          ),
        Autocomplete<String>(
          initialValue: TextEditingValue(text: state.timezoneName),
          optionsBuilder: (query) async {
            if (!state.canEdit) return const Iterable<String>.empty();
            return notifier.searchTimezones(query.text);
          },
          onSelected: state.canEdit ? notifier.updateTimezone : null,
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            if (controller.text != state.timezoneName) {
              controller.text = state.timezoneName;
            }
            return TextField(
              key: const Key('calendar-settings-timezone'),
              controller: controller,
              focusNode: focusNode,
              enabled: state.canEdit,
              decoration: InputDecoration(
                labelText: l10n.calendarSettingsTimezone,
                errorText: state.fieldErrors['timezone'] != null
                    ? l10n.calendarSettingsTimezoneRequired
                    : null,
                helperText:
                    state.legacyTimezoneSuggestion != null &&
                        !state.workingScheduleConfigured
                    ? l10n.calendarSettingsLegacyTimezoneSuggestion(
                        state.legacyTimezoneSuggestion!,
                      )
                    : null,
              ),
              onChanged: state.canEdit ? notifier.updateTimezone : null,
            );
          },
        ),
        const SizedBox(height: 16),
        Text(
          l10n.calendarSettingsWorkingDaysSection,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: 8),
        ...days.map(
          (day) => CalendarWorkingDayEditor(
            key: ValueKey('calendar-day-${day.isoWeekday}'),
            day: day,
            canEdit: state.canEdit,
            errorCode: state.fieldErrors['day_${day.isoWeekday}'],
            onChanged: (updated) => notifier.updateDay(day.isoWeekday, updated),
          ),
        ),
        const SizedBox(height: 16),
        SwitchListTile(
          key: const Key('calendar-settings-remind-event-day'),
          title: Text(l10n.calendarSettingsRemindEventDay),
          value: state.remindEventWorkdayStart,
          onChanged: state.canEdit
              ? notifier.updateRemindEventWorkdayStart
              : null,
        ),
        SwitchListTile(
          key: const Key('calendar-settings-remind-previous-day'),
          title: Text(l10n.calendarSettingsRemindPreviousDay),
          value: state.remindPreviousWorkdayStart,
          onChanged: state.canEdit
              ? notifier.updateRemindPreviousWorkdayStart
              : null,
        ),
        const SizedBox(height: 16),
        if (state.canEdit)
          FilledButton(
            key: const Key('calendar-settings-save'),
            onPressed: state.isSaving ? null : notifier.save,
            child: state.isSaving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(l10n.calendarSettingsSave),
          ),
        const SizedBox(height: 24),
        const CalendarWorkingDateExceptionsSection(),
      ],
    );
  }

  String _errorMessage(AppLocalizations l10n, String code) {
    if (code == FinanceException.permissionDenied) {
      return l10n.calendarSettingsPermissionDenied;
    }
    if (code == FinanceException.validationFailed) {
      return l10n.calendarSettingsValidationFailed;
    }
    return l10n.financeErrorUnknown;
  }
}
