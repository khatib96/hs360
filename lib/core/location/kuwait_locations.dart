/// Kuwait governorate/area catalog for customer and supplier profiles.
///
/// [canonical] values are stored in the database and used for filters.
/// Display uses [nameAr] / [nameEn].
library;

/// Default country canonical for Kuwait operations.
const String kuwaitCountryCanonical = 'Kuwait';

/// Sentinel for free-text area entry in dropdowns.
const String kuwaitAreaOtherCanonical = '__other__';

class KuwaitGovernorate {
  const KuwaitGovernorate({
    required this.canonical,
    required this.nameAr,
    required this.nameEn,
    required this.areas,
  });

  final String canonical;
  final String nameAr;
  final String nameEn;
  final List<KuwaitArea> areas;
}

class KuwaitArea {
  const KuwaitArea({
    required this.canonical,
    required this.nameAr,
    this.nameEn,
  });

  final String canonical;
  final String nameAr;
  final String? nameEn;

  String label(String languageCode) {
    if (languageCode == 'en') {
      final en = nameEn?.trim();
      if (en != null && en.isNotEmpty) return en;
    }
    return nameAr;
  }
}

/// All Kuwait governorates with areas (source: business location table).
const List<KuwaitGovernorate> kuwaitGovernorates = [
  KuwaitGovernorate(
    canonical: 'capital',
    nameAr: 'العاصمة',
    nameEn: 'Capital',
    areas: [
      KuwaitArea(canonical: 'sharq', nameAr: 'الشرق'),
      KuwaitArea(canonical: 'mirqab', nameAr: 'المرقاب'),
      KuwaitArea(canonical: 'jibla', nameAr: 'القبلة'),
      KuwaitArea(canonical: 'sawaber', nameAr: 'الصوابر'),
      KuwaitArea(canonical: 'dasman', nameAr: 'دسمان'),
      KuwaitArea(canonical: 'bneid_al_gar', nameAr: 'بنيد القار'),
      KuwaitArea(canonical: 'daiya', nameAr: 'الدعية'),
      KuwaitArea(canonical: 'mansouriya', nameAr: 'المنصورية'),
      KuwaitArea(canonical: 'abdullah_al_salem', nameAr: 'عبدالله السالم'),
      KuwaitArea(canonical: 'nuzha', nameAr: 'النزهة'),
      KuwaitArea(canonical: 'faiha', nameAr: 'الفيحاء'),
      KuwaitArea(canonical: 'shamiya', nameAr: 'الشامية'),
      KuwaitArea(canonical: 'rawda', nameAr: 'الروضة'),
      KuwaitArea(canonical: 'qadsiya', nameAr: 'القادسية'),
      KuwaitArea(canonical: 'qortuba', nameAr: 'قرطبة'),
      KuwaitArea(canonical: 'surra', nameAr: 'السرة'),
      KuwaitArea(canonical: 'khaldiya', nameAr: 'الخالدية'),
      KuwaitArea(canonical: 'yarmouk', nameAr: 'اليرموك'),
      KuwaitArea(canonical: 'shuwaikh', nameAr: 'الشويخ'),
      KuwaitArea(canonical: 'granada', nameAr: 'غرناطة'),
      KuwaitArea(canonical: 'sulaibikhat', nameAr: 'الصليبيخات'),
      KuwaitArea(canonical: 'doha', nameAr: 'الدوحة'),
      KuwaitArea(canonical: 'nahda', nameAr: 'النهضة'),
    ],
  ),
  KuwaitGovernorate(
    canonical: 'hawalli',
    nameAr: 'حولي',
    nameEn: 'Hawalli',
    areas: [
      KuwaitArea(canonical: 'hawalli', nameAr: 'حولي', nameEn: 'Hawalli'),
      KuwaitArea(canonical: 'salmiya', nameAr: 'السالمية'),
      KuwaitArea(canonical: 'salwa', nameAr: 'سلوى'),
      KuwaitArea(canonical: 'rumaithiya', nameAr: 'الرميثية'),
      KuwaitArea(canonical: 'jabriya', nameAr: 'الجابرية'),
      KuwaitArea(canonical: 'shaab', nameAr: 'الشعب'),
      KuwaitArea(canonical: 'bayan', nameAr: 'بيان'),
      KuwaitArea(canonical: 'mishref', nameAr: 'مشرف'),
      KuwaitArea(canonical: 'bidaa', nameAr: 'البدع'),
      KuwaitArea(canonical: 'shuhada', nameAr: 'الشهداء'),
      KuwaitArea(canonical: 'zahra', nameAr: 'الزهراء'),
      KuwaitArea(canonical: 'siddiq', nameAr: 'الصديق'),
      KuwaitArea(canonical: 'salam', nameAr: 'السلام'),
      KuwaitArea(canonical: 'hattin', nameAr: 'حطين'),
    ],
  ),
  KuwaitGovernorate(
    canonical: 'ahmadi',
    nameAr: 'الأحمدي',
    nameEn: 'Ahmadi',
    areas: [
      KuwaitArea(canonical: 'ahmadi', nameAr: 'الأحمدي', nameEn: 'Ahmadi'),
      KuwaitArea(canonical: 'fintas', nameAr: 'الفنطاس'),
      KuwaitArea(canonical: 'fahaheel', nameAr: 'الفحيحيل'),
      KuwaitArea(canonical: 'mangaf', nameAr: 'المنقف'),
      KuwaitArea(canonical: 'abu_halifa', nameAr: 'أبو حليفة'),
      KuwaitArea(canonical: 'sabahiya', nameAr: 'الصباحية'),
      KuwaitArea(canonical: 'dahar', nameAr: 'الظهر'),
      KuwaitArea(canonical: 'riqqa', nameAr: 'الرقة'),
      KuwaitArea(canonical: 'hadiya', nameAr: 'هدية'),
      KuwaitArea(canonical: 'jaber_al_ali', nameAr: 'جابر العلي'),
      KuwaitArea(canonical: 'eqaila', nameAr: 'العقيلة'),
      KuwaitArea(
        canonical: 'fahaheel_industrial',
        nameAr: 'الفحيحيل الصناعية',
      ),
      KuwaitArea(canonical: 'sabah_al_ahmad', nameAr: 'صباح الأحمد'),
      KuwaitArea(canonical: 'ali_sabah_al_salem', nameAr: 'علي صباح السالم'),
      KuwaitArea(canonical: 'khiran_city', nameAr: 'مدينة الخيران'),
      KuwaitArea(canonical: 'wafra', nameAr: 'الوفرة'),
      KuwaitArea(canonical: 'mina_abdullah', nameAr: 'ميناء عبدالله'),
    ],
  ),
  KuwaitGovernorate(
    canonical: 'farwaniya',
    nameAr: 'الفروانية',
    nameEn: 'Farwaniya',
    areas: [
      KuwaitArea(canonical: 'farwaniya', nameAr: 'الفروانية', nameEn: 'Farwaniya'),
      KuwaitArea(canonical: 'omariya', nameAr: 'العمرية'),
      KuwaitArea(canonical: 'rabiya', nameAr: 'الرابية'),
      KuwaitArea(canonical: 'khaitan', nameAr: 'خيطان'),
      KuwaitArea(canonical: 'jleeb_al_shuyoukh', nameAr: 'جليب الشيوخ'),
      KuwaitArea(canonical: 'abdullah_al_mubarak', nameAr: 'عبدالله المبارك'),
      KuwaitArea(
        canonical: 'sabah_al_nasser',
        nameAr: 'ضاحية صباح الناصر',
      ),
      KuwaitArea(canonical: 'andalus', nameAr: 'الأندلس'),
      KuwaitArea(canonical: 'firdous', nameAr: 'الفردوس'),
      KuwaitArea(canonical: 'sabah_al_salem', nameAr: 'صباح السالم'),
      KuwaitArea(canonical: 'shadadiya', nameAr: 'الشدادية'),
      KuwaitArea(
        canonical: 'rabiya_industrial',
        nameAr: 'الرابية الصناعية',
      ),
      KuwaitArea(canonical: 'dajeej', nameAr: 'الضجيج'),
      KuwaitArea(canonical: 'riggae', nameAr: 'الرقعي'),
      KuwaitArea(canonical: 'rai', nameAr: 'الري'),
    ],
  ),
  KuwaitGovernorate(
    canonical: 'jahra',
    nameAr: 'الجهراء',
    nameEn: 'Jahra',
    areas: [
      KuwaitArea(canonical: 'jahra', nameAr: 'الجهراء', nameEn: 'Jahra'),
      KuwaitArea(canonical: 'qasr', nameAr: 'القصر'),
      KuwaitArea(canonical: 'taima', nameAr: 'تيماء'),
      KuwaitArea(canonical: 'naeem', nameAr: 'النعيم'),
      KuwaitArea(canonical: 'waha', nameAr: 'الواحة'),
      KuwaitArea(canonical: 'oyoun', nameAr: 'العيون'),
      KuwaitArea(canonical: 'naseem', nameAr: 'النسيم'),
      KuwaitArea(canonical: 'masayel', nameAr: 'المسايل'),
      KuwaitArea(canonical: 'saad_al_abdullah', nameAr: 'سعد العبدالله'),
      KuwaitArea(canonical: 'abdali', nameAr: 'العبدلي'),
      KuwaitArea(canonical: 'mutlaa', nameAr: 'المطلاع'),
    ],
  ),
  KuwaitGovernorate(
    canonical: 'mubarak_al_kabeer',
    nameAr: 'مبارك الكبير',
    nameEn: 'Mubarak Al-Kabeer',
    areas: [
      KuwaitArea(canonical: 'sabah_al_salem_mb', nameAr: 'صباح السالم'),
      KuwaitArea(canonical: 'adan', nameAr: 'العدان'),
      KuwaitArea(canonical: 'qusour', nameAr: 'القصور'),
      KuwaitArea(canonical: 'qurain', nameAr: 'القرين'),
      KuwaitArea(
        canonical: 'mubarak_al_kabeer_district',
        nameAr: 'ضاحية مبارك الكبير',
      ),
      KuwaitArea(
        canonical: 'sabah_al_ahmad_district',
        nameAr: 'ضاحية صباح الأحمد',
      ),
      KuwaitArea(canonical: 'messila', nameAr: 'المسيلة'),
      KuwaitArea(canonical: 'masayel_mb', nameAr: 'المسايل'),
      KuwaitArea(canonical: 'abu_faitira', nameAr: 'أبو فطيرة'),
      KuwaitArea(canonical: 'funaitees', nameAr: 'الفنيطيس'),
    ],
  ),
];

