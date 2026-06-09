import 'package:flutter_test/flutter_test.dart';
import 'package:hs360/core/documents/services/pdf/pdf_bilingual_text.dart';
import 'package:pdf/widgets.dart' as pw;

void main() {
  test('detects Arabic text across common Unicode ranges', () {
    expect(containsArabicText('شركة تجريبية'), isTrue);
    expect(containsArabicText('Sample Co'), isFalse);
  });

  test('Arabic content remains RTL inside a bilingual document', () {
    final text = directedPdfText('فاتورة مبيعات', languageCode: 'bilingual');

    expect(text.textDirection, pw.TextDirection.rtl);
  });

  test('Latin identifiers remain LTR inside an Arabic document', () {
    expect(
      pdfTextDirectionFor('SN-12345', languageCode: 'ar'),
      pw.TextDirection.ltr,
    );
    expect(
      pdfTextDirectionFor('C-001', languageCode: 'ar'),
      pw.TextDirection.ltr,
    );
  });

  test('bilingual localized text uses separate RTL and LTR runs', () {
    final widget = localizedPdfText(
      languageCode: 'bilingual',
      ar: 'عميل عربي',
      en: 'Arabic Customer',
      bilingualGap: 0,
    );

    expect(widget, isA<pw.Column>());
    final children = (widget as pw.Column).children;
    expect(children, hasLength(2));
    expect((children[0] as pw.Text).textDirection, pw.TextDirection.rtl);
    expect((children[1] as pw.Text).textDirection, pw.TextDirection.ltr);
  });
}
