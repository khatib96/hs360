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
}
