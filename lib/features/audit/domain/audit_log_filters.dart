class AuditLogFilters {
  const AuditLogFilters({
    this.module,
    this.action,
    this.actorId,
    this.dateFrom,
    this.dateTo,
    this.search,
  });

  final String? module;
  final String? action;
  final String? actorId;
  final DateTime? dateFrom;
  final DateTime? dateTo;
  final String? search;

  AuditLogFilters copyWith({
    String? module,
    String? action,
    String? actorId,
    DateTime? dateFrom,
    DateTime? dateTo,
    String? search,
    bool clearModule = false,
    bool clearAction = false,
    bool clearActor = false,
    bool clearSearch = false,
  }) {
    return AuditLogFilters(
      module: clearModule ? null : module ?? this.module,
      action: clearAction ? null : action ?? this.action,
      actorId: clearActor ? null : actorId ?? this.actorId,
      dateFrom: dateFrom ?? this.dateFrom,
      dateTo: dateTo ?? this.dateTo,
      search: clearSearch ? null : search ?? this.search,
    );
  }
}
