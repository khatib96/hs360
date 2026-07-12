import 'pdf_bilingual_text.dart';

abstract final class PdfFieldLabels {
  static const _labels = <String, ({String ar, String en})>{
    'totals.subtotal': (ar: 'المجموع الفرعي', en: 'Subtotal'),
    'totals.discount': (ar: 'الخصم', en: 'Discount'),
    'totals.tax': (ar: 'الضريبة', en: 'Tax'),
    'totals.total': (ar: 'الإجمالي', en: 'Total'),
    'summary.opening_balance': (ar: 'الرصيد الافتتاحي', en: 'Opening balance'),
    'summary.total_debit': (ar: 'إجمالي المدين', en: 'Total debit'),
    'summary.total_credit': (ar: 'إجمالي الدائن', en: 'Total credit'),
    'summary.closing_balance': (ar: 'الرصيد الختامي', en: 'Closing balance'),
    'totals.monthly_rental': (ar: 'الإيجار الشهري', en: 'Monthly rental'),
    'totals.total_value': (ar: 'قيمة العقد', en: 'Total contract value'),
    'totals.is_trial': (ar: 'عقد تجريبي', en: 'Trial contract'),
    'document.start_date': (ar: 'تاريخ البدء', en: 'Start date'),
    'document.end_date': (ar: 'تاريخ الانتهاء', en: 'End date'),
    'document.trial_days': (ar: 'أيام التجربة', en: 'Trial days'),
    'document.trial_end_date': (ar: 'نهاية التجربة', en: 'Trial end date'),
    'document.duration_months': (
      ar: 'مدة العقد (أشهر)',
      en: 'Duration (months)',
    ),
    'document.billing_day': (ar: 'يوم الفوترة', en: 'Billing day'),
    'document.refill_day': (ar: 'يوم التعبئة', en: 'Refill day'),
    'document.type': (ar: 'نوع العقد', en: 'Contract type'),
    'document.status': (ar: 'حالة العقد', en: 'Contract status'),
    'document.printed_at': (ar: 'تاريخ الطباعة', en: 'Printed at'),
    'party.contact_person': (ar: 'جهة الاتصال', en: 'Contact person'),
    'party.phone': (ar: 'الهاتف', en: 'Phone'),
    'party.email': (ar: 'البريد الإلكتروني', en: 'Email'),
    'location.name': (ar: 'موقع الخدمة', en: 'Service location'),
    'location.governorate': (ar: 'المحافظة', en: 'Governorate'),
    'location.area': (ar: 'المنطقة', en: 'Area'),
  };

  static const unitLabels = <String, ({String ar, String en})>{
    'piece': (ar: 'قطعة', en: 'Piece'),
    'liter': (ar: 'لتر', en: 'Liter'),
    'ml': (ar: 'مل', en: 'ml'),
    'gram': (ar: 'غرام', en: 'Gram'),
    'kg': (ar: 'كغ', en: 'kg'),
    'box': (ar: 'صندوق', en: 'Box'),
    'bottle': (ar: 'زجاجة', en: 'Bottle'),
    'carton': (ar: 'كرتون', en: 'Carton'),
    'meter': (ar: 'متر', en: 'Meter'),
    'pack': (ar: 'عبوة', en: 'Pack'),
  };

  static const contractTypeLabels = <String, ({String ar, String en})>{
    'trial': (ar: 'تجريبي', en: 'Trial'),
    'rental': (ar: 'إيجار', en: 'Rental'),
  };

  static const contractStatusLabels = <String, ({String ar, String en})>{
    'draft': (ar: 'مسودة', en: 'Draft'),
    'active': (ar: 'نشط', en: 'Active'),
    'suspended': (ar: 'موقوف', en: 'Suspended'),
    'completed': (ar: 'مكتمل', en: 'Completed'),
    'terminated_early': (ar: 'منتهٍ مبكراً', en: 'Terminated early'),
    'expired': (ar: 'منتهٍ', en: 'Expired'),
  };

  static String forField(String field, {required String languageCode}) {
    final labels = labelsForField(field);
    return pickLocalized(
      languageCode: languageCode,
      ar: labels.ar,
      en: labels.en,
    );
  }

  static ({String ar, String en}) labelsForField(String field) {
    final labels = _labels[field];
    if (labels != null) return labels;
    final humanized = field.split('.').last.replaceAll('_', ' ');
    return (ar: humanized, en: humanized);
  }

  static String unitLabel(String? dbValue, {required String languageCode}) {
    if (dbValue == null || dbValue.trim().isEmpty) return '';
    final labels = unitLabels[dbValue.trim()];
    if (labels == null) return dbValue;
    return languageCode == 'ar' ? labels.ar : labels.en;
  }

  static String contractTypeLabel(
    String? dbValue, {
    required String languageCode,
  }) {
    if (dbValue == null || dbValue.trim().isEmpty) return '';
    final labels = contractTypeLabels[dbValue.trim()];
    if (labels == null) return dbValue;
    return languageCode == 'ar' ? labels.ar : labels.en;
  }

  static String contractStatusLabel(
    String? dbValue, {
    required String languageCode,
  }) {
    if (dbValue == null || dbValue.trim().isEmpty) return '';
    final labels = contractStatusLabels[dbValue.trim()];
    if (labels == null) return dbValue;
    return languageCode == 'ar' ? labels.ar : labels.en;
  }

  static String trialFlagLabel(dynamic value, {required String languageCode}) {
    final isTrial = value == true || value == 'true';
    if (!isTrial) return '';
    return languageCode == 'ar' ? 'نعم' : 'Yes';
  }
}