KuwaitGovernorate? kuwaitGovernorateByCanonical(String? canonical) {
  if (canonical == null || canonical.trim().isEmpty) return null;
  for (final g in kuwaitGovernorates) {
    if (g.canonical == canonical) return g;
  }
  return null;
}

KuwaitArea? kuwaitAreaByCanonical(String? governorateCanonical, String? areaCanonical) {
  final gov = kuwaitGovernorateByCanonical(governorateCanonical);
  if (gov == null || areaCanonical == null) return null;
  for (final a in gov.areas) {
    if (a.canonical == areaCanonical) return a;
  }
  return null;
}

String governorateLabel(String? canonical, String languageCode) {
  final gov = kuwaitGovernorateByCanonical(canonical);
  if (gov == null) return canonical ?? '';
  return languageCode == 'en' ? gov.nameEn : gov.nameAr;
}

String areaLabel(
  String? governorateCanonical,
  String? areaCanonical,
  String languageCode,
) {
  final area = kuwaitAreaByCanonical(governorateCanonical, areaCanonical);
  if (area != null) return area.label(languageCode);
  return areaCanonical ?? '';
}

List<KuwaitArea> areasForGovernorate(String? governorateCanonical) {
  return kuwaitGovernorateByCanonical(governorateCanonical)?.areas ?? const [];
}

/// Builds dropdown entries for a governorate, including a legacy value not in catalog.
List<String> governorateDropdownValues({String? currentValue}) {
  final values = kuwaitGovernorates.map((g) => g.canonical).toList();
  if (currentValue != null &&
      currentValue.isNotEmpty &&
      !values.contains(currentValue)) {
    return [currentValue, ...values];
  }
  return values;
}

/// Area dropdown values for a governorate, with optional legacy/custom value.
List<String> areaDropdownValues({
  required String? governorateCanonical,
  String? currentValue,
}) {
  final values = areasForGovernorate(governorateCanonical)
      .map((a) => a.canonical)
      .toList();
  if (currentValue != null &&
      currentValue.isNotEmpty &&
      currentValue != kuwaitAreaOtherCanonical &&
      !values.contains(currentValue)) {
    return [currentValue, ...values, kuwaitAreaOtherCanonical];
  }
  return [...values, kuwaitAreaOtherCanonical];
}
