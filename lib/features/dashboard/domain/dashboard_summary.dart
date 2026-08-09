class DashboardScheduleSummary {
  const DashboardScheduleSummary({
    required this.visible,
    required this.total,
    required this.completed,
    required this.remaining,
  });

  final bool visible;
  final int total;
  final int completed;
  final int remaining;

  factory DashboardScheduleSummary.fromJson(Map<String, dynamic> json) {
    return DashboardScheduleSummary(
      visible: json['visible'] == true,
      total: _asInt(json['total']),
      completed: _asInt(json['completed']),
      remaining: _asInt(json['remaining']),
    );
  }
}

class DashboardOverdueSummary {
  const DashboardOverdueSummary({required this.visible, required this.count});

  final bool visible;
  final int count;

  factory DashboardOverdueSummary.fromJson(Map<String, dynamic> json) {
    return DashboardOverdueSummary(
      visible: json['visible'] == true,
      count: _asInt(json['count']),
    );
  }
}

class DashboardContractSummary {
  const DashboardContractSummary({
    required this.visible,
    required this.active,
    required this.trials,
    required this.rentals,
    required this.assetConditionVisible,
    required this.assetsRented,
    required this.assetsTrial,
    required this.assetsAttention,
  });

  final bool visible;
  final int active;
  final int trials;
  final int rentals;
  final bool assetConditionVisible;
  final int assetsRented;
  final int assetsTrial;
  final int assetsAttention;

  factory DashboardContractSummary.fromJson(Map<String, dynamic> json) {
    return DashboardContractSummary(
      visible: json['visible'] == true,
      active: _asInt(json['active']),
      trials: _asInt(json['trials']),
      rentals: _asInt(json['rentals']),
      assetConditionVisible: json['asset_condition_visible'] == true,
      assetsRented: _asInt(json['assets_rented']),
      assetsTrial: _asInt(json['assets_trial']),
      assetsAttention: _asInt(json['assets_attention']),
    );
  }
}

class DashboardFinancialSummary {
  const DashboardFinancialSummary({
    required this.collectionsVisible,
    required this.collections,
    required this.outstandingVisible,
    required this.outstanding,
    required this.monthStart,
  });

  final bool collectionsVisible;
  final double collections;
  final bool outstandingVisible;
  final double outstanding;
  final DateTime monthStart;

  bool get visible => collectionsVisible || outstandingVisible;

  factory DashboardFinancialSummary.fromJson(Map<String, dynamic> json) {
    return DashboardFinancialSummary(
      collectionsVisible: json['collections_visible'] == true,
      collections: _asDouble(json['collections']),
      outstandingVisible: json['outstanding_visible'] == true,
      outstanding: _asDouble(json['outstanding']),
      monthStart: _asDate(json['month_start']),
    );
  }
}

class DashboardSummary {
  const DashboardSummary({
    required this.businessDate,
    required this.timezoneName,
    required this.currencyCode,
    required this.todaySchedule,
    required this.overdue,
    required this.contracts,
    required this.financial,
  });

  final DateTime businessDate;
  final String timezoneName;
  final String currencyCode;
  final DashboardScheduleSummary todaySchedule;
  final DashboardOverdueSummary overdue;
  final DashboardContractSummary contracts;
  final DashboardFinancialSummary financial;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) {
    return DashboardSummary(
      businessDate: _asDate(json['business_date']),
      timezoneName: json['timezone_name'] as String? ?? '',
      currencyCode: json['currency_code'] as String? ?? '',
      todaySchedule: DashboardScheduleSummary.fromJson(
        _asMap(json['today_schedule']),
      ),
      overdue: DashboardOverdueSummary.fromJson(_asMap(json['overdue'])),
      contracts: DashboardContractSummary.fromJson(_asMap(json['contracts'])),
      financial: DashboardFinancialSummary.fromJson(_asMap(json['financial'])),
    );
  }
}

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.cast<String, dynamic>();
  return const {};
}

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

double _asDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse(value?.toString() ?? '') ?? 0;
}

DateTime _asDate(Object? value) {
  final parsed = DateTime.tryParse(value?.toString() ?? '');
  if (parsed == null) throw const FormatException('Invalid business date');
  return DateTime(parsed.year, parsed.month, parsed.day);
}
