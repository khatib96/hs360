import 'package:flutter/material.dart';
import 'package:hs360/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

import '../../domain/customer.dart';
import '../../domain/customer_timeline_event.dart';

List<CustomerTimelineEvent> buildCustomerTimelineEvents(
  Customer customer,
  AppLocalizations l10n,
) {
  final events = <CustomerTimelineEvent>[];

  final createdAt = customer.createdAt;
  if (createdAt != null) {
    events.add(
      CustomerTimelineEvent(
        id: 'created',
        occurredAt: createdAt,
        kind: 'created',
        title: l10n.customerTimelineCreated,
      ),
    );
  }

  final updatedAt = customer.updatedAt;
  if (updatedAt != null &&
      (createdAt == null || updatedAt.isAfter(createdAt))) {
    events.add(
      CustomerTimelineEvent(
        id: 'updated',
        occurredAt: updatedAt,
        kind: 'updated',
        title: l10n.customerTimelineUpdated,
      ),
    );
  }

  final acquiredAt = customer.acquiredAt;
  if (acquiredAt != null) {
    events.add(
      CustomerTimelineEvent(
        id: 'acquired',
        occurredAt: acquiredAt,
        kind: 'acquired',
        title: l10n.customerTimelineAcquired,
      ),
    );
  }

  events.sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
  return events;
}

class CustomerTimelineTab extends StatelessWidget {
  const CustomerTimelineTab({required this.customer, super.key});

  final Customer customer;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).languageCode;
    final events = buildCustomerTimelineEvents(customer, l10n);
    final dateFormat = DateFormat.yMMMd(locale).add_jm();

    if (events.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsetsDirectional.all(24),
          child: Text(
            l10n.customerTimelineEmpty,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      key: const Key('customer-timeline-tab'),
      padding: const EdgeInsetsDirectional.all(16),
      itemCount: events.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final event = events[index];
        return ListTile(
          leading: const Icon(Icons.history),
          title: Text(event.title),
          subtitle: Text(dateFormat.format(event.occurredAt)),
        );
      },
    );
  }
}
