class GlobalSearchResult {
  const GlobalSearchResult({
    required this.category,
    required this.entityId,
    required this.titleAr,
    required this.titleEn,
    required this.identifier,
    required this.route,
  });

  final String category;
  final String entityId;
  final String titleAr;
  final String titleEn;
  final String identifier;
  final String route;

  String title(String languageCode) => languageCode == 'ar' ? titleAr : titleEn;

  factory GlobalSearchResult.fromJson(Map<String, dynamic> json) {
    return GlobalSearchResult(
      category: json['category'] as String? ?? '',
      entityId: json['entity_id'] as String? ?? '',
      titleAr: json['title_ar'] as String? ?? '',
      titleEn: json['title_en'] as String? ?? '',
      identifier: json['identifier'] as String? ?? '',
      route: json['route'] as String? ?? '',
    );
  }
}
