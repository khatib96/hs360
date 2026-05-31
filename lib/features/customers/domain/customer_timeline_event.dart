/// Placeholder for M6 customer timeline. No RPC in M2/M3.
class CustomerTimelineEvent {
  const CustomerTimelineEvent({
    required this.id,
    required this.occurredAt,
    required this.kind,
    required this.title,
  });

  final String id;
  final DateTime occurredAt;
  final String kind;
  final String title;
}
