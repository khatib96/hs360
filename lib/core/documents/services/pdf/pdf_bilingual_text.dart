import 'package:pdf/widgets.dart' as pw;

export '../../domain/effective_language.dart' show pickLocalized;

bool containsArabicText(String value) {
  for (final rune in value.runes) {
    if ((rune >= 0x0600 && rune <= 0x06ff) ||
        (rune >= 0x0750 && rune <= 0x077f) ||
        (rune >= 0x08a0 && rune <= 0x08ff) ||
        (rune >= 0xfb50 && rune <= 0xfdff) ||
        (rune >= 0xfe70 && rune <= 0xfeff)) {
      return true;
    }
  }
  return false;
}

pw.TextDirection pdfTextDirectionFor(
  String value, {
  required String languageCode,
}) {
  if (containsArabicText(value)) {
    return pw.TextDirection.rtl;
  }
  return pw.TextDirection.ltr;
}

pw.Text directedPdfText(
  String value, {
  required String languageCode,
  pw.TextStyle? style,
  pw.TextAlign? textAlign,
  int? maxLines,
  bool? softWrap,
}) {
  return pw.Text(
    value,
    style: style,
    textAlign: textAlign,
    textDirection: pdfTextDirectionFor(value, languageCode: languageCode),
    maxLines: maxLines,
    softWrap: softWrap,
  );
}

pw.Widget localizedPdfText({
  required String languageCode,
  required String ar,
  required String en,
  pw.TextStyle? style,
  pw.TextAlign? textAlign,
  double bilingualGap = 1,
}) {
  final arText = ar.trim();
  final enText = en.trim();

  if (languageCode == 'bilingual' && arText.isNotEmpty && enText.isNotEmpty) {
    return pw.Column(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        directedPdfText(
          arText,
          languageCode: 'ar',
          style: style,
          textAlign: textAlign,
        ),
        if (bilingualGap > 0) pw.SizedBox(height: bilingualGap),
        directedPdfText(
          enText,
          languageCode: 'en',
          style: style,
          textAlign: textAlign,
        ),
      ],
    );
  }

  final value = languageCode == 'ar' && arText.isNotEmpty
      ? arText
      : enText.isNotEmpty
      ? enText
      : arText;
  return directedPdfText(
    value,
    languageCode: languageCode,
    style: style,
    textAlign: textAlign,
  );
}
