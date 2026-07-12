/// One generated calendar row from `get_contract_detail.upcoming_schedule`.
class ContractScheduleEvent {
  const ContractScheduleEvent({
    required this.id,
    required this.type,
    required this.scheduledDate,
    this.status,
    this.titleAr,
    this.titleEn,
    this.contractLineId,
    this.productNameAr,
    this.productNameEn,
    this.actionKind,
    this.coverageMonthKey,
    this.daysRemaining,
  });

  final String id;
  final String type;
  final DateTime scheduledDate;
  final String? status;
  final String? titleAr;
  final String? titleEn;
  final String? contractLineId;
  final String? productNameAr;
  final String? productNameEn;
  final String? actionKind;
  final String? coverageMonthKey;
  final int? daysRemaining;

  factory ContractScheduleEvent.fromRpcJson(Map<String, dynamic> json) {
    return ContractScheduleEvent(
      id: json['id'] as String,
      type: json['type'] as String,
      scheduledDate: DateTime.parse(json['scheduled_date'] as String),
      status: json['status'] as String?,
      titleAr: json['title_ar'] as String?,
      titleEn: json['title_en'] as String?,
      contractLineId: json['contract_line_id'] as String?,
      productNameAr: json['product_name_ar'] as String?,
      productNameEn: json['product_name_en'] as String?,
      actionKind: json['action_kind'] as String?,
      coverageMonthKey: json['coverage_month_key'] as String?,
      daysRemaining: json['days_remaining'] as int?,
    );
  }

  bool get isConsumableChange =>
      actionKind == 'consumable_change' ||
      actionKind == 'refill_with_consumable_change';
}
