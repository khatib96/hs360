import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hs360/l10n/app_localizations.dart';

import '../../../../core/routing/app_routes.dart';
import '../../../auth/domain/app_session.dart';
import '../../../calendar/domain/calendar_permissions.dart';
import '../../domain/contract_detail.dart';
import '../../domain/contract_schedule_event.dart';
import '../contract_display_helpers.dart';
import 'contract_detail_panel.dart';

/// Upcoming generated schedule (Phase 7 M11 adds an optional "view in
/// calendar" deep link when the viewer has calendar access).
class ContractUpcomingScheduleSection extends StatelessWidget {
  const ContractUpcomingScheduleSection({
    required this.detail,
    required this.languageCode,
    this.session,
    super.key,
  });

  final ContractDetail detail;
  final String languageCode;
  final AppSession? session;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final events = detail.upcomingSchedule;
    final session = this.session;
    final canOpenCalendar = session != null && canAccessCalendar(session);
    final calendarLink = canOpenCalendar
        ? TextButton.icon(
            key: const Key('contract-view-in-calendar'),
            onPressed: () => context.push(
              AppRoutes.calendarPath(
                customerId: detail.customerId,
                contractId: detail.id,
              ),
            ),
            icon: const Icon(Icons.calendar_month_outlined, size: 18),
            label: Text(l10n.calendarViewContractInCalendar),
          )
        : null;

    if (events.isEmpty) {
      return ContractDetailPanel(
        key: const Key('contract-upcoming-schedule-section'),
        title: l10n.contractSectionUpcomingSchedule,
        trailing: calendarLink,
        child: Text(
          l10n.contractScheduleEmpty,
          key: const Key('contract-upcoming-schedule-empty'),
        ),
      );
    }

    return ContractDetailPanel(
      key: const Key('contract-upcoming-schedule-section'),
      title: l10n.contractSectionUpcomingSchedule,
      trailing: calendarLink,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < events.length; i++) ...[
            if (i > 0) const Divider(height: 20),
            _ScheduleEventRow(
              key: Key('contract-upcoming-schedule-event-$i'),
              event: events[i],
              languageCode: languageCode,
            ),
          ],
        ],
      ),
    );
  }
}

class _ScheduleEventRow extends StatelessWidget {
  const _ScheduleEventRow({
    required this.event,
    required this.languageCode,
    super.key,
  });

  final ContractScheduleEvent event;
  final String languageCode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final productName = contractScheduleProductName(
      languageCode: languageCode,
      nameAr: event.productNameAr,
      nameEn: event.productNameEn,
    );
    final showProduct = productName != '—';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          contractScheduleEventTypeLabel(l10n, event.type),
          style: theme.textTheme.titleSmall,
        ),
        const SizedBox(height: 4),
        ContractInfoRow(
          label: l10n.contractFieldEffectiveDate,
          value: formatContractDate(event.scheduledDate),
        ),
        if (event.daysRemaining != null)
          ContractInfoRow(
            label: l10n.contractScheduleRemaining,
            value: formatRemainingDays(l10n, event.daysRemaining!),
          ),
        if (showProduct)
          ContractInfoRow(
            label: l10n.contractProductTypeConsumable,
            value: productName,
          ),
        if (event.isConsumableChange)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              l10n.contractScheduleEventConsumableChange,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}
