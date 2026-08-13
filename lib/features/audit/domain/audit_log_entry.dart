class AuditLogEntry {
  const AuditLogEntry({
    required this.id,
    required this.occurredAt,
    required this.localTime,
    required this.actorName,
    required this.action,
    required this.module,
    required this.entityType,
    required this.sourceVisible,
    required this.beforeSummary,
    required this.afterSummary,
    required this.changedFields,
    this.actorId,
    this.actorAccountType,
    this.entityId,
    this.reason,
    this.sourceRoute,
  });

  final int id;
  final DateTime occurredAt;
  final String localTime;
  final String? actorId;
  final String actorName;
  final String? actorAccountType;
  final String action;
  final String module;
  final String entityType;
  final String? entityId;
  final String? reason;
  final bool sourceVisible;
  final Map<String, dynamic> beforeSummary;
  final Map<String, dynamic> afterSummary;
  final List<String> changedFields;
  final String? sourceRoute;

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) {
    final at = DateTime.tryParse(json['at']?.toString() ?? '');
    if (at == null) throw const FormatException('Invalid audit timestamp');
    return AuditLogEntry(
      id: _asInt(json['id']),
      occurredAt: at,
      localTime: json['local_time'] as String? ?? '',
      actorId: json['actor_id'] as String?,
      actorName: json['actor_name'] as String? ?? '',
      actorAccountType: json['actor_account_type'] as String?,
      action: json['action'] as String? ?? '',
      module: json['module'] as String? ?? 'system',
      entityType: json['entity_type'] as String? ?? '',
      entityId: json['entity_id'] as String?,
      reason: _nonEmpty(json['reason']),
      sourceVisible: json['source_visible'] == true,
      beforeSummary: _asMap(json['before_summary']),
      afterSummary: _asMap(json['after_summary']),
      changedFields: (json['changed_fields'] as List? ?? const [])
          .map((value) => value.toString())
          .where((value) => value.isNotEmpty)
          .toList(growable: false),
      sourceRoute: _safeRoute(json['source_route']),
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static Map<String, dynamic> _asMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();
    return const {};
  }

  static String? _nonEmpty(Object? value) {
    final text = value?.toString().trim();
    return text == null || text.isEmpty ? null : text;
  }

  static String? _safeRoute(Object? value) {
    final route = _nonEmpty(value);
    if (route == null ||
        !route.startsWith('/') ||
        route.startsWith('//') ||
        route.contains('\\')) {
      return null;
    }
    final uri = Uri.tryParse(route);
    return uri != null && !uri.hasScheme && !uri.hasAuthority ? route : null;
  }
}

class AuditLogPage {
  const AuditLogPage({
    required this.timezoneName,
    required this.items,
    required this.hasMore,
    this.nextBeforeAt,
    this.nextBeforeId,
  });

  final String timezoneName;
  final List<AuditLogEntry> items;
  final bool hasMore;
  final DateTime? nextBeforeAt;
  final int? nextBeforeId;

  factory AuditLogPage.fromJson(Map<String, dynamic> json) {
    final items = (json['items'] as List? ?? const [])
        .whereType<Map>()
        .map((item) => AuditLogEntry.fromJson(item.cast<String, dynamic>()))
        .where((item) => item.id > 0 && item.entityType.isNotEmpty)
        .toList(growable: false);
    final rawId = json['next_before_id'];
    final nextId = rawId == null ? null : AuditLogEntry._asInt(rawId);
    return AuditLogPage(
      timezoneName: json['timezone_name'] as String? ?? '',
      items: items,
      hasMore: json['has_more'] == true,
      nextBeforeAt: DateTime.tryParse(json['next_before_at']?.toString() ?? ''),
      nextBeforeId: nextId == 0 ? null : nextId,
    );
  }
}
