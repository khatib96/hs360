class AppNotification {
  const AppNotification({
    required this.id,
    required this.subject,
    required this.bodyAr,
    required this.bodyEn,
    required this.isRead,
    required this.createdAt,
    this.readAt,
    this.sourceRoute,
  });

  final String id;
  final String subject;
  final String bodyAr;
  final String bodyEn;
  final bool isRead;
  final DateTime createdAt;
  final DateTime? readAt;
  final String? sourceRoute;

  String body(String languageCode) => languageCode == 'ar' ? bodyAr : bodyEn;

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: json['id'] as String? ?? '',
      subject: json['subject'] as String? ?? '',
      bodyAr: json['body_ar'] as String? ?? '',
      bodyEn: json['body_en'] as String? ?? '',
      isRead: json['is_read'] as bool? ?? false,
      createdAt:
          DateTime.tryParse(json['created_at'] as String? ?? '') ??
          DateTime.fromMillisecondsSinceEpoch(0),
      readAt: DateTime.tryParse(json['read_at'] as String? ?? ''),
      sourceRoute: json['source_route'] as String?,
    );
  }
}

class AppNotificationPage {
  const AppNotificationPage({
    required this.items,
    required this.unreadCount,
    required this.hasMore,
  });

  const AppNotificationPage.empty()
    : items = const [],
      unreadCount = 0,
      hasMore = false;

  final List<AppNotification> items;
  final int unreadCount;
  final bool hasMore;

  factory AppNotificationPage.fromJson(Map<String, dynamic> json) {
    final rows = json['items'] as List? ?? const [];
    return AppNotificationPage(
      items: rows
          .whereType<Map>()
          .map((row) => AppNotification.fromJson(row.cast<String, dynamic>()))
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false),
      unreadCount: json['unread_count'] as int? ?? 0,
      hasMore: json['has_more'] as bool? ?? false,
    );
  }
}
