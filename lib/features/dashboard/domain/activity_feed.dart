class ActivityFeedItem {
  const ActivityFeedItem({
    required this.kind,
    required this.entityId,
    required this.occurredAt,
    this.localTime,
    required this.titleAr,
    required this.titleEn,
    required this.identifier,
    required this.status,
    this.amount,
    this.sourceRoute,
  });

  final String kind;
  final String entityId;
  final DateTime occurredAt;
  final String? localTime;
  final String titleAr;
  final String titleEn;
  final String identifier;
  final String status;
  final double? amount;
  final String? sourceRoute;

  String localizedTitle(String languageCode) {
    if (languageCode == 'ar' && titleAr.trim().isNotEmpty) return titleAr;
    if (titleEn.trim().isNotEmpty) return titleEn;
    return titleAr;
  }

  factory ActivityFeedItem.fromJson(Map<String, dynamic> json) {
    final amountRaw = json['amount'];
    return ActivityFeedItem(
      kind: json['kind'] as String? ?? '',
      entityId: json['entity_id'] as String? ?? '',
      occurredAt:
          DateTime.tryParse(json['occurred_at']?.toString() ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      localTime: _safeLocalTime(json['local_time']),
      titleAr: json['title_ar'] as String? ?? '',
      titleEn: json['title_en'] as String? ?? '',
      identifier: json['identifier'] as String? ?? '',
      status: json['status'] as String? ?? '',
      amount: amountRaw == null
          ? null
          : (amountRaw is num
                ? amountRaw.toDouble()
                : double.tryParse(amountRaw.toString())),
      sourceRoute: _safeRoute(json['source_route']),
    );
  }

  static String? _safeRoute(Object? value) {
    final route = value?.toString().trim();
    if (route == null || route.isEmpty || !route.startsWith('/')) return null;
    return route;
  }

  static String? _safeLocalTime(Object? value) {
    final localTime = value?.toString().trim();
    if (localTime == null ||
        !RegExp(r'^(?:[01]\d|2[0-3]):[0-5]\d$').hasMatch(localTime)) {
      return null;
    }
    return localTime;
  }
}

class ActivityFeedPage {
  const ActivityFeedPage({
    required this.businessDate,
    required this.timezoneName,
    required this.currencyCode,
    required this.items,
    required this.totalCount,
    required this.hasMore,
    this.kind,
  });

  final DateTime businessDate;
  final String timezoneName;
  final String currencyCode;
  final List<ActivityFeedItem> items;
  final int totalCount;
  final bool hasMore;
  final String? kind;

  factory ActivityFeedPage.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'] as List? ?? const [];
    final rawDate = DateTime.tryParse(json['business_date']?.toString() ?? '');
    if (rawDate == null) throw const FormatException('Invalid business date');
    return ActivityFeedPage(
      businessDate: DateTime(rawDate.year, rawDate.month, rawDate.day),
      timezoneName: json['timezone_name'] as String? ?? '',
      currencyCode: json['currency_code'] as String? ?? '',
      items: rawItems
          .whereType<Map>()
          .map(
            (item) => ActivityFeedItem.fromJson(item.cast<String, dynamic>()),
          )
          .where((item) => item.kind.isNotEmpty && item.entityId.isNotEmpty)
          .toList(growable: false),
      totalCount: _asInt(json['total_count']),
      hasMore: json['has_more'] == true,
      kind: json['kind'] as String?,
    );
  }

  static int _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
