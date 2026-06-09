import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/services/pdf/pdf_field_labels.dart';

void main() {
  test('returns bilingual financial labels without exposing internal keys', () {
    expect(
      PdfFieldLabels.forField(
        'summary.opening_balance',
        languageCode: 'bilingual',
      ),
      'الرصيد الافتتاحي / Opening balance',
    );
    expect(
      PdfFieldLabels.forField('totals.total', languageCode: 'en'),
      'Total',
    );
  });

  test('humanizes unknown field names', () {
    expect(
      PdfFieldLabels.forField('summary.custom_value', languageCode: 'en'),
      'custom value',
    );
  });
}
